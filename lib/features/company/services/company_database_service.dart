import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/cache_service.dart';
import 'package:flutter_application_1/core/services/database_service.dart';
import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/utils/whatsapp_identity.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/models/seat_limit.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';

class CompanyDatabaseService {
  final DatabaseService _databaseService;
  final StorageAssetService _storageAssetService = StorageAssetService();

  CompanyDatabaseService(this._databaseService);

  Future<Company> getCompanyByUserId(String userId) async {
    final cachedData = await CacheService.getCachedCompanyData(userId: userId);
    if (cachedData != null && cachedData['user_id'] == userId) {
      return _companyFromRecord(cachedData);
    }

    final data = await _databaseService.getRecord(
      'companies',
      'user_id',
      userId,
    );
    if (data == null) {
      throw Exception('Company not found');
    }

    await CacheService.cacheCompanyData(data);
    return _companyFromRecord(data);
  }

  Future<Company> getCompanyById(String companyId) async {
    final data = await _databaseService.getRecord('companies', 'id', companyId);
    if (data == null) {
      throw Exception('Company not found');
    }

    return _companyFromRecord(data);
  }

  Future<List<Company>> getAllCompanies() async {
    final data = await _databaseService.getRecords(
      'companies',
      orderBy: 'company_name',
    );

    return _companiesFromRecords(data);
  }

  Future<List<Employee>> getCompanyEmployees(String companyId) async {
    final cachedData = await CacheService.getCachedCompanyEmployees(companyId);
    if (cachedData != null) {
      return _employeesFromRecords(cachedData);
    }

    final data = await _databaseService.getRecords(
      'employees',
      filters: {'company_id': companyId},
      orderBy: 'first_name',
      ascending: true,
    );

    await CacheService.cacheCompanyEmployees(companyId, data);
    return _employeesFromRecords(data);
  }

  Future<Employee> getEmployeeById(String employeeId) async {
    final data = await _databaseService.getRecord(
      'employees',
      'id',
      employeeId,
    );
    if (data == null) {
      throw Exception('Employee not found');
    }

    return _employeeFromRecord(data);
  }

  Future<Employee> approveEmployeeRequest(String employeeId) async {
    final response = await SupabaseConfig.client.rpc(
      'approve_employee_request',
      params: {'target_employee_id': employeeId},
    );

    await CacheService.clearEmployeeCache();
    return _employeeFromRecord(Map<String, dynamic>.from(response));
  }

  Future<Employee> assignRoleToEmployee(
    String employeeId,
    UserRole role,
  ) async {
    final response = await SupabaseConfig.client.rpc(
      'assign_employee_role',
      params: {'target_employee_id': employeeId, 'target_role': role.name},
    );

    await CacheService.clearEmployeeCache();
    return _employeeFromRecord(Map<String, dynamic>.from(response));
  }

  Future<Employee> declineEmployeeRequest(String employeeId) async {
    final response = await SupabaseConfig.client.rpc(
      'decline_employee_request',
      params: {'target_employee_id': employeeId},
    );

    await CacheService.clearEmployeeCache();
    return _employeeFromRecord(Map<String, dynamic>.from(response));
  }

  Future<Employee> createManagedEmployee({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String whatsappNumber = '',
    required UserRole role,
  }) async {
    // Build the body - email falls back to the deterministic WhatsApp synthetic
    // email (same derivation the login form uses), so a WhatsApp-only create
    // still satisfies Supabase's per-user email requirement.
    final trimmedEmail = email.trim();
    final trimmedWhatsapp = whatsappNumber.trim();
    final effectiveEmail = trimmedEmail.isNotEmpty
        ? trimmedEmail.toLowerCase()
        : (trimmedWhatsapp.isNotEmpty ? whatsappAuthEmail(trimmedWhatsapp) : '');

    final body = <String, dynamic>{
      'action': 'create_employee',
      'email': effectiveEmail,
      'password': password,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'role': role.name,
    };

    // Only include whatsapp_number if provided
    if (trimmedWhatsapp.isNotEmpty) {
      body['whatsapp_number'] = trimmedWhatsapp;
    }

    final response = await SupabaseConfig.client.functions.invoke(
      'company-user-admin',
      body: body,
    );

    final responseData = _expectFunctionSuccess(
      response.status,
      response.data,
      fallbackMessage: 'Failed to create employee account',
    );
    final employeeJson = _expectEmployeeJson(responseData['employee']);

    await CacheService.clearEmployeeCache();
    return _employeeFromRecord(employeeJson);
  }

  Future<Employee> updateCompanyEmployee({
    required String employeeId,
    required String firstName,
    required String lastName,
    required String whatsappNumber,
  }) async {
    final response = await SupabaseConfig.client.rpc(
      'update_company_employee',
      params: {
        'target_employee_id': employeeId,
        'first_name_input': firstName.trim(),
        'last_name_input': lastName.trim(),
        'whatsapp_number_input': whatsappNumber.trim(),
      },
    );

    await CacheService.clearEmployeeCache();
    return _employeeFromRecord(Map<String, dynamic>.from(response));
  }

  Future<Employee> removeCompanyEmployee(String employeeId) async {
    final response = await SupabaseConfig.client.rpc(
      'remove_company_employee',
      params: {'target_employee_id': employeeId},
    );

    await CacheService.clearEmployeeCache();
    return _employeeFromRecord(Map<String, dynamic>.from(response));
  }

  Future<void> updateCompanyProfile(
    String companyId,
    Map<String, dynamic> data,
  ) async {
    final sanitizedData = Map<String, dynamic>.from(data);
    if (sanitizedData.containsKey('ceo_first_name') &&
        sanitizedData['ceo_first_name'] != null) {
      sanitizedData['ceo_first_name'] = sanitizedData['ceo_first_name']
          .toString()
          .trim();
    }
    if (sanitizedData.containsKey('ceo_last_name') &&
        sanitizedData['ceo_last_name'] != null) {
      sanitizedData['ceo_last_name'] = sanitizedData['ceo_last_name']
          .toString()
          .trim();
    }
    if (sanitizedData.containsKey('company_name') &&
        sanitizedData['company_name'] != null) {
      sanitizedData['company_name'] = sanitizedData['company_name']
          .toString()
          .trim();
    }
    if (sanitizedData.containsKey('whatsapp_number') &&
        sanitizedData['whatsapp_number'] != null) {
      sanitizedData['whatsapp_number'] = sanitizedData['whatsapp_number']
          .toString()
          .trim();
    }

    debugPrint(
      'Database service: Updating company profile: $companyId with data: $sanitizedData',
    );

    await SupabaseConfig.client.rpc(
      'update_my_company_profile',
      params: {
        'company_name_input': sanitizedData['company_name'],
        'whatsapp_number_input': sanitizedData['whatsapp_number'],
        'logo_url_input': sanitizedData['logo_url'],
        'ceo_first_name_input': sanitizedData['ceo_first_name'],
        'ceo_last_name_input': sanitizedData['ceo_last_name'],
        'support_contact_email_input': sanitizedData['support_contact_email'],
        'registration_number_input': sanitizedData['registration_number'],
        'vat_number_input': sanitizedData['vat_number'],
        'physical_address_input': sanitizedData['physical_address'],
      },
    );

    await CacheService.clearCompanyCache();
  }

  Future<Company> getCompanyWithRealTimeUpdates(String companyId) async {
    final data = await _databaseService.getRealtimeData(
      'companies',
      filters: {'id': companyId},
    );

    if (data.isEmpty) {
      throw Exception('Company not found');
    }

    return _companyFromRecord(data.first);
  }

  Future<List<Employee>> getCompanyEmployeesWithRealTimeUpdates(
    String companyId,
  ) async {
    final data = await _databaseService.getRealtimeData(
      'employees',
      filters: {'company_id': companyId},
      orderBy: 'first_name',
      ascending: true,
    );

    return _employeesFromRecords(data);
  }

  Future<Company> _companyFromRecord(Map<String, dynamic> record) async {
    final resolvedRecord = await _storageAssetService.resolveCompanyRecord(
      record,
    );
    return Company.fromJson(resolvedRecord);
  }

  Future<List<Company>> _companiesFromRecords(
    List<Map<String, dynamic>> records,
  ) async {
    final resolvedRecords = await _storageAssetService.resolveCompanyRecords(
      records,
    );
    return resolvedRecords.map(Company.fromJson).toList();
  }

  Future<Employee> _employeeFromRecord(Map<String, dynamic> record) async {
    final resolvedRecord = await _storageAssetService.resolveEmployeeRecord(
      record,
    );
    return Employee.fromJson(resolvedRecord);
  }

  Future<List<Employee>> _employeesFromRecords(
    List<Map<String, dynamic>> records,
  ) async {
    final resolvedRecords = await _storageAssetService.resolveEmployeeRecords(
      records,
    );
    return resolvedRecords.map(Employee.fromJson).toList();
  }

  Map<String, dynamic> _expectFunctionSuccess(
    int status,
    dynamic rawData, {
    required String fallbackMessage,
  }) {
    if (rawData is! Map && rawData is! Map<String, dynamic>) {
      if (status < 200 || status >= 300) {
        throw Exception(rawData?.toString() ?? fallbackMessage);
      }

      throw Exception(fallbackMessage);
    }

    final data = rawData is Map<String, dynamic>
        ? rawData
        : Map<String, dynamic>.from(rawData as Map);

    // The edge function flattens a Postgres failure to a string, so the
    // SQLSTATE would be lost here. It now forwards `code` alongside `error`,
    // which is the only way the seat gate can be told apart from every other
    // reason a create fails — and therefore the only way the UI can offer
    // "request extra seats" instead of a dead snackbar.
    final code = data['code']?.toString();

    if (status < 200 || status >= 300) {
      final message = data['error']?.toString() ?? fallbackMessage;
      if (code == kSeatLimitSqlState) throw SeatLimitException(message);
      throw Exception(message);
    }

    if (data['error'] != null) {
      final message = data['error'].toString();
      if (code == kSeatLimitSqlState) throw SeatLimitException(message);
      throw Exception(message);
    }

    return data;
  }

  Map<String, dynamic> _expectEmployeeJson(dynamic rawEmployee) {
    if (rawEmployee is Map<String, dynamic>) {
      return rawEmployee;
    }

    if (rawEmployee is Map) {
      return Map<String, dynamic>.from(rawEmployee);
    }

    throw Exception('Employee response payload was invalid');
  }
}

final companyDatabaseServiceProvider = Provider<CompanyDatabaseService>((ref) {
  final databaseService = ref.watch(databaseServiceProvider);
  return CompanyDatabaseService(databaseService);
});
