import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/portal/models/fuel_models.dart';

/// Fuel + operating-cost data access (CLAUDE.md §6). Writes go through
/// SECURITY DEFINER RPCs that self-authorize (staff/driver can log fuel;
/// managers log tyres/tolls).
class FuelService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<FuelEntry>> listFuel(String companyId) async {
    final rows = await _client
        .rpc('list_fuel_entries', params: {'p_company_id': companyId});
    return (rows as List)
        .map((e) => FuelEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String> logFuel({
    required String companyId,
    required String vehicleId,
    required double litres,
    required double costZar,
    double? odometerKm,
    String? station,
    String? tripId,
    DateTime? filledAt,
    String? notes,
    String? id,
  }) async {
    final res = await _client.rpc('log_fuel_entry', params: {
      'p_company_id': companyId,
      'p_vehicle_id': vehicleId,
      'p_litres': litres,
      'p_cost_zar': costZar,
      'p_odometer_km': odometerKm,
      'p_station': station,
      'p_trip_id': tripId,
      'p_filled_at': filledAt?.toUtc().toIso8601String(),
      'p_notes': notes,
      'p_id': id,
    });
    return (Map<String, dynamic>.from(res as Map)['id']).toString();
  }

  Future<void> deleteFuel(String id) async {
    await _client.rpc('delete_fuel_entry', params: {'p_id': id});
  }

  Future<List<OperatingCost>> listOperatingCosts(String companyId) async {
    final rows = await _client
        .rpc('list_operating_costs', params: {'p_company_id': companyId});
    return (rows as List)
        .map((e) => OperatingCost.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<String> logOperatingCost({
    required String companyId,
    required String vehicleId,
    required OperatingCostKind kind,
    required double costZar,
    DateTime? incurredAt,
    String? description,
    String? tripId,
    String? id,
  }) async {
    final res = await _client.rpc('log_operating_cost', params: {
      'p_company_id': companyId,
      'p_vehicle_id': vehicleId,
      'p_kind': kind.wire,
      'p_cost_zar': costZar,
      'p_incurred_at': incurredAt?.toUtc().toIso8601String(),
      'p_description': description,
      'p_trip_id': tripId,
      'p_id': id,
    });
    return (Map<String, dynamic>.from(res as Map)['id']).toString();
  }

  Future<void> deleteOperatingCost(String id) async {
    await _client.rpc('delete_operating_cost', params: {'p_id': id});
  }

  Future<List<VehicleCostBreakdown>> listCostBreakdown(String companyId) async {
    final rows = await _client.rpc(
        'list_transporter_vehicle_cost_breakdown',
        params: {'p_company_id': companyId});
    return (rows as List)
        .map((e) => VehicleCostBreakdown.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}

final fuelServiceProvider = Provider<FuelService>((ref) => FuelService());

final fuelEntriesProvider =
    FutureProvider.family.autoDispose<List<FuelEntry>, String>(
  (ref, companyId) => ref.read(fuelServiceProvider).listFuel(companyId),
);

final operatingCostsProvider =
    FutureProvider.family.autoDispose<List<OperatingCost>, String>(
  (ref, companyId) =>
      ref.read(fuelServiceProvider).listOperatingCosts(companyId),
);

final vehicleCostBreakdownProvider =
    FutureProvider.family.autoDispose<List<VehicleCostBreakdown>, String>(
  (ref, companyId) =>
      ref.read(fuelServiceProvider).listCostBreakdown(companyId),
);
