import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/models/live_trip_position.dart';

/// Live trip GPS tracking (§4): the driver ping write path and the
/// party-scoped live-trip feed the map screens consume.
class LiveTrackingService {
  final SupabaseClient _client = SupabaseConfig.client;
  final _log = LoggerFactory.getLogger('LiveTrackingService');

  /// Records one driver ping via `record_vehicle_position`. The RPC resolves
  /// the caller's truck through driver_assignments and stamps the active trip;
  /// `{recorded: false, reason: no_vehicle | no_active_trip}` is the
  /// reporter's signal to stop.
  Future<Map<String, dynamic>> recordPosition({
    required double lat,
    required double lng,
    double? heading,
    double? speedKmh,
    double? accuracyM,
  }) async {
    final res = await _client.rpc('record_vehicle_position', params: {
      'p_lat': lat,
      'p_lng': lng,
      'p_heading': heading,
      'p_speed_kmh': speedKmh,
      'p_accuracy_m': accuracyM,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  /// Publishes the driver's live navigation state (telemetry sharing,
  /// 2026-07-17): current instruction, ETA, time/distance left, speed and —
  /// when a route was (re)fetched — the encoded polyline, so every trip party
  /// can mirror the navigation the driver sees. [newSession] resets the
  /// original-ETA baseline used for the "late vs plan" readout.
  Future<void> publishNavState({
    String? instruction,
    DateTime? eta,
    int? timeLeftS,
    int? distanceLeftM,
    double? speedKmh,
    String? routePolyline,
    bool newSession = false,
  }) async {
    try {
      await _client.rpc('publish_trip_nav_state', params: {
        'p_current_instruction': instruction,
        'p_eta': eta?.toUtc().toIso8601String(),
        'p_time_left_s': timeLeftS,
        'p_distance_left_m': distanceLeftM,
        'p_speed_kmh': speedKmh,
        'p_route_polyline': routePolyline,
        'p_new_session': newSession,
      });
    } catch (e) {
      // Telemetry is best-effort — navigation must keep working offline.
      _log.w('publishNavState failed: $e');
    }
  }

  /// Every active trip (with truck) the caller may see, latest position
  /// attached. [companyId] null = platform-wide (super-admin).
  Future<List<LiveTripPosition>> listLiveTrips(String? companyId) async {
    final res = await _client.rpc(
      'list_live_trip_positions',
      params: {'p_company_id': companyId},
    );
    return (res as List)
        .map((e) =>
            LiveTripPosition.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Live feed: an initial [listLiveTrips] snapshot, re-fetched whenever a new
  /// vehicle_positions row arrives over realtime (throttled so ping bursts
  /// collapse into one reload) with a slow periodic fallback in case the
  /// realtime channel drops.
  Stream<List<LiveTripPosition>> watchLiveTrips(String? companyId) {
    final controller = StreamController<List<LiveTripPosition>>();
    RealtimeChannel? channel;
    Timer? fallback;
    Timer? pending;
    var disposed = false;
    var emitted = false;

    Future<void> refresh() async {
      if (disposed) return;
      try {
        final rows = await listLiveTrips(companyId);
        if (disposed) return;
        emitted = true;
        controller.add(rows);
      } catch (e) {
        // Surface only a failure to load anything at all; once data is on
        // screen a transient refresh error just keeps the last snapshot.
        _log.w('live trips refresh failed: $e');
        if (!disposed && !emitted) controller.addError(e);
      }
    }

    void scheduleRefresh() {
      pending ??= Timer(const Duration(seconds: 3), () {
        pending = null;
        refresh();
      });
    }

    controller.onListen = () {
      refresh();
      channel = _client
          .channel('live-trip-positions-${companyId ?? 'platform'}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'vehicle_positions',
            callback: (_) => scheduleRefresh(),
          )
          // Nav telemetry (instruction/ETA/route) updates between pings too.
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'trip_nav_state',
            callback: (_) => scheduleRefresh(),
          )
          .subscribe();
      fallback =
          Timer.periodic(const Duration(seconds: 60), (_) => refresh());
    };
    controller.onCancel = () {
      disposed = true;
      pending?.cancel();
      fallback?.cancel();
      final ch = channel;
      if (ch != null) _client.removeChannel(ch);
      // Found by turning `close_sinks` on (S9-3): the timers and the realtime
      // channel were released here and the controller itself never was. Not a
      // growing leak — an unreferenced controller is collected — but leaving a
      // sink open is the wrong contract, and it is one line.
      controller.close();
    };
    return controller.stream;
  }
}
