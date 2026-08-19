import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/company/models/company_directory_entry.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OperationsService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// Companies for the transaction editor's Supplier / Buyer / Transporter
  /// dropdowns — id, name, org type and logo only.
  ///
  /// P3-43 §2b. This was `from('companies').select()` — every row, every column
  /// — fired on **every** `OperationsNotifier.refresh()`, i.e. every visit to
  /// the Operations Hub by any user with a company scope.
  ///
  /// ⚠ The prepared change guessed this result was "dead weight on the refresh
  /// path". It is not: `state.companies` feeds three counterparty dropdowns in
  /// the transaction editor (`operations_hub_screen.dart`), which read exactly
  /// `id` and `companyName`. So it could not simply be deleted — and it could
  /// not be narrowed to counterparties either, because picking a counterparty
  /// you have not yet transacted with is the entire purpose of a picker. The
  /// directory RPC is the resolution: the full row set the picker needs, minus
  /// every commercial column it never rendered.
  Future<List<CompanyDirectoryEntry>> getCompanies() async {
    final response = await _supabase.rpc('list_company_directory');
    return (response as List)
        .map((json) => CompanyDirectoryEntry.fromJson(
            Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<List<Employee>> getCompanyEmployees(String companyId) async {
    final response = await _supabase
        .from('employees')
        .select()
        .eq('company_id', companyId)
        .order('first_name');
    return response.map(Employee.fromJson).toList();
  }

  Future<List<FleetVehicle>> getFleetVehicles(String companyId) async {
    final response = await _supabase
        .from('fleet_vehicles')
        .select()
        .eq('company_id', companyId)
        .order('created_at', ascending: false);
    return response.map(FleetVehicle.fromJson).toList();
  }

  Future<List<MineralRecord>> getMinerals(String companyId) async {
    final response = await _supabase
        .from('minerals')
        .select()
        .eq('company_id', companyId)
        .order('updated_at', ascending: false);
    return response.map(MineralRecord.fromJson).toList();
  }

  Future<List<OperationTransaction>> getTransactions(String companyId) async {
    final response = await _supabase
        .from('transactions')
        .select()
        .or(
          'supplier_company_id.eq.$companyId,buyer_company_id.eq.$companyId,transporter_company_id.eq.$companyId',
        )
        .order('updated_at', ascending: false);
    return response.map(OperationTransaction.fromJson).toList();
  }

  Future<List<WeighbridgeRecord>> getWeighbridgeRecords(
    String companyId,
  ) async {
    final response = await _supabase
        .from('weighbridge_records')
        .select()
        .eq('company_id', companyId)
        .order('recorded_at', ascending: false);
    return response.map(WeighbridgeRecord.fromJson).toList();
  }

  Future<List<MineralLoadRecord>> getMineralLoads(String companyId) async {
    final vehicles = await getFleetVehicles(companyId);
    if (vehicles.isEmpty) {
      return const [];
    }

    final response = await _supabase
        .from('mineral_loads')
        .select()
        .inFilter('vehicle_id', vehicles.map((vehicle) => vehicle.id).toList())
        .order('loaded_at', ascending: false);
    return response.map(MineralLoadRecord.fromJson).toList();
  }

  Future<List<SecurityIncidentRecord>> getSecurityIncidents(
    String companyId,
  ) async {
    final response = await _supabase
        .from('security_incidents')
        .select()
        .eq('company_id', companyId)
        .order('occurred_at', ascending: false);
    return response.map(SecurityIncidentRecord.fromJson).toList();
  }

  Future<List<GateCheckRecord>> getGateChecks(String companyId) async {
    final response = await _supabase
        .from('gate_checks')
        .select()
        .eq('company_id', companyId)
        .order('checked_at', ascending: false);
    return response.map(GateCheckRecord.fromJson).toList();
  }

  Future<MineralRecord> saveMineral({
    String? id,
    required String companyId,
    required String userId,
    required String name,
    String? grade,
    String? description,
    required String unitOfMeasure,
  }) async {
    final payload = <String, dynamic>{
      'company_id': companyId,
      'name': name.trim(),
      'grade': _nullIfBlank(grade),
      'description': _nullIfBlank(description),
      'unit_of_measure': unitOfMeasure.trim(),
      'created_by': userId,
    };

    if (id == null) {
      final response = await _supabase
          .from('minerals')
          .insert(payload)
          .select()
          .single();
      return MineralRecord.fromJson(response);
    }

    final response = await _supabase
        .from('minerals')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return MineralRecord.fromJson(response);
  }

  Future<OperationTransaction> saveTransaction({
    String? id,
    required String userId,
    String? mineralId,
    String? supplierCompanyId,
    String? buyerCompanyId,
    String? transporterCompanyId,
    required String referenceNumber,
    required String status,
    required double quantity,
    Map<String, dynamic>? metadata,
  }) async {
    final payload = <String, dynamic>{
      'mineral_id': mineralId,
      'supplier_company_id': supplierCompanyId,
      'buyer_company_id': buyerCompanyId,
      'transporter_company_id': transporterCompanyId,
      'reference_number': referenceNumber.trim(),
      'status': status,
      'quantity': quantity,
      'metadata': metadata ?? const <String, dynamic>{},
      'created_by': userId,
    };

    if (id == null) {
      final response = await _supabase
          .from('transactions')
          .insert(payload)
          .select()
          .single();
      return OperationTransaction.fromJson(response);
    }

    final response = await _supabase
        .from('transactions')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return OperationTransaction.fromJson(response);
  }

  Future<WeighbridgeRecord> saveWeighbridgeRecord({
    String? id,
    required String companyId,
    required String userId,
    String? transactionId,
    String? vehicleId,
    required String direction,
    double? grossWeight,
    double? tareWeight,
    double? netWeight,
    DateTime? recordedAt,
  }) async {
    final payload = <String, dynamic>{
      'company_id': companyId,
      'transaction_id': transactionId,
      'vehicle_id': vehicleId,
      'direction': direction,
      'gross_weight': grossWeight,
      'tare_weight': tareWeight,
      'net_weight': netWeight,
      'recorded_by': userId,
      'recorded_at': (recordedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };

    if (id == null) {
      final response = await _supabase
          .from('weighbridge_records')
          .insert(payload)
          .select()
          .single();
      return WeighbridgeRecord.fromJson(response);
    }

    final response = await _supabase
        .from('weighbridge_records')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return WeighbridgeRecord.fromJson(response);
  }

  Future<MineralLoadRecord> saveMineralLoad({
    String? id,
    String? transactionId,
    String? vehicleId,
    String? mineralId,
    String? loaderEmployeeId,
    String? notes,
    DateTime? loadedAt,
  }) async {
    final payload = <String, dynamic>{
      'transaction_id': transactionId,
      'vehicle_id': vehicleId,
      'mineral_id': mineralId,
      'loader_employee_id': loaderEmployeeId,
      'notes': _nullIfBlank(notes),
      'loaded_at': (loadedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };

    if (id == null) {
      final response = await _supabase
          .from('mineral_loads')
          .insert(payload)
          .select()
          .single();
      return MineralLoadRecord.fromJson(response);
    }

    final response = await _supabase
        .from('mineral_loads')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return MineralLoadRecord.fromJson(response);
  }

  Future<SecurityIncidentRecord> saveSecurityIncident({
    String? id,
    required String companyId,
    required String userId,
    String? employeeId,
    String? vehicleId,
    required String severity,
    required String title,
    String? description,
    required String status,
    DateTime? occurredAt,
  }) async {
    final payload = <String, dynamic>{
      'company_id': companyId,
      'employee_id': employeeId,
      'vehicle_id': vehicleId,
      'severity': severity,
      'title': title.trim(),
      'description': _nullIfBlank(description),
      'status': status,
      'reported_by': userId,
      'occurred_at': (occurredAt ?? DateTime.now()).toUtc().toIso8601String(),
    };

    if (status == 'resolved' || status == 'closed') {
      payload['resolved_by'] = userId;
    }

    if (id == null) {
      final response = await _supabase
          .from('security_incidents')
          .insert(payload)
          .select()
          .single();
      return SecurityIncidentRecord.fromJson(response);
    }

    final response = await _supabase
        .from('security_incidents')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return SecurityIncidentRecord.fromJson(response);
  }

  Future<GateCheckRecord> saveGateCheck({
    String? id,
    required String companyId,
    required String userId,
    String? employeeId,
    String? vehicleId,
    required String checkType,
    required String gateStatus,
    String? notes,
    DateTime? checkedAt,
  }) async {
    final payload = <String, dynamic>{
      'company_id': companyId,
      'employee_id': employeeId,
      'vehicle_id': vehicleId,
      'check_type': checkType,
      'gate_status': gateStatus,
      'notes': _nullIfBlank(notes),
      'checked_by': userId,
      'checked_at': (checkedAt ?? DateTime.now()).toUtc().toIso8601String(),
    };

    if (id == null) {
      final response = await _supabase
          .from('gate_checks')
          .insert(payload)
          .select()
          .single();
      return GateCheckRecord.fromJson(response);
    }

    final response = await _supabase
        .from('gate_checks')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return GateCheckRecord.fromJson(response);
  }

  String? _nullIfBlank(String? value) {
    if (value == null) {
      return null;
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
