import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/services/storage_asset_service.dart';
import 'package:flutter_application_1/features/company/models/company_directory_entry.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/utils/error_handler.dart';
import 'package:flutter_application_1/core/services/cache_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

class CompanyService {
  final _supabase = SupabaseConfig.client;
  final _storageAssetService = StorageAssetService();

  Future<Company> getCompanyByUserId(String userId) async {
    try {
      debugPrint('CompanyService: Getting company data for user ID: $userId');

      // Try to get from cache first with specific user ID
      final cachedData = await CacheService.getCachedCompanyData(
        userId: userId,
      );
      if (cachedData != null && cachedData['user_id'] == userId) {
        debugPrint(
          'CompanyService: Found cached company data for user ID: $userId',
        );
        return _companyFromRecord(cachedData);
      }

      debugPrint(
        'CompanyService: No valid cache found, fetching from Supabase',
      );
      // If not in cache, fetch from Supabase
      final results = await _supabase
          .from('companies')
          .select()
          .eq('user_id', userId);

      if (results.isEmpty) {
        debugPrint('CompanyService: No company found for user ID: $userId');
        throw Exception('Company not found');
      }

      final data = results.first;
      debugPrint(
        'CompanyService: Found company data from Supabase for user ID: $userId',
      );

      // Cache the result with user-specific key
      await CacheService.cacheCompanyData(data);

      // Also set this as the current user ID
      await CacheService.setCurrentUserId(userId);

      return _companyFromRecord(data);
    } catch (e) {
      debugPrint('CompanyService: Error getting company data: $e');
      throw _handleError(e);
    }
  }

  Future<Company> getCompanyById(String companyId) async {
    try {
      final results = await _supabase
          .from('companies')
          .select()
          .eq('id', companyId);

      if (results.isEmpty) {
        throw Exception('Company not found');
      }

      return _companyFromRecord(results.first);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Every company on the platform as a **picker entry** — name, org type and
  /// logo, and nothing else.
  ///
  /// P3-43: this replaced `from('companies').select()`, which returned every
  /// row and every column — seat limits, token expiry, WhatsApp number, VAT and
  /// registration numbers, physical address, CEO names — to any authenticated
  /// user, including one who had not yet been approved by any employer. The
  /// `companies` SELECT policy is now scoped to own-company + counterparties +
  /// platform admin, so a table read here would return almost nothing anyway;
  /// but the reason to route through the RPC is that the picker legitimately
  /// needs a *wider* row set than the policy allows and a far *narrower* column
  /// set than the table has. `list_company_directory()` is SECURITY DEFINER and
  /// grants exactly that trade.
  Future<List<CompanyDirectoryEntry>> listCompanyDirectory() async {
    try {
      final data = await _supabase.rpc('list_company_directory');
      return (data as List)
          .map((json) => CompanyDirectoryEntry.fromJson(
              Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<List<Employee>> getCompanyEmployees(String companyId) async {
    try {
      // Try to get from cache first
      final cachedData = await CacheService.getCachedCompanyEmployees(
        companyId,
      );
      if (cachedData != null) {
        return _employeesFromRecords(cachedData);
      }

      // If not in cache, fetch from Supabase
      final data = await _supabase
          .from('employees')
          .select()
          .eq('company_id', companyId)
          .order('first_name', ascending: true)
          .order('last_name', ascending: true);

      // Cache the result
      await CacheService.cacheCompanyEmployees(companyId, data);

      return _employeesFromRecords(
        data.map((json) => Map<String, dynamic>.from(json as Map)).toList(),
      );
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

  Future<void> assignRoleToEmployee(String employeeId, UserRole role) async {
    try {
      await _supabase.rpc(
        'assign_employee_role',
        params: {'target_employee_id': employeeId, 'target_role': role.name},
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> declineEmployeeRequest(String employeeId) async {
    try {
      await _supabase.rpc(
        'decline_employee_request',
        params: {'target_employee_id': employeeId},
      );
    } catch (e) {
      throw _handleError(e);
    }
  }

  Future<void> updateCompanyProfile(
    String companyId,
    Map<String, dynamic> data,
  ) async {
    try {
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
        'Updating company profile: $companyId with data: $sanitizedData',
      );

      await _supabase.rpc(
        'update_my_company_profile',
        params: {
          'company_name_input': sanitizedData['company_name'],
          'whatsapp_number_input': sanitizedData['whatsapp_number'],
          'logo_url_input': sanitizedData['logo_url'],
          'ceo_first_name_input': sanitizedData['ceo_first_name'],
          'ceo_last_name_input': sanitizedData['ceo_last_name'],
          'support_contact_email_input':
              sanitizedData['support_contact_email'],
          'registration_number_input': sanitizedData['registration_number'],
          'vat_number_input': sanitizedData['vat_number'],
          'physical_address_input': sanitizedData['physical_address'],
        },
      );

      await CacheService.clearCompanyCache();
    } catch (e) {
      debugPrint('Error updating company profile: $e');
      throw _handleError(e);
    }
  }

  Future<String> uploadCompanyLogo(
    String companyId,
    Uint8List fileBytes,
    String fileName,
  ) async {
    try {
      // Validate inputs
      if (fileBytes.isEmpty) {
        throw Exception('File bytes cannot be empty');
      }

      if (fileName.isEmpty) {
        throw Exception('File name cannot be empty');
      }

      // Extract file extension, defaulting to png for generated/web uploads.
      final fileExt = fileName.contains('.')
          ? fileName.split('.').last.toLowerCase()
          : 'png';
      final contentType = switch (fileExt) {
        'png' => 'image/png',
        'jpg' || 'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'svg' || 'svgz' => 'image/svg+xml',
        _ => 'image/png',
      };
      debugPrint('File size: ${fileBytes.length} bytes');

      try {
        final response = await _supabase.functions.invoke(
          'company-user-admin',
          body: {
            'action': 'upload_company_logo',
            'company_id': companyId,
            'file_name': fileName,
            'file_extension': fileExt,
            'file_bytes_base64': base64Encode(fileBytes),
          },
        );

        final data = response.data;
        if (response.status < 200 || response.status >= 300) {
          if (data is Map && data['error'] != null) {
            throw Exception(data['error'].toString());
          }
          throw Exception('Failed to upload company logo');
        }

        if (data is! Map) {
          throw Exception('Company logo upload returned an invalid response');
        }

        final logoPath = data['logo_path']?.toString();
        final logoUrl = data['logo_url']?.toString();
        if (logoPath == null || logoPath.isEmpty) {
          throw Exception('Company logo upload did not return a storage path');
        }

        return logoUrl ??
            await _storageAssetService.resolveCompanyAssetUrl(logoPath) ??
            logoPath;
      } catch (functionError) {
        debugPrint(
          'Company logo function upload unavailable, falling back to inline logo storage: $functionError',
        );
      }

      final dataUrl = 'data:$contentType;base64,${base64Encode(fileBytes)}';
      await updateCompanyProfile(companyId, {'logo_url': dataUrl});
      return dataUrl;
    } catch (e) {
      debugPrint('Error in uploadCompanyLogo: $e');
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    final errorMessage = ErrorHandler.getErrorMessage(error);
    return Exception(errorMessage);
  }

  Future<Company> _companyFromRecord(Map<String, dynamic> record) async {
    final resolvedRecord = await _storageAssetService.resolveCompanyRecord(
      record,
    );
    return Company.fromJson(resolvedRecord);
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
}

final companyServiceProvider = Provider<CompanyService>(
  (ref) => CompanyService(),
);

/// Every company the caller may see, for pickers.
///
/// Backed by `list_company_directory()` — the SECURITY DEFINER RPC added at
/// S2-1 so the onboarding picker stopped reading `companies` directly. It
/// returns picker columns only (id, name, org type, logo), never seat counts
/// or token expiry.
final companyDirectoryProvider =
    FutureProvider<List<CompanyDirectoryEntry>>((ref) async {
  return ref.watch(companyServiceProvider).listCompanyDirectory();
});
