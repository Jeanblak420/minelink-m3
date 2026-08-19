import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/portal/models/company_location.dart';

/// CRUD for company_locations + trip nav-destination resolution (all DB
/// access for the Locations feature lives here, per CLAUDE.md §6).
class CompanyLocationService {
  static final _log = LoggerFactory.getLogger('CompanyLocationService');
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<CompanyLocation>> list(String companyId) async {
    final rows = await _client
        .from('company_locations')
        .select()
        .eq('company_id', companyId)
        .order('is_primary', ascending: false)
        .order('created_at', ascending: true);
    return [for (final r in rows) CompanyLocation.fromJson(r)];
  }

  /// Saved locations whose name matches [query], for the location picker.
  ///
  /// Deliberately unfiltered by company: `company_locations_select` is
  /// `is_platform_admin() OR is_company_staff(company_id)`, so RLS already
  /// scopes this to the caller's own company — and widens it to everything for
  /// the platform admin, which is what an admin picking on behalf of a company
  /// wants. Passing a company id here would need the picker to know one, which
  /// it does not.
  Future<List<CompanyLocation>> searchByName(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    // `%` and `_` are wildcards to ilike; a name containing one would otherwise
    // match far more than the user typed.
    final escaped = q.replaceAll(RegExp(r'[%_\\]'), r'\\$&');
    final rows = await _client
        .from('company_locations')
        .select()
        .ilike('name', '%$escaped%')
        .order('is_primary', ascending: false)
        .limit(6);
    return [for (final r in rows) CompanyLocation.fromJson(r)];
  }

  Future<void> add(String companyId, String name, String mapLink) async {
    await _client.from('company_locations').insert({
      'company_id': companyId,
      'name': name.trim(),
      'map_link': mapLink,
    });
  }

  Future<void> rename(String id, String name) async {
    await _client.from('company_locations').update({
      'name': name.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> move(String id, String mapLink) async {
    await _client.from('company_locations').update({
      'map_link': mapLink,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> remove(String id) async {
    await _client.from('company_locations').delete().eq('id', id);
  }

  Future<void> setPrimary(String id) async {
    await _client
        .rpc('set_primary_company_location', params: {'p_location_id': id});
  }

  /// Where the driver should drive for this trip's current leg (spec §2
  /// resolution chain, evaluated server-side).
  Future<NavDestination> tripNavDestination(String tripId,
      {required bool offloadLeg}) async {
    final res = await _client.rpc('get_trip_nav_destination', params: {
      'p_trip_id': tripId,
      'p_leg': offloadLeg ? 'offload' : 'load',
    });
    _log.d('nav destination for $tripId: $res');
    return NavDestination.fromJson(Map<String, dynamic>.from(res as Map));
  }
}
