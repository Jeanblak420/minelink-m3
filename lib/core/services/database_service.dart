import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/error_handler.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

/// A centralized service for common Supabase reads, writes, and helper calls.
///
/// Active realtime flows now use Postgres Changes in feature providers.
class DatabaseService {
  final _supabase = SupabaseConfig.client;
  final _logger = LoggerFactory.getLogger('DatabaseService');

  // CRUD Operations

  /// Fetches a single record from the specified table
  Future<Map<String, dynamic>?> getRecord(
    String table,
    String field,
    dynamic value,
  ) async {
    try {
      final response = await _supabase
          .from(table)
          .select()
          .eq(field, value)
          .maybeSingle();

      return response;
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Fetches multiple records from the specified table
  Future<List<Map<String, dynamic>>> getRecords(
    String table, {
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
    Map<String, dynamic>? filters,
  }) async {
    try {
      dynamic query = _supabase.from(table).select();

      if (filters != null) {
        query = _applyFilters(query, filters);
      }

      if (orderBy != null) {
        query = query.order(orderBy, ascending: ascending);
      }

      if (offset != null && limit != null) {
        query = query.range(offset, offset + limit - 1);
      } else if (offset != null) {
        query = query.range(offset, offset + 999);
      } else if (limit != null) {
        query = query.limit(limit);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response as List);
    } catch (e) {
      throw _handleError(e);
    }
  }

  dynamic _applyFilters(dynamic query, Map<String, dynamic> filters) {
    dynamic nextQuery = query;

    filters.forEach((field, value) {
      if (value == null) {
        nextQuery = nextQuery.isFilter(field, null);
      } else if (value is Iterable && value is! String) {
        nextQuery = nextQuery.inFilter(field, value.toList());
      } else {
        nextQuery = nextQuery.eq(field, value);
      }
    });

    return nextQuery;
  }

  /// Fetches records for callers that manage their own realtime subscriptions.
  Future<List<Map<String, dynamic>>> getRealtimeData(
    String table, {
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
    Map<String, dynamic>? filters,
  }) async {
    return await getRecords(
      table,
      orderBy: orderBy,
      ascending: ascending,
      limit: limit,
      offset: offset,
      filters: filters,
    );
  }

  // NOTE: broadcast-message cleanup moved server-side — the
  // cleanup-old-broadcast-messages pg_cron job (migration 20260803090000)
  // runs nightly in Postgres; clients no longer schedule maintenance.

  Future<Map<String, dynamic>> getRuntimePlatformStatus() async {
    try {
      final response = await _supabase.rpc('get_runtime_platform_status');
      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }

      throw Exception('Unexpected runtime platform status payload');
    } catch (e) {
      _logger.e('Error fetching runtime platform status', e);
      // Rethrown raw, unlike every other method here: this one is a bootstrap
      // preflight, and its only caller has to tell "the project is misconfigured"
      // apart from "this caller may not run the check" (42501). Flattening it to
      // a friendly Exception here destroys the code it needs to do that.
      // DatabaseMigrationService converts it before anything reaches the UI.
      rethrow;
    }
  }

  // Error Handling

  Exception _handleError(dynamic error) {
    return ErrorHandler.handleSupabaseError(error);
  }

  /// Exposes the Supabase client for direct access when needed
  /// This should be used sparingly, only when the provided methods are insufficient
  SupabaseClient getSupabaseClient() {
    return _supabase;
  }
}

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});
