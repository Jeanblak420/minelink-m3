import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/models/mine_location.dart';

/// Data access for the `mine_locations` navigation anchors (phase-5 design
/// §2.1): the three per-mine points — Main Gate, Weighbridge, Loading Point —
/// that `auto_generate_trip_waypoints` turns into a trip's waypoint sequence.
/// One active row per type per mine (unique `mine_company_id,location_type`).
class MineLocationService {
  static final _log = LoggerFactory.getLogger('MineLocationService');
  final SupabaseClient _client = SupabaseConfig.client;

  /// All anchors configured for a mine, in the canonical
  /// gate → weighbridge → loading-point order.
  Future<List<MineLocation>> list(String mineCompanyId) async {
    final rows = await _client
        .from('mine_locations')
        .select()
        .eq('mine_company_id', mineCompanyId)
        .order('location_type', ascending: true);
    final anchors = [for (final r in rows) MineLocation.fromJson(r)];
    // Wire strings don't sort into the physical order — sort by enum index.
    anchors.sort(
        (a, b) => a.locationType.index.compareTo(b.locationType.index));
    return anchors;
  }

  /// The single anchor of [type] for a mine, or null when not configured yet.
  Future<MineLocation?> byType(
      String mineCompanyId, MineLocationType type) async {
    final row = await _client
        .from('mine_locations')
        .select()
        .eq('mine_company_id', mineCompanyId)
        .eq('location_type', type.wire)
        .maybeSingle();
    return row == null ? null : MineLocation.fromJson(row);
  }

  /// Insert-or-update the anchor (one row per `mine_company_id,location_type`
  /// — the row id never travels; the conflict target decides create vs edit).
  Future<MineLocation> upsert(MineLocation location) async {
    _log.i('Upserting ${location.locationType.wire} anchor for mine '
        '${location.mineCompanyId}');
    final row = await _client
        .from('mine_locations')
        .upsert({
          'mine_company_id': location.mineCompanyId,
          'location_type': location.locationType.wire,
          'name': location.name.trim(),
          'address': location.address.trim(),
          'latitude': location.latitude,
          'longitude': location.longitude,
          'map_link': location.mapLink,
          'is_active': location.isActive,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'mine_company_id,location_type')
        .select()
        .single();
    return MineLocation.fromJson(row);
  }

  /// Toggle an anchor without losing its configuration (soft remove/restore).
  Future<void> setActive(String id, bool active) async {
    _log.i('Setting mine location $id active=$active');
    await _client.from('mine_locations').update({
      'is_active': active,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
