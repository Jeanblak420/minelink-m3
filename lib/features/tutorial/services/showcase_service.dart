import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/tutorial/models/showcase_item.dart';

final _log = LoggerFactory.getLogger('ShowcaseService');

/// Data access for the live `showcase_data` table (seeded demo content shown
/// during the guided tour). Read-only from the app — rows are admin-seeded;
/// RLS grants authenticated users select access.
class ShowcaseService {
  final SupabaseClient _supabase = SupabaseConfig.client;

  /// All showcase rows, typed. Returns an empty list on failure (the tour
  /// must never break normal app use because demo data can't be fetched).
  Future<List<ShowcaseItem>> getAll() async {
    try {
      final response = await _supabase
          .from('showcase_data')
          .select()
          .order('category')
          .order('created_at');
      return response.map(ShowcaseItem.fromJson).toList();
    } catch (e) {
      _log.w('Failed to fetch showcase data: $e');
      return const [];
    }
  }

  /// Showcase rows for a single [category] (e.g. `mine`, `truck`, `trip`).
  Future<List<ShowcaseItem>> getByCategory(String category) async {
    try {
      final response = await _supabase
          .from('showcase_data')
          .select()
          .eq('category', category)
          .order('created_at');
      return response.map(ShowcaseItem.fromJson).toList();
    } catch (e) {
      _log.w('Failed to fetch showcase data for "$category": $e');
      return const [];
    }
  }

  /// All showcase rows grouped by category — the shape the demo-data
  /// indicator and tour consume.
  Future<Map<String, List<ShowcaseItem>>> getGroupedByCategory() async {
    final items = await getAll();
    final grouped = <String, List<ShowcaseItem>>{};
    for (final item in items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    return grouped;
  }
}
