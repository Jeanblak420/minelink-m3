import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/models/trip_waypoint.dart';

/// Data access for `trip_waypoints` (phase-5 design §2.2) — everything goes
/// through the Phase-1 RPCs (party-scoped, SECURITY DEFINER), never raw table
/// writes. Waypoint completion is ADDITIVE progress bookkeeping: it must
/// never drive `TripStatus` — the `set_trip_status` cascade stays the
/// authoritative lifecycle.
class TripWaypointService {
  static final _log = LoggerFactory.getLogger('TripWaypointService');
  final SupabaseClient _client = SupabaseConfig.client;

  List<TripWaypoint> _rows(dynamic response) => [
        for (final r in (response as List? ?? const []))
          TripWaypoint.fromJson(Map<String, dynamic>.from(r as Map)),
      ]..sort((a, b) => a.sequenceOrder.compareTo(b.sequenceOrder));

  /// Generate the MG → WB → LP → WB → MG → drop-off sequence from the mine's
  /// configured anchors. Idempotent — the RPC returns the existing rows when
  /// the trip already has waypoints (safe to call on every nav open).
  Future<List<TripWaypoint>> autoGenerate(String tripId) async {
    _log.i('Auto-generating waypoints for trip $tripId');
    final res = await _client
        .rpc('auto_generate_trip_waypoints', params: {'p_trip_id': tripId});
    return _rows(res);
  }

  /// The trip's waypoints in sequence order (empty when the mine never
  /// configured anchors — callers must degrade gracefully).
  Future<List<TripWaypoint>> forTrip(String tripId) async {
    final res =
        await _client.rpc('get_trip_waypoints', params: {'p_trip_id': tripId});
    return _rows(res);
  }

  /// Mark one waypoint reached. Progress bookkeeping only — never advances
  /// the trip lifecycle.
  Future<TripWaypoint> complete(String waypointId) async {
    _log.i('Completing waypoint $waypointId');
    final res = await _client
        .rpc('complete_trip_waypoint', params: {'p_waypoint_id': waypointId});
    return TripWaypoint.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Set (or move) the trip's final drop-off waypoint.
  Future<TripWaypoint> setDropOff({
    required String tripId,
    required double lat,
    required double lng,
    required String address,
  }) async {
    _log.i('Setting drop-off for trip $tripId to ($lat, $lng)');
    final res = await _client.rpc('set_drop_off_waypoint', params: {
      'p_trip_id': tripId,
      'p_latitude': lat,
      'p_longitude': lng,
      'p_address': address,
    });
    return TripWaypoint.fromJson(Map<String, dynamic>.from(res as Map));
  }
}
