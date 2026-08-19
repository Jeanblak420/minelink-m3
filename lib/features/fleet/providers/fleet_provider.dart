import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/services/database_service.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/models/vehicle_driver.dart';
import 'package:flutter_application_1/features/fleet/services/fleet_service.dart';
import 'package:flutter_application_1/features/fleet/services/fleet_document_debug_service.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final fleetServiceProvider = Provider<FleetService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return FleetService(databaseService);
});

/// Live route-availability for a transporter's fleet (Available vs On Route),
/// keyed by company id. Used by the accept-route truck picker (available only)
/// and the "Trucks On Route" screen. Invalidate after accepting a route.
final fleetStatusProvider =
    FutureProvider.family<List<FleetVehicleStatus>, String>((ref, companyId) {
  return ref.read(fleetServiceProvider).getFleetStatus(companyId);
});

/// Every driver assignment in a company (multi-driver per truck), with each
/// driver's derived On-Route status. Invalidate after add/remove.
final vehicleDriversProvider =
    FutureProvider.family<List<VehicleDriver>, String>((ref, companyId) {
  return ref.read(fleetServiceProvider).listVehicleDrivers(companyId);
});

final fleetDocumentDebugServiceProvider = Provider<FleetDocumentDebugService>((
  ref,
) {
  final databaseService = ref.watch(databaseServiceProvider);
  return FleetDocumentDebugService(databaseService);
});

class FleetState {
  final List<FleetVehicle> vehicles;
  final bool isLoading;
  final String? error;
  final List<Map<String, dynamic>> availableDrivers;
  final bool isLoadingDrivers;

  FleetState({
    this.vehicles = const [],
    this.isLoading = false,
    this.error,
    this.availableDrivers = const [],
    this.isLoadingDrivers = false,
  });

  FleetState copyWith({
    List<FleetVehicle>? vehicles,
    bool? isLoading,
    String? error,
    List<Map<String, dynamic>>? availableDrivers,
    bool? isLoadingDrivers,
  }) {
    return FleetState(
      vehicles: vehicles ?? this.vehicles,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      availableDrivers: availableDrivers ?? this.availableDrivers,
      isLoadingDrivers: isLoadingDrivers ?? this.isLoadingDrivers,
    );
  }

  List<FleetVehicle> get activeVehicles =>
      vehicles.where((vehicle) => vehicle.isActive).toList();

  List<FleetVehicle> get inactiveVehicles =>
      vehicles.where((vehicle) => !vehicle.isActive).toList();

  List<FleetVehicle> get assignedVehicles =>
      activeVehicles.where((vehicle) => vehicle.hasAssignedDriver).toList();

  List<FleetVehicle> get unassignedVehicles =>
      activeVehicles.where((vehicle) => !vehicle.hasAssignedDriver).toList();
}

class FleetNotifier extends StateNotifier<FleetState> {
  final FleetService _fleetService;
  final Ref _ref;
  final String companyId;
  RealtimeChannel? _fleetChannel;

  FleetNotifier(this._fleetService, this._ref, this.companyId)
      : super(FleetState()) {
    loadFleetVehicles();
    _setupRealtime();
  }

  /// Everything else in the app that reads driver assignments or route
  /// availability, re-read after this notifier changes either.
  ///
  /// This notifier used to patch only its OWN `FleetState`, so the Fleet
  /// Register row updated and nothing else did. Measured 2026-08-17: after
  /// unassigning Sipho Driver from S6W001GP through the register — with
  /// `driver_assignments` holding **zero rows** for that truck — the
  /// accept-route truck picker still read "S6W001GP · Sipho Driver · 1/2
  /// drivers", and the Trucks-on-route assign dialog still offered "Remove
  /// from truck" for a driver who was no longer on it. The dialogs that live
  /// in `driver_assignment_dialog.dart` have always refreshed correctly; the
  /// register's own row actions never did.
  ///
  /// A fleet manager acting on that stale list assigns a load to a driver who
  /// is not there, which is the same class of defect as the driverless truck
  /// `accept_request_dispatch` now warns about — just arriving from the UI
  /// side instead.
  void _refreshDerived() {
    _ref.invalidate(vehicleDriversProvider(companyId));
    _ref.invalidate(fleetStatusProvider(companyId));
  }

  void _setupRealtime() {
    _fleetChannel?.unsubscribe();
    _fleetChannel = SupabaseConfig.client.channel('fleet-$companyId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'fleet_vehicles',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'company_id',
          value: companyId,
        ),
        callback: (_) async {
          await loadFleetVehicles();
          await loadAvailableDrivers();
          // Another session's assignment counts too — `sync_vehicle_primary_
          // driver` writes `fleet_vehicles`, so this channel sees it.
          _refreshDerived();
        },
      )
      ..subscribe();
  }

  @override
  void dispose() {
    _fleetChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> loadFleetVehicles() async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final vehicles = await _fleetService.getFleetVehicles(companyId);
      state = state.copyWith(vehicles: vehicles, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load fleet vehicles: ${e.toString()}',
      );
    }
  }

  Future<void> addFleetVehicle({
    required String vehicleRegistrationNumber,
    DateTime? vehicleRegistrationExpiryDate,
    String? firstTrailerRegs,
    String? secondTrailerRegs,
    String? vehicleMake,
    String? vehicleType,
    int? vehicleYearModel,
    int? vehicleOdometerKm,
    /// Seal points on the rig (1-4). Applied after the vehicle exists, via
    /// its own guarded RPC — see FleetService.setVehicleSealPoints.
    int? sealPoints,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final newVehicle = await _fleetService.addFleetVehicle(
        vehicleRegistrationNumber: vehicleRegistrationNumber,
        companyId: companyId,
        vehicleRegistrationExpiryDate: vehicleRegistrationExpiryDate,
        firstTrailerRegs: firstTrailerRegs,
        secondTrailerRegs: secondTrailerRegs,
        vehicleMake: vehicleMake,
        vehicleType: vehicleType,
        vehicleYearModel: vehicleYearModel,
        vehicleOdometerKm: vehicleOdometerKm,
      );

      // The vehicle has to exist before its seal count can be stated.
      // create_fleet_vehicle derives a starting value from the trailers;
      // this only speaks up when the operator chose something else.
      var stored = newVehicle;
      if (sealPoints != null && sealPoints != stored.sealPoints) {
        await _fleetService.setVehicleSealPoints(
          vehicleId: stored.id, sealPoints: sealPoints);
        stored = stored.copyWith(sealPoints: sealPoints);
      }

      state = state.copyWith(
        vehicles: [...state.vehicles, stored],
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to add vehicle: ${e.toString()}',
      );
    }
  }

  Future<void> updateFleetVehicle({
    required String id,
    String? vehicleRegistrationNumber,
    DateTime? vehicleRegistrationExpiryDate,
    String? firstTrailerRegs,
    String? secondTrailerRegs,
    String? vehicleMake,
    String? vehicleType,
    int? vehicleYearModel,
    int? vehicleOdometerKm,
    bool clearVehicleMake = false,
    bool clearVehicleType = false,
    bool clearVehicleYearModel = false,
    bool clearVehicleOdometerKm = false,
    /// Seal points on the rig (1-4), applied via its own guarded RPC.
    int? sealPoints,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final updatedVehicle = await _fleetService.updateFleetVehicle(
        id: id,
        vehicleRegistrationNumber: vehicleRegistrationNumber,
        vehicleRegistrationExpiryDate: vehicleRegistrationExpiryDate,
        firstTrailerRegs: firstTrailerRegs,
        secondTrailerRegs: secondTrailerRegs,
        vehicleMake: vehicleMake,
        vehicleType: vehicleType,
        vehicleYearModel: vehicleYearModel,
        vehicleOdometerKm: vehicleOdometerKm,
        clearVehicleMake: clearVehicleMake,
        clearVehicleType: clearVehicleType,
        clearVehicleYearModel: clearVehicleYearModel,
        clearVehicleOdometerKm: clearVehicleOdometerKm,
      );

      var stored = updatedVehicle;
      if (sealPoints != null && sealPoints != stored.sealPoints) {
        await _fleetService.setVehicleSealPoints(
          vehicleId: id, sealPoints: sealPoints);
        stored = stored.copyWith(sealPoints: sealPoints);
      }

      final updatedVehicles = state.vehicles.map((vehicle) {
        return vehicle.id == id ? stored : vehicle;
      }).toList();

      state = state.copyWith(vehicles: updatedVehicles, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to update vehicle: ${e.toString()}',
      );
    }
  }

  Future<void> assignDriver({
    required String vehicleId,
    required String driverId,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final updatedVehicle = await _fleetService.assignDriver(
        vehicleId: vehicleId,
        companyId: companyId,
        driverId: driverId,
      );

      final updatedVehicles = state.vehicles.map((vehicle) {
        return vehicle.id == vehicleId ? updatedVehicle : vehicle;
      }).toList();

      state = state.copyWith(vehicles: updatedVehicles, isLoading: false);

      await loadAvailableDrivers();
      _refreshDerived();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to assign driver: ${e.toString()}',
      );
    }
  }

  Future<void> unassignDriver(String vehicleId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final updatedVehicle = await _fleetService.unassignDriver(vehicleId);

      final updatedVehicles = state.vehicles.map((vehicle) {
        return vehicle.id == vehicleId ? updatedVehicle : vehicle;
      }).toList();

      state = state.copyWith(vehicles: updatedVehicles, isLoading: false);

      await loadAvailableDrivers();
      _refreshDerived();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to unassign driver: ${e.toString()}',
      );
    }
  }

  Future<void> markVehicleAsInactive(String vehicleId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final vehicle = state.vehicles.firstWhere((v) => v.id == vehicleId);

      if (vehicle.hasAssignedDriver) {
        await _fleetService.unassignDriver(vehicleId);
      }

      final updatedVehicle = await _fleetService.updateFleetVehicle(
        id: vehicleId,
        isActive: false,
      );

      final updatedVehicles = state.vehicles.map((v) {
        return v.id == vehicleId ? updatedVehicle : v;
      }).toList();

      state = state.copyWith(vehicles: updatedVehicles, isLoading: false);

      await loadAvailableDrivers();
      _refreshDerived();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to mark vehicle as inactive: ${e.toString()}',
      );
    }
  }

  Future<void> markVehicleAsActive(String vehicleId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final updatedVehicle = await _fleetService.updateFleetVehicle(
        id: vehicleId,
        isActive: true,
      );

      final updatedVehicles = state.vehicles.map((v) {
        return v.id == vehicleId ? updatedVehicle : v;
      }).toList();

      state = state.copyWith(vehicles: updatedVehicles, isLoading: false);
      _refreshDerived();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to mark vehicle as active: ${e.toString()}',
      );
    }
  }

  Future<void> deleteFleetVehicle(String vehicleId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      await _fleetService.deleteFleetVehicle(vehicleId);

      state = state.copyWith(
        vehicles: state.vehicles
            .where((vehicle) => vehicle.id != vehicleId)
            .toList(),
        isLoading: false,
      );

      await loadAvailableDrivers();
      _refreshDerived();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to delete vehicle: ${e.toString()}',
      );
    }
  }

  Future<void> loadAvailableDrivers() async {
    try {
      state = state.copyWith(isLoadingDrivers: true, error: null);

      final drivers = await _fleetService.getAvailableDrivers(companyId);

      state = state.copyWith(
        availableDrivers: drivers,
        isLoadingDrivers: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingDrivers: false,
        error: 'Failed to load available drivers: ${e.toString()}',
      );
    }
  }

  Future<Map<String, dynamic>> verifyVehicleDocumentUrls(
    String vehicleId,
  ) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final fleetDocumentDebugService = FleetDocumentDebugService(
        _fleetService.getDatabaseService(),
      );
      final result = await fleetDocumentDebugService.verifyVehicleDocumentUrls(
        vehicleId,
      );

      state = state.copyWith(isLoading: false);
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to verify document URLs: ${e.toString()}',
      );
      return {
        'status': 'error',
        'message': e.toString(),
        'vehicle_id': vehicleId,
      };
    }
  }

  Future<void> fixVehicleDocumentUrls(String vehicleId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final fleetDocumentDebugService = FleetDocumentDebugService(
        _fleetService.getDatabaseService(),
      );
      final updatedVehicle = await fleetDocumentDebugService
          .fixVehicleDocumentUrls(vehicleId);

      final updatedVehicles = state.vehicles.map((v) {
        return v.id == vehicleId ? updatedVehicle : v;
      }).toList();

      state = state.copyWith(vehicles: updatedVehicles, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to fix document URLs: ${e.toString()}',
      );
    }
  }
}

final fleetProvider =
    StateNotifierProvider.family<FleetNotifier, FleetState, String>((
      ref,
      companyId,
    ) {
      final fleetService = ref.watch(fleetServiceProvider);
      return FleetNotifier(fleetService, ref, companyId);
    });

final currentUserFleetProvider =
    Provider<StateNotifierProvider<FleetNotifier, FleetState>?>((ref) {
      final companyState = ref.watch(companyProvider);
      final employeeState = ref.watch(employeeProvider);

      if (companyState.company != null) {
        return fleetProvider(companyState.company!.id);
      }

      if (employeeState.employee != null &&
          employeeState.employee!.companyId != null) {
        return fleetProvider(employeeState.employee!.companyId!);
      }

      return null;
    });
