import 'package:flutter_application_1/core/mcp/models/employee_model.dart';
import 'package:flutter_application_1/core/mcp/repositories/supabase_repository.dart';
import 'package:flutter_application_1/core/services/cache_service.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';

/// Repository for interacting with the employees table
class EmployeeRepository extends SupabaseRepository<EmployeeMCP> {
  final _logger = LoggerFactory.getLogger('EmployeeRepository');

  @override
  String get tableName => 'employees';

  @override
  EmployeeMCP fromJson(Map<String, dynamic> json) => EmployeeMCP.fromJson(json);

  /// Gets an employee by user ID
  Future<EmployeeMCP> getByUserId(String userId) async {
    try {
      _logger.d('Getting employee data for user ID: $userId');

      // Try to get from cache first
      final cachedData = await CacheService.getCachedEmployeeData(
        userId: userId,
      );
      if (cachedData != null && cachedData['user_id'] == userId) {
        _logger.d('Found cached employee data for user ID: $userId');
        return EmployeeMCP.fromJson(cachedData);
      }

      _logger.d('No valid cache found, fetching from Supabase');
      // If not in cache, fetch from Supabase
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', userId)
          .single();

      // Cache the result
      await CacheService.cacheEmployeeData(response);

      // Also set this as the current user ID
      await CacheService.setCurrentUserId(userId);

      return fromJson(response);
    } catch (e) {
      _logger.e('Error getting employee data for user ID: $userId', e);
      rethrow;
    }
  }

  /// Gets all employees for a company
  Future<List<EmployeeMCP>> getByCompanyId(
    String companyId, {
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    try {
      // Try to get from cache first
      final cachedData = await CacheService.getCachedCompanyEmployees(
        companyId,
      );
      if (cachedData != null) {
        _logger.d('Found cached employee data for company ID: $companyId');
        return cachedData.map((json) => EmployeeMCP.fromJson(json)).toList();
      }

      _logger.d('No valid cache found, fetching from Supabase');
      final query = supabase
          .from(tableName)
          .select()
          .eq('company_id', companyId)
          .order('first_name', ascending: true)
          .order('last_name', ascending: true);
      final response = await query;

      // Process the results
      List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(
        response,
      );

      // Apply ordering if needed
      if (orderBy != null) {
        results.sort((a, b) {
          final aValue = a[orderBy];
          final bValue = b[orderBy];

          if (aValue == null && bValue == null) return 0;
          if (aValue == null) return ascending ? -1 : 1;
          if (bValue == null) return ascending ? 1 : -1;

          int comparison;
          if (aValue is String && bValue is String) {
            comparison = aValue.compareTo(bValue);
          } else if (aValue is num && bValue is num) {
            comparison = aValue.compareTo(bValue);
          } else if (aValue is DateTime && bValue is DateTime) {
            comparison = aValue.compareTo(bValue);
          } else if (aValue is bool && bValue is bool) {
            comparison = aValue == bValue ? 0 : (aValue ? 1 : -1);
          } else {
            comparison = aValue.toString().compareTo(bValue.toString());
          }

          return ascending ? comparison : -comparison;
        });
      }

      // Apply pagination if needed
      if (offset != null || limit != null) {
        final start = offset ?? 0;
        final end = limit != null ? start + limit : results.length;
        results = results.sublist(
          start,
          end > results.length ? results.length : end,
        );
      }

      // Cache the result
      await CacheService.cacheCompanyEmployees(companyId, results);

      return results.map<EmployeeMCP>((json) => fromJson(json)).toList();
    } catch (e) {
      _logger.e('Error getting employees for company ID: $companyId', e);
      rethrow;
    }
  }

  /// Assigns a role to an employee
  Future<EmployeeMCP> assignRole(String employeeId, UserRole role) async {
    try {
      final response = await supabase
          .from(tableName)
          .update({
            'role': role.name,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', employeeId)
          .select()
          .single();

      // Clear the cache to ensure fresh data on next fetch
      await CacheService.clearEmployeeCache();

      return fromJson(response);
    } catch (e) {
      _logger.e('Error assigning role to employee: $e');
      rethrow;
    }
  }

  /// Updates an employee's profile photo URL
  Future<EmployeeMCP> updateProfilePhoto(
    String employeeId,
    String photoUrl,
  ) async {
    try {
      final response = await supabase
          .from(tableName)
          .update({
            'profile_photo_url': photoUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', employeeId)
          .select()
          .single();

      // Clear the cache to ensure fresh data on next fetch
      await CacheService.clearEmployeeCache();

      return fromJson(response);
    } catch (e) {
      _logger.e('Error updating employee profile photo: $e');
      rethrow;
    }
  }

  /// Gets a stream of employees for a company for real-time updates
  Stream<List<EmployeeMCP>> streamByCompanyId(String companyId) {
    try {
      final stream = supabase.from(tableName).stream(primaryKey: ['id']);

      return stream.map((event) {
        // Filter by company ID
        final filtered = event
            .where((item) => item['company_id'] == companyId)
            .toList();
        return filtered.map<EmployeeMCP>((json) => fromJson(json)).toList();
      });
    } catch (e) {
      _logger.e(
        'Error creating stream for employees by company ID: $companyId',
        e,
      );
      rethrow;
    }
  }
}
