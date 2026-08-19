import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/models/mine_hazard.dart';

/// Data access for `mine_hazards` (phase-5 design §2.4). Radius queries go
/// through the `get_nearby_hazards(lat, lng, radius_meters)` RPC (bounding
/// box + haversine — no PostGIS on this project), and inserts write PLAIN
/// `latitude`/`longitude` columns — never a PostGIS EWKT `geom` (the ML donor
/// schema's biggest mismatch with the live table).
class HazardService {
  static final _log = LoggerFactory.getLogger('HazardService');
  final SupabaseClient _client = SupabaseConfig.client;

  /// Active hazards within [radiusMeters] of ([lat], [lng]), nearest first.
  Future<List<MineHazard>> nearby(double lat, double lng,
      {int radiusMeters = 5000}) async {
    final rows = await _client.rpc('get_nearby_hazards', params: {
      'lat': lat,
      'lng': lng,
      'radius_meters': radiusMeters,
    });
    return [
      for (final r in (rows as List? ?? const []))
        MineHazard.fromJson(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// Avoid-points near [p] for `RoutingService.fetchRoute(avoidLocations:)` —
  /// critical hazards only by default (blasting zones are the primary
  /// use-case). Best-effort by contract: NEVER throws; any failure is logged
  /// and returns an empty list so a hazard-fetch problem can never block
  /// routing.
  Future<List<LatLng>> avoidZonesNear(LatLng p,
      {int radiusMeters = 20000, bool criticalOnly = true}) async {
    try {
      final hazards =
          await nearby(p.latitude, p.longitude, radiusMeters: radiusMeters);
      return [
        for (final h in hazards)
          if (!criticalOnly || h.isCritical) LatLng(h.latitude, h.longitude),
      ];
    } catch (e) {
      _log.w('avoidZonesNear failed (routing continues without zones): $e');
      return const [];
    }
  }

  /// The SOURCE mine of [tripId], or null if the caller is not a party to it.
  ///
  /// Resolved server-side (`mine_for_trip`) rather than carried down through
  /// the UI: a hazard is scoped to a mine, and the client should not be the
  /// one deciding which. See migration 20260816230000.
  Future<String?> mineForTrip(String tripId) async {
    final res =
        await _client.rpc('mine_for_trip', params: {'p_trip_id': tripId});
    return res as String?;
  }

  /// Report a hazard at ([lat], [lng]) for [mineCompanyId]. [expiresAt]
  /// optional — hazards without an expiry persist until cleared.
  ///
  /// [mineCompanyId] decides who receives this: only that mine's staff and
  /// drivers with a trip to it that has not yet left it. Get it from
  /// [mineForTrip] rather than from anything the user chose. The insert is
  /// refused outright unless the caller is a driver heading to that mine or
  /// that mine's owner/admin/management (RLS, migration 20260816220000).
  ///
  /// `reported_by` is deliberately NOT sent — the column defaults to
  /// `auth.uid()`, so the author cannot be spoofed by the client.
  Future<MineHazard> report({
    required String type,
    required String mineCompanyId,
    String severity = 'medium',
    String description = '',
    required double lat,
    required double lng,
    DateTime? expiresAt,
  }) async {
    _log.i('Reporting $type ($severity) hazard at ($lat, $lng) '
        'for mine $mineCompanyId');
    final row = await _client
        .from('mine_hazards')
        .insert({
          'hazard_type': type,
          'severity': severity,
          'description': description,
          // Plain columns — the live table has no PostGIS geom.
          'latitude': lat,
          'longitude': lng,
          'mine_company_id': mineCompanyId,
          'reported_at': DateTime.now().toUtc().toIso8601String(),
          if (expiresAt != null)
            'expires_at': expiresAt.toUtc().toIso8601String(),
        })
        .select()
        .single();
    return MineHazard.fromJson(row);
  }

  /// Clear (delete) a hazard by its serial int id. Allowed for the platform
  /// admin and for whoever reported it (`mine_hazards_delete_own`) — a hazard
  /// that has cleared should be retractable by the person who saw it clear.
  Future<void> clear(int id) async {
    _log.i('Clearing hazard $id');
    await _client.from('mine_hazards').delete().eq('id', id);
  }

  /// All non-expired hazards, newest first (non-spatial listing; prefer
  /// [nearby] for radius queries).
  Future<List<MineHazard>> activeAll() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final rows = await _client
        .from('mine_hazards')
        .select()
        .or('expires_at.is.null,expires_at.gt.$now')
        .order('reported_at', ascending: false);
    return [for (final r in rows) MineHazard.fromJson(r)];
  }
}
