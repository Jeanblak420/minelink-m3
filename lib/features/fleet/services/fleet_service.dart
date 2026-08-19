import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/database_service.dart';
import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/models/vehicle_driver.dart';
import 'package:flutter_application_1/core/utils/error_handler.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

class FleetService {
  final DatabaseService _databaseService;
  final Logger _logger = LoggerFactory.getLogger('FleetService');
  final StorageAssetService _storageAssetService = StorageAssetService();

  FleetService(this._databaseService);

  /// Each vehicle in [companyId]'s fleet plus its live route-availability
  /// (Available vs On Route), via the `list_transporter_fleet_status` RPC.
  Future<List<FleetVehicleStatus>> getFleetStatus(String companyId) async {
    final rows = await SupabaseConfig.client.rpc(
      'list_transporter_fleet_status',
      params: {'p_company_id': companyId},
    );
    return (rows as List)
        .map((e) => FleetVehicleStatus.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<FleetVehicle>> getFleetVehicles(String companyId) async {
    try {
      final response = await _databaseService.getRecords(
        'fleet_vehicles',
        filters: {'company_id': companyId},
        orderBy: 'created_at',
        ascending: false,
      );

      return _vehiclesFromRecords(response);
    } catch (e) {
      throw ErrorHandler.handleSupabaseError(e);
    }
  }

  Future<FleetVehicle> getFleetVehicleById(String vehicleId) async {
    try {
      _logger.d('Getting fleet vehicle with ID: $vehicleId');
      final response = await _databaseService.getRecord(
        'fleet_vehicles',
        'id',
        vehicleId,
      );

      if (response == null) {
        throw Exception('Fleet vehicle with ID $vehicleId not found');
      }

      return _vehicleFromRecord(response);
    } catch (e) {
      _logger.e('Error getting fleet vehicle by ID', e);
      throw ErrorHandler.handleSupabaseError(e);
    }
  }

  DatabaseService getDatabaseService() {
    return _databaseService;
  }

  Future<FleetVehicle> addFleetVehicle({
    required String vehicleRegistrationNumber,
    required String companyId,
    DateTime? vehicleRegistrationExpiryDate,
    String? firstTrailerRegs,
    String? secondTrailerRegs,
    String? vehicleMake,
    String? vehicleType,
    int? vehicleYearModel,
    int? vehicleOdometerKm,
  }) async {
    try {
      final response = await _rpcVehicle(
        'create_fleet_vehicle',
        params: {
          'target_company_id': companyId,
          'vehicle_registration_number': vehicleRegistrationNumber,
          'vehicle_registration_expiry_date': vehicleRegistrationExpiryDate
              ?.toIso8601String(),
          'first_trailer_regs': firstTrailerRegs,
          'second_trailer_regs': secondTrailerRegs,
          'vehicle_make': vehicleMake,
          'vehicle_type': vehicleType,
          'vehicle_year_model': vehicleYearModel,
          'vehicle_odometer_km': vehicleOdometerKm,
        },
      );

      return _vehicleFromRecord(response);
    } catch (e) {
      throw ErrorHandler.handleSupabaseError(e);
    }
  }

  Future<FleetVehicle> updateFleetVehicle({
    required String id,
    String? vehicleRegistrationNumber,
    DateTime? vehicleRegistrationExpiryDate,
    String? firstTrailerRegs,
    String? secondTrailerRegs,
    bool? isActive,
    String? vehicleMake,
    String? vehicleType,
    int? vehicleYearModel,
    int? vehicleOdometerKm,
    bool clearVehicleMake = false,
    bool clearVehicleType = false,
    bool clearVehicleYearModel = false,
    bool clearVehicleOdometerKm = false,
  }) async {
    try {
      final response = await _rpcVehicle(
        'update_fleet_vehicle',
        params: {
          'target_vehicle_id': id,
          'vehicle_registration_number': vehicleRegistrationNumber,
          'vehicle_registration_expiry_date': vehicleRegistrationExpiryDate
              ?.toIso8601String(),
          'first_trailer_regs': firstTrailerRegs,
          'second_trailer_regs': secondTrailerRegs,
          'is_active': isActive,
          'vehicle_make': vehicleMake,
          'vehicle_type': vehicleType,
          'vehicle_year_model': vehicleYearModel,
          'vehicle_odometer_km': vehicleOdometerKm,
          'clear_vehicle_make': clearVehicleMake,
          'clear_vehicle_type': clearVehicleType,
          'clear_vehicle_year_model': clearVehicleYearModel,
          'clear_vehicle_odometer_km': clearVehicleOdometerKm,
        },
      );

      return _vehicleFromRecord(response);
    } catch (e) {
      throw ErrorHandler.handleSupabaseError(e);
    }
  }

  Future<FleetVehicle> assignDriver({
    required String vehicleId,
    required String companyId,
    required String driverId,
  }) async {
    try {
      final driverEmployeeId = await _resolveDriverEmployeeId(
        companyId: companyId,
        driverReference: driverId,
      );

      final response = await _rpcVehicle(
        'assign_fleet_driver',
        params: {
          'target_vehicle_id': vehicleId,
          'target_driver_employee_id': driverEmployeeId,
        },
      );

      return _vehicleFromRecord(response);
    } catch (e) {
      throw ErrorHandler.handleSupabaseError(e);
    }
  }

  /// Every driver assignment in the company (multi-driver per truck), with
  /// the derived On-Route status of each driver's truck.
  Future<List<VehicleDriver>> listVehicleDrivers(String companyId) async {
    final rows = await SupabaseConfig.client.rpc(
      'list_vehicle_drivers',
      params: {'p_company_id': companyId},
    );
    return (rows as List)
        .map((e) => VehicleDriver.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Adds a driver to a truck (server-enforced cap: fleet_vehicles.max_drivers).
  Future<FleetVehicle> addVehicleDriver({
    required String vehicleId,
    required String driverEmployeeId,
  }) async {
    try {
      final response = await _rpcVehicle(
        'add_vehicle_driver',
        params: {
          'target_vehicle_id': vehicleId,
          'target_driver_employee_id': driverEmployeeId,
        },
      );
      return _vehicleFromRecord(response);
    } catch (e) {
      throw ErrorHandler.handleSupabaseError(e);
    }
  }

  /// Removes one driver from a truck.
  Future<FleetVehicle> removeVehicleDriver({
    required String vehicleId,
    required String driverEmployeeId,
  }) async {
    try {
      final response = await _rpcVehicle(
        'remove_vehicle_driver',
        params: {
          'target_vehicle_id': vehicleId,
          'target_driver_employee_id': driverEmployeeId,
        },
      );
      return _vehicleFromRecord(response);
    } catch (e) {
      throw ErrorHandler.handleSupabaseError(e);
    }
  }

  /// State how many seals this rig carries (1-4).
  ///
  /// Its own RPC rather than a field on [updateFleetVehicle] because that is
  /// how this schema states facts somebody owns — set_route_quality_spec,
  /// set_primary_company_location — and because adding a parameter to a
  /// function PostgREST resolves by named argument changes its identity, so it
  /// would mean dropping and recreating a 3.3k-character body to carry one
  /// smallint.
  ///
  /// Guarded server-side by `can_manage_fleet`: only the transporter that owns
  /// the truck can say, and a mine cannot change what its supplier's rig needs.
  Future<void> setVehicleSealPoints({
    required String vehicleId,
    required int sealPoints,
  }) async {
    try {
      await SupabaseConfig.client.rpc(
        'set_vehicle_seal_points',
        params: {'p_vehicle_id': vehicleId, 'p_seal_points': sealPoints},
      );
    } catch (e) {
      throw ErrorHandler.handleSupabaseError(e);
    }
  }

  /// Asks the super-admin to raise a truck's driver limit (3–5, CLAUDE.md §4).
  Future<void> requestDriverLimit({
    required String vehicleId,
    required int newLimit,
  }) async {
    try {
      await SupabaseConfig.client.rpc(
        'request_driver_limit',
        params: {'p_vehicle_id': vehicleId, 'p_new_limit': newLimit},
      );
    } catch (e) {
      throw ErrorHandler.handleSupabaseError(e);
    }
  }

  Future<FleetVehicle> unassignDriver(String vehicleId) async {
    try {
      final response = await _rpcVehicle(
        'unassign_fleet_driver',
        params: {'target_vehicle_id': vehicleId},
      );

      return _vehicleFromRecord(response);
    } catch (e) {
      throw ErrorHandler.handleSupabaseError(e);
    }
  }

  Future<void> deleteFleetVehicle(String vehicleId) async {
    try {
      final response = await _databaseService.getSupabaseClient().rpc(
        'delete_fleet_vehicle',
        params: {'target_vehicle_id': vehicleId},
      );

      if (response != true) {
        throw Exception('Failed to delete fleet vehicle');
      }
    } catch (e) {
      throw ErrorHandler.handleSupabaseError(e);
    }
  }

  Future<List<Map<String, dynamic>>> getAvailableDrivers(
    String companyId,
  ) async {
    try {
      final client = _databaseService.getSupabaseClient();

      // A driver can be on at most one truck, so "available" = no assignment
      // row at all (multi-driver per truck lives in driver_assignments now).
      final assignmentsResponse = await client
          .from('driver_assignments')
          .select('driver_employee_id')
          .eq('company_id', companyId);

      final assignedDriverIds = (assignmentsResponse as List)
          .map((row) => row['driver_employee_id'])
          .whereType<String>()
          .toSet();

      final driversResponse = await client
          .from('employees')
          .select()
          .eq('company_id', companyId)
          .eq('role', 'driver')
          .eq('status', 'active');

      final availableDrivers = (driversResponse as List)
          .where((driver) => !assignedDriverIds.contains(driver['id']))
          .map((driver) => Map<String, dynamic>.from(driver as Map))
          .toList();

      final resolvedDrivers = await _storageAssetService.resolveEmployeeRecords(
        availableDrivers,
      );

      resolvedDrivers.sort((a, b) {
        final aName = '${a['first_name'] ?? ''} ${a['last_name'] ?? ''}'
            .trim()
            .toLowerCase();
        final bName = '${b['first_name'] ?? ''} ${b['last_name'] ?? ''}'
            .trim()
            .toLowerCase();
        return aName.compareTo(bName);
      });

      return resolvedDrivers;
    } catch (e) {
      throw ErrorHandler.handleSupabaseError(e);
    }
  }

  Future<Map<String, dynamic>?> getCompanyById(String companyId) async {
    try {
      final response = await _databaseService.getRecord(
        'companies',
        'id',
        companyId,
      );
      return response == null
          ? null
          : _storageAssetService.resolveCompanyRecord(response);
    } catch (e) {
      _logger.e('Error getting company', e);
      throw ErrorHandler.handleSupabaseError(
        Exception('Failed to get company with ID $companyId: ${e.toString()}'),
      );
    }
  }

  Future<List<Map<String, dynamic>>> getCompanyEmployees(
    String companyId,
  ) async {
    try {
      final response = await _databaseService.getRecords(
        'employees',
        filters: {'company_id': companyId},
      );
      return _storageAssetService.resolveEmployeeRecords(response);
    } catch (e) {
      _logger.e('Error getting company employees', e);
      throw ErrorHandler.handleSupabaseError(
        Exception(
          'Failed to get employees for company ID $companyId: ${e.toString()}',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> _rpcVehicle(
    String functionName, {
    required Map<String, dynamic> params,
  }) async {
    final response = await _databaseService.getSupabaseClient().rpc(
      functionName,
      params: params,
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }

    throw Exception('Unexpected response from $functionName');
  }

  Future<String> _resolveDriverEmployeeId({
    required String companyId,
    required String driverReference,
  }) async {
    final client = _databaseService.getSupabaseClient();

    final byId = await client
        .from('employees')
        .select('id, user_id, company_id, role, status')
        .eq('id', driverReference)
        .maybeSingle();

    if (byId != null && byId['company_id'] == companyId) {
      return byId['id'] as String;
    }

    final byUserId = await client
        .from('employees')
        .select('id, user_id, company_id, role, status')
        .eq('user_id', driverReference)
        .maybeSingle();

    if (byUserId != null && byUserId['company_id'] == companyId) {
      return byUserId['id'] as String;
    }

    final employees = await client
        .from('employees')
        .select('id, user_id, company_id, role, status')
        .eq('company_id', companyId)
        .eq('role', 'driver');

    for (final employee in employees as List) {
      final record = Map<String, dynamic>.from(employee as Map);
      if (record['id'] == driverReference ||
          record['user_id'] == driverReference) {
        return record['id'] as String;
      }
    }

    throw Exception('Driver not found for company $companyId');
  }

  Future<FleetVehicle> _vehicleFromRecord(Map<String, dynamic> record) async {
    final resolvedRecord = await _storageAssetService.resolveFleetVehicleRecord(
      record,
    );
    return FleetVehicle.fromJson(resolvedRecord);
  }

  Future<List<FleetVehicle>> _vehiclesFromRecords(
    List<Map<String, dynamic>> records,
  ) async {
    final resolvedRecords = await _storageAssetService
        .resolveFleetVehicleRecords(records);
    return resolvedRecords.map(FleetVehicle.fromJson).toList();
  }
}
