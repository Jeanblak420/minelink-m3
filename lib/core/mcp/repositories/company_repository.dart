import 'package:flutter_application_1/core/mcp/models/company_model.dart';
import 'package:flutter_application_1/core/mcp/repositories/supabase_repository.dart';
import 'package:flutter_application_1/core/services/cache_service.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

/// Repository for interacting with the companies table
class CompanyRepository extends SupabaseRepository<CompanyMCP> {
  final _logger = LoggerFactory.getLogger('CompanyRepository');

  @override
  String get tableName => 'companies';

  @override
  CompanyMCP fromJson(Map<String, dynamic> json) => CompanyMCP.fromJson(json);

  /// Gets a company by user ID
  Future<CompanyMCP> getByUserId(String userId) async {
    try {
      _logger.d('Getting company data for user ID: $userId');

      // Try to get from cache first with specific user ID
      final cachedData = await CacheService.getCachedCompanyData(
        userId: userId,
      );
      if (cachedData != null && cachedData['user_id'] == userId) {
        _logger.d('Found cached company data for user ID: $userId');
        return CompanyMCP.fromJson(cachedData);
      }

      _logger.d('No valid cache found, fetching from Supabase');
      // If not in cache, fetch from Supabase
      final response = await supabase
          .from(tableName)
          .select()
          .eq('user_id', userId)
          .single();

      // Cache the result with user-specific key
      await CacheService.cacheCompanyData(response);

      // Also set this as the current user ID
      await CacheService.setCurrentUserId(userId);

      return fromJson(response);
    } catch (e) {
      _logger.e('Error getting company data for user ID: $userId', e);
      rethrow;
    }
  }

  /// Gets all companies with a specific organization type
  Future<List<CompanyMCP>> getByOrgType(
    String orgType, {
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    try {
      final query = supabase.from(tableName).select().eq('org_type', orgType);
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

      return results.map<CompanyMCP>((json) => fromJson(json)).toList();
    } catch (e) {
      _logger.e('Error getting companies by org type: $orgType', e);
      rethrow;
    }
  }

  /// Updates a company's logo URL
  Future<CompanyMCP> updateLogo(String companyId, String logoUrl) async {
    try {
      final response = await supabase
          .from(tableName)
          .update({
            'logo_url': logoUrl,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', companyId)
          .select()
          .single();

      // Clear the cache to ensure fresh data on next fetch
      await CacheService.clearCompanyCache();

      return fromJson(response);
    } catch (e) {
      _logger.e('Error updating company logo: $e');
      rethrow;
    }
  }

  /// Gets a stream of companies for real-time updates
  Stream<List<CompanyMCP>> streamByOrgType(String orgType) {
    try {
      final stream = supabase.from(tableName).stream(primaryKey: ['id']);

      return stream.map((event) {
        // Filter by org type
        final filtered = event
            .where((item) => item['org_type'] == orgType)
            .toList();
        return filtered.map<CompanyMCP>((json) => fromJson(json)).toList();
      });
    } catch (e) {
      _logger.e('Error creating stream for companies by org type: $orgType', e);
      rethrow;
    }
  }
}
