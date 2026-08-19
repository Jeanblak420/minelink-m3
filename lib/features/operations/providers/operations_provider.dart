import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/models/company_directory_entry.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/operations/services/operations_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class OperationsScope {
  final String companyId;
  final String userId;
  final OrgType orgType;

  const OperationsScope({
    required this.companyId,
    required this.userId,
    required this.orgType,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is OperationsScope &&
        other.companyId == companyId &&
        other.userId == userId &&
        other.orgType == orgType;
  }

  @override
  int get hashCode => Object.hash(companyId, userId, orgType);
}

class OperationsState {
  final List<CompanyDirectoryEntry> companies;
  final List<Employee> employees;
  final List<FleetVehicle> vehicles;
  final List<MineralRecord> minerals;
  final List<OperationTransaction> transactions;
  final List<WeighbridgeRecord> weighbridgeRecords;
  final List<MineralLoadRecord> mineralLoads;
  final List<SecurityIncidentRecord> securityIncidents;
  final List<GateCheckRecord> gateChecks;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const OperationsState({
    this.companies = const [],
    this.employees = const [],
    this.vehicles = const [],
    this.minerals = const [],
    this.transactions = const [],
    this.weighbridgeRecords = const [],
    this.mineralLoads = const [],
    this.securityIncidents = const [],
    this.gateChecks = const [],
    this.isLoading = true,
    this.isSaving = false,
    this.error,
  });

  OperationsState copyWith({
    List<CompanyDirectoryEntry>? companies,
    List<Employee>? employees,
    List<FleetVehicle>? vehicles,
    List<MineralRecord>? minerals,
    List<OperationTransaction>? transactions,
    List<WeighbridgeRecord>? weighbridgeRecords,
    List<MineralLoadRecord>? mineralLoads,
    List<SecurityIncidentRecord>? securityIncidents,
    List<GateCheckRecord>? gateChecks,
    bool? isLoading,
    bool? isSaving,
    String? error,
  }) {
    return OperationsState(
      companies: companies ?? this.companies,
      employees: employees ?? this.employees,
      vehicles: vehicles ?? this.vehicles,
      minerals: minerals ?? this.minerals,
      transactions: transactions ?? this.transactions,
      weighbridgeRecords: weighbridgeRecords ?? this.weighbridgeRecords,
      mineralLoads: mineralLoads ?? this.mineralLoads,
      securityIncidents: securityIncidents ?? this.securityIncidents,
      gateChecks: gateChecks ?? this.gateChecks,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class OperationsNotifier extends StateNotifier<OperationsState> {
  final OperationsService _service;
  final OperationsScope scope;
  final List<RealtimeChannel> _channels = [];
  Timer? _refreshDebounce;

  OperationsNotifier(this._service, this.scope)
    : super(const OperationsState()) {
    _initialize();
  }

  Future<void> _initialize() async {
    await refresh();
    _setupRealtime();
  }

  Future<void> refresh({bool withLoading = true}) async {
    try {
      state = state.copyWith(
        isLoading: withLoading ? true : state.isLoading,
        error: null,
      );

      final companiesFuture = _service.getCompanies();
      final employeesFuture = _service.getCompanyEmployees(scope.companyId);
      final vehiclesFuture = _service.getFleetVehicles(scope.companyId);
      final mineralsFuture = _service.getMinerals(scope.companyId);
      final transactionsFuture = _service.getTransactions(scope.companyId);
      final weighbridgeFuture = _service.getWeighbridgeRecords(scope.companyId);
      final loadsFuture = _service.getMineralLoads(scope.companyId);
      final securityFuture = _service.getSecurityIncidents(scope.companyId);
      final gateFuture = _service.getGateChecks(scope.companyId);

      final results = await Future.wait<dynamic>([
        companiesFuture,
        employeesFuture,
        vehiclesFuture,
        mineralsFuture,
        transactionsFuture,
        weighbridgeFuture,
        loadsFuture,
        securityFuture,
        gateFuture,
      ]);

      state = state.copyWith(
        companies: results[0] as List<CompanyDirectoryEntry>,
        employees: results[1] as List<Employee>,
        vehicles: results[2] as List<FleetVehicle>,
        minerals: results[3] as List<MineralRecord>,
        transactions: results[4] as List<OperationTransaction>,
        weighbridgeRecords: results[5] as List<WeighbridgeRecord>,
        mineralLoads: results[6] as List<MineralLoadRecord>,
        securityIncidents: results[7] as List<SecurityIncidentRecord>,
        gateChecks: results[8] as List<GateCheckRecord>,
        isLoading: false,
        isSaving: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isSaving: false,
        error: e.toString(),
      );
    }
  }

  void _setupRealtime() {
    _disposeChannels();

    _listen(
      SupabaseConfig.client.channel('operations-minerals-${scope.companyId}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'minerals',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: scope.companyId,
          ),
          callback: (_) => _scheduleRefresh(),
        ),
    );

    _listen(
      SupabaseConfig.client.channel(
          'operations-transactions-${scope.companyId}',
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'supplier_company_id',
            value: scope.companyId,
          ),
          callback: (_) => _scheduleRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'buyer_company_id',
            value: scope.companyId,
          ),
          callback: (_) => _scheduleRefresh(),
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transactions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'transporter_company_id',
            value: scope.companyId,
          ),
          callback: (_) => _scheduleRefresh(),
        ),
    );

    _listen(
      SupabaseConfig.client.channel('operations-weighbridge-${scope.companyId}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'weighbridge_records',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: scope.companyId,
          ),
          callback: (_) => _scheduleRefresh(),
        ),
    );

    _listen(
      SupabaseConfig.client.channel('operations-security-${scope.companyId}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'security_incidents',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: scope.companyId,
          ),
          callback: (_) => _scheduleRefresh(),
        ),
    );

    _listen(
      SupabaseConfig.client.channel('operations-gate-${scope.companyId}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'gate_checks',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: scope.companyId,
          ),
          callback: (_) => _scheduleRefresh(),
        ),
    );

    _listen(
      SupabaseConfig.client.channel('operations-loads-${scope.companyId}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'mineral_loads',
          callback: (payload) {
            if (_isRelevantMineralLoadChange(payload)) {
              _scheduleRefresh();
            }
          },
        ),
    );

    _listen(
      SupabaseConfig.client.channel('operations-employees-${scope.companyId}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'employees',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: scope.companyId,
          ),
          callback: (_) => _scheduleRefresh(),
        ),
    );

    _listen(
      SupabaseConfig.client.channel('operations-fleet-${scope.companyId}')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'fleet_vehicles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'company_id',
            value: scope.companyId,
          ),
          callback: (_) => _scheduleRefresh(),
        ),
    );
  }

  void _listen(RealtimeChannel channel) {
    _channels.add(channel);
    channel.subscribe();
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 120), () {
      refresh(withLoading: false);
    });
  }

  bool _isRelevantMineralLoadChange(PostgresChangePayload payload) {
    final vehicleId =
        payload.newRecord['vehicle_id']?.toString() ??
        payload.oldRecord['vehicle_id']?.toString();
    if (vehicleId == null || vehicleId.isEmpty) {
      return true;
    }

    return state.vehicles.any((vehicle) => vehicle.id == vehicleId);
  }

  Future<void> saveMineral({
    String? id,
    required String name,
    String? grade,
    String? description,
    required String unitOfMeasure,
  }) async {
    await _runSave(
      () => _service.saveMineral(
        id: id,
        companyId: scope.companyId,
        userId: scope.userId,
        name: name,
        grade: grade,
        description: description,
        unitOfMeasure: unitOfMeasure,
      ),
    );
  }

  Future<void> saveTransaction({
    String? id,
    String? mineralId,
    String? supplierCompanyId,
    String? buyerCompanyId,
    String? transporterCompanyId,
    required String referenceNumber,
    required String status,
    required double quantity,
    Map<String, dynamic>? metadata,
  }) async {
    await _runSave(
      () => _service.saveTransaction(
        id: id,
        userId: scope.userId,
        mineralId: mineralId,
        supplierCompanyId: supplierCompanyId,
        buyerCompanyId: buyerCompanyId,
        transporterCompanyId: transporterCompanyId,
        referenceNumber: referenceNumber,
        status: status,
        quantity: quantity,
        metadata: metadata,
      ),
    );
  }

  Future<void> saveWeighbridgeRecord({
    String? id,
    String? transactionId,
    String? vehicleId,
    required String direction,
    double? grossWeight,
    double? tareWeight,
    double? netWeight,
    DateTime? recordedAt,
  }) async {
    await _runSave(
      () => _service.saveWeighbridgeRecord(
        id: id,
        companyId: scope.companyId,
        userId: scope.userId,
        transactionId: transactionId,
        vehicleId: vehicleId,
        direction: direction,
        grossWeight: grossWeight,
        tareWeight: tareWeight,
        netWeight: netWeight,
        recordedAt: recordedAt,
      ),
    );
  }

  Future<void> saveMineralLoad({
    String? id,
    String? transactionId,
    String? vehicleId,
    String? mineralId,
    String? loaderEmployeeId,
    String? notes,
    DateTime? loadedAt,
  }) async {
    await _runSave(
      () => _service.saveMineralLoad(
        id: id,
        transactionId: transactionId,
        vehicleId: vehicleId,
        mineralId: mineralId,
        loaderEmployeeId: loaderEmployeeId,
        notes: notes,
        loadedAt: loadedAt,
      ),
    );
  }

  Future<void> saveSecurityIncident({
    String? id,
    String? employeeId,
    String? vehicleId,
    required String severity,
    required String title,
    String? description,
    required String status,
    DateTime? occurredAt,
  }) async {
    await _runSave(
      () => _service.saveSecurityIncident(
        id: id,
        companyId: scope.companyId,
        userId: scope.userId,
        employeeId: employeeId,
        vehicleId: vehicleId,
        severity: severity,
        title: title,
        description: description,
        status: status,
        occurredAt: occurredAt,
      ),
    );
  }

  Future<void> saveGateCheck({
    String? id,
    String? employeeId,
    String? vehicleId,
    required String checkType,
    required String gateStatus,
    String? notes,
    DateTime? checkedAt,
  }) async {
    await _runSave(
      () => _service.saveGateCheck(
        id: id,
        companyId: scope.companyId,
        userId: scope.userId,
        employeeId: employeeId,
        vehicleId: vehicleId,
        checkType: checkType,
        gateStatus: gateStatus,
        notes: notes,
        checkedAt: checkedAt,
      ),
    );
  }

  Future<void> _runSave(Future<dynamic> Function() action) async {
    try {
      state = state.copyWith(isSaving: true, error: null);
      await action();
      await refresh(withLoading: false);
    } catch (e) {
      state = state.copyWith(isSaving: false, error: e.toString());
      rethrow;
    }
  }

  void _disposeChannels() {
    _refreshDebounce?.cancel();
    for (final channel in _channels) {
      channel.unsubscribe();
    }
    _channels.clear();
  }

  @override
  void dispose() {
    _disposeChannels();
    super.dispose();
  }
}

final operationsServiceProvider = Provider<OperationsService>((ref) {
  return OperationsService();
});

final operationsProvider = StateNotifierProvider.autoDispose
    .family<OperationsNotifier, OperationsState, OperationsScope>((ref, scope) {
      return OperationsNotifier(ref.watch(operationsServiceProvider), scope);
    });
