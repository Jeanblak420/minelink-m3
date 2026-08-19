import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/cache_service.dart';
import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/core/utils/error_handler.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';

class EmployeeService {
  final _supabase = SupabaseConfig.client;
  final _storageAssetService = StorageAssetService();

  Future<Employee> getEmployeeByUserId(String userId) async {
    try {
      final cachedData = await CacheService.getCachedEmployeeData(
        userId: userId,
      );
      if (cachedData != null && cachedData['user_id'] == userId) {
        return _employeeFromRecord(cachedData);
      }

      final results = await _supabase
          .from('employees')
          .select()
          .eq('user_id', userId);

      if (results.isEmpty) {
        throw Exception('Employee not found');
      }

      final data = results.first;
      await CacheService.cacheEmployeeData(data);
      await CacheService.setCurrentUserId(userId);

      return _employeeFromRecord(data);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<Employee> getEmployeeById(String employeeId) async {
    try {
      final results = await _supabase
          .from('employees')
          .select()
          .eq('id', employeeId);

      if (results.isEmpty) {
        throw Exception('Employee not found');
      }

      return _employeeFromRecord(results.first);
    } catch (e) {
      throw _handleError(e);
    }
  }

  bool isValidUuid(String input) {
    final regex = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return regex.hasMatch(input);
  }

  Future<Employee> linkEmployeeToCompany(
    String employeeId,
    String companyId,
  ) async {
    if (!isValidUuid(employeeId)) {
      throw Exception('Invalid employeeId: must be a valid UUID');
    }
    if (!isValidUuid(companyId)) {
      throw Exception('Invalid companyId: must be a valid UUID');
    }

    try {
      final response = await _supabase.rpc(
        'request_company_link',
        params: {'target_company_id': companyId},
      );

      await CacheService.clearEmployeeCache();
      return _employeeFromRecord(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error requesting company link: $e');
      throw _handleError(e);
    }
  }

  Future<Employee> updateEmployeeProfile(
    String employeeId,
    Map<String, dynamic> data,
  ) async {
    try {
      final sanitizedData = Map<String, dynamic>.from(data);
      if (sanitizedData.containsKey('company_id')) {
        sanitizedData.remove('company_id');
      }

      final response = await _supabase.rpc(
        'update_my_employee_profile',
        params: {
          'first_name_input': sanitizedData['first_name'],
          'last_name_input': sanitizedData['last_name'],
          'whatsapp_number_input': sanitizedData['whatsapp_number'],
          'profile_photo_url_input': sanitizedData['profile_photo_url'],
          'is_south_african_citizen_input':
              sanitizedData['is_south_african_citizen'],
          'id_number_input': sanitizedData['id_number'],
          'passport_or_workers_permit_input':
              sanitizedData['passport_or_workers_permit'],
          'license_document_input': sanitizedData['license_document'],
          'id_document_url_input': sanitizedData['id_document_url'],
          'passport_document_url_input': sanitizedData['passport_document_url'],
          'work_visa_document_url_input':
              sanitizedData['work_visa_document_url'],
          'license_document_url_input': sanitizedData['license_document_url'],
          'date_of_birth_input': sanitizedData['date_of_birth'],
          'residential_address_input': sanitizedData['residential_address'],
          'emergency_contact_name_input':
              sanitizedData['emergency_contact_name'],
          'emergency_contact_phone_input':
              sanitizedData['emergency_contact_phone'],
          'contact_email_input': sanitizedData['contact_email'],
          'employment_start_date_input':
              sanitizedData['employment_start_date'],
          'license_codes_input': sanitizedData['license_codes'],
          'psira_grade_input': sanitizedData['psira_grade'],
        },
      );

      await CacheService.clearEmployeeCache();
      return _employeeFromRecord(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error updating employee profile: $e');
      throw _handleError(e);
    }
  }

  Future<String> uploadProfilePhoto(
    String employeeId,
    Uint8List fileBytes,
    String fileName,
  ) async {
    return _uploadEmployeeAsset(
      employeeId: employeeId,
      fileBytes: fileBytes,
      fileName: fileName,
      folderName: 'profile_photos',
      storedFileName: 'photo',
      targetField: 'profile_photo_url',
    );
  }

  Future<String> uploadIdDocument(
    String employeeId,
    Uint8List fileBytes,
    String fileName,
  ) async {
    return _uploadEmployeeAsset(
      employeeId: employeeId,
      fileBytes: fileBytes,
      fileName: fileName,
      folderName: 'id_documents',
      storedFileName: 'id_document',
      targetField: 'id_document_url',
    );
  }

  Future<String> uploadPassportDocument(
    String employeeId,
    Uint8List fileBytes,
    String fileName,
  ) async {
    return _uploadEmployeeAsset(
      employeeId: employeeId,
      fileBytes: fileBytes,
      fileName: fileName,
      folderName: 'passport_documents',
      storedFileName: 'passport',
      targetField: 'passport_document_url',
    );
  }

  Future<String> uploadWorkVisaDocument(
    String employeeId,
    Uint8List fileBytes,
    String fileName,
  ) async {
    return _uploadEmployeeAsset(
      employeeId: employeeId,
      fileBytes: fileBytes,
      fileName: fileName,
      folderName: 'work_visa_documents',
      storedFileName: 'work_visa',
      targetField: 'work_visa_document_url',
    );
  }

  Future<String> uploadLicenseDocument(
    String employeeId,
    Uint8List fileBytes,
    String fileName,
  ) async {
    return _uploadEmployeeAsset(
      employeeId: employeeId,
      fileBytes: fileBytes,
      fileName: fileName,
      folderName: 'license_documents',
      storedFileName: 'license',
      targetField: 'license_document_url',
    );
  }

  Future<String> _uploadEmployeeAsset({
    required String employeeId,
    required Uint8List fileBytes,
    required String fileName,
    required String folderName,
    required String storedFileName,
    required String targetField,
  }) async {
    try {
      final fileExt = _fileExtension(fileName);
      final filePath = '$folderName/$employeeId/$storedFileName.$fileExt';

      await _supabase.storage
          .from('employee_assets')
          .uploadBinary(
            filePath,
            fileBytes,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: true),
          );

      await updateEmployeeProfile(employeeId, {targetField: filePath});
      return (await _storageAssetService.resolveEmployeeAssetUrl(filePath))!;
    } catch (e) {
      throw _handleError(e);
    }
  }

  String _fileExtension(String fileName) {
    final parts = fileName.split('.');
    if (parts.length < 2 || parts.last.trim().isEmpty) {
      throw Exception('Invalid file name: missing extension');
    }
    return parts.last;
  }

  Exception _handleError(dynamic error) {
    final errorMessage = ErrorHandler.getErrorMessage(error);
    return Exception(errorMessage);
  }

  Future<List<Map<String, dynamic>>> getEmployeesByCompanyId(
    String companyId,
  ) async {
    try {
      final results = await _supabase
          .from('employees')
          .select()
          .eq('company_id', companyId);

      return _storageAssetService.resolveEmployeeRecords(
        results.map((json) => Map<String, dynamic>.from(json as Map)),
      );
    } catch (e) {
      debugPrint('Error getting employees by company ID: $e');
      return [];
    }
  }

  Future<Employee> _employeeFromRecord(Map<String, dynamic> record) async {
    final resolvedRecord = await _storageAssetService.resolveEmployeeRecord(
      record,
    );
    return Employee.fromJson(resolvedRecord);
  }
}

final employeeServiceProvider = Provider<EmployeeService>(
  (ref) => EmployeeService(),
);
