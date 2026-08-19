import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/portal/models/trip_earning.dart';

/// Transporter earnings data access (manager/admin-scoped RPCs). The revenue is
/// computed server-side from net tons × the transporter's rate/ton; the admin
/// margin is never returned.
class EarningsService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Per-trip P&L — revenue, direct + allocated cost, and net. Backed by
  /// list_transporter_trip_pnl so every cost (tagged or pooled) lands on a
  /// trip's net.
  Future<List<TripEarning>> listTripEarnings(String companyId) async {
    final rows = await _client.rpc(
      'list_transporter_trip_pnl',
      params: {'p_company_id': companyId},
    );
    return (rows as List)
        .map((e) => TripEarning.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<VehicleCost>> listVehicleCosts(String companyId) async {
    final rows = await _client.rpc(
      'list_transporter_vehicle_costs',
      params: {'p_company_id': companyId},
    );
    return (rows as List)
        .map((e) => VehicleCost.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

final earningsServiceProvider =
    Provider<EarningsService>((ref) => EarningsService());

final tripEarningsProvider =
    FutureProvider.family.autoDispose<List<TripEarning>, String>(
  (ref, companyId) => ref.read(earningsServiceProvider).listTripEarnings(companyId),
);

final vehicleCostsProvider =
    FutureProvider.family.autoDispose<List<VehicleCost>, String>(
  (ref, companyId) => ref.read(earningsServiceProvider).listVehicleCosts(companyId),
);
