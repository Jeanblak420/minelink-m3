import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/mcp/models/supabase_model.dart';
import 'package:flutter_application_1/core/utils/logger.dart';

/// Base repository for interacting with Supabase
///
/// This class provides common CRUD operations for Supabase tables.
/// It is designed to be extended by specific repositories for each model.
abstract class SupabaseRepository<T extends SupabaseModel> {
  final supabase = SupabaseConfig.client;
  final _logger = LoggerFactory.getLogger('SupabaseRepository');

  /// The table name in Supabase
  String get tableName;

  /// Creates a model from a JSON map
  T fromJson(Map<String, dynamic> json);

  /// Fetches all records from the table
  Future<List<T>> getAll({
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    try {
      final query = supabase.from(tableName).select();

      // Execute the query
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

      return results.map<T>((json) => fromJson(json)).toList();
    } catch (e) {
      _logger.e('Error fetching all records from $tableName', e);
      rethrow;
    }
  }

  /// Fetches a record by ID
  Future<T> getById(String id) async {
    try {
      final response = await supabase
          .from(tableName)
          .select()
          .eq('id', id)
          .single();
      return fromJson(response);
    } catch (e) {
      _logger.e('Error fetching record with ID $id from $tableName', e);
      rethrow;
    }
  }

  /// Inserts a new record
  Future<T> insert(T model) async {
    try {
      final response = await supabase
          .from(tableName)
          .insert(model.toJson())
          .select()
          .single();
      return fromJson(response);
    } catch (e) {
      _logger.e('Error inserting record into $tableName', e);
      rethrow;
    }
  }

  /// Updates an existing record
  Future<T> update(T model) async {
    try {
      // Assuming the model has an 'id' field
      final id = (model as dynamic).id;
      final response = await supabase
          .from(tableName)
          .update(model.toJson())
          .eq('id', id)
          .select()
          .single();
      return fromJson(response);
    } catch (e) {
      _logger.e('Error updating record in $tableName', e);
      rethrow;
    }
  }

  /// Deletes a record by ID
  Future<void> delete(String id) async {
    try {
      await supabase.from(tableName).delete().eq('id', id);
    } catch (e) {
      _logger.e('Error deleting record with ID $id from $tableName', e);
      rethrow;
    }
  }

  /// Creates a stream subscription for real-time updates
  Stream<List<T>> stream({
    List<String>? primaryKey,
    String? orderBy,
    bool ascending = true,
    int? limit,
  }) {
    try {
      final stream = supabase
          .from(tableName)
          .stream(primaryKey: primaryKey ?? ['id']);

      return stream.map((event) {
        List<Map<String, dynamic>> results = List<Map<String, dynamic>>.from(
          event,
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

        // Apply limit if needed
        if (limit != null && results.length > limit) {
          results = results.sublist(0, limit);
        }

        return results.map<T>((json) => fromJson(json)).toList();
      });
    } catch (e) {
      _logger.e('Error creating stream for $tableName', e);
      rethrow;
    }
  }
}
