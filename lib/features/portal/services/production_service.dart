import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/portal/models/production_entry.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Mine production data access: tons-mined entries (`record_production` RPC —
/// optionally landing the tonnage on a production pile atomically), the
/// production-vs-dispatch daily series, and mine-owned ROM/production pile
/// creation (order piles stay system-only).
class ProductionService {
  final SupabaseClient _client = SupabaseConfig.client;

  Future<List<ProductionEntry>> listEntries(
    String companyId, {
    int limit = 60,
  }) async {
    final rows = await _client
        .from('production_entries')
        .select()
        .eq('company_id', companyId)
        .order('entry_date', ascending: false)
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List)
        .map((e) => ProductionEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Record tons mined. When [stockpileId] names one of the mine's production
  /// piles, the RPC also adds the tonnage onto that pile atomically.
  Future<void> recordProduction({
    required String companyId,
    required double tons,
    DateTime? entryDate,
    String? commodity,
    String? pitSection,
    String? stockpileId,
    String? notes,
  }) async {
    await _client.rpc('record_production', params: {
      'p_company_id': companyId,
      'p_tons': tons,
      // The day at the mine. `toIso8601String().substring(0, 10)` on a
      // device-local value silently used whatever zone the object was in, so a
      // shift recorded just after midnight was filed under the day before.
      'p_entry_date': MlTime.dateParam(entryDate ?? MlTime.now()),
      'p_commodity': commodity,
      'p_pit_section': pitSection,
      'p_stockpile_id': stockpileId,
      'p_notes': notes,
    });
  }

  Future<List<ProductionDispatchDay>> report({
    required String companyId,
    required DateTime from,
    required DateTime to,
  }) async {
    final rows = await _client.rpc('mine_production_dispatch_report', params: {
      'p_company_id': companyId,
      // Pit days, both edges — the report's buckets are pit days too.
      'p_from': MlTime.dateParam(from),
      'p_to': MlTime.dateParam(to),
    });
    return (rows as List)
        .map((e) =>
            ProductionDispatchDay.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Create a mine-owned ROM/production pile (RLS: stockpile writers only,
  /// `kind = 'production'`; order piles remain system-created).
  Future<void> createProductionPile({
    required String companyId,
    required String name,
    double openingTons = 0,
    String? mineral,
    String? grade,
    double? cr2o3Pct,
    double? moisturePct,
    String? sizing,
  }) async {
    final inserted = await _client
        .from('stockpiles')
        .insert({
          'supplier_company_id': companyId,
          'name': name,
          'kind': 'production',
          'mineral': mineral,
          'grade': grade,
          'cr2o3_pct': cr2o3Pct,
          'moisture_pct': moisturePct,
          'sizing': sizing,
          'balance_tons': openingTons,
        })
        .select()
        .single();
    if (openingTons > 0) {
      await _client.from('stockpile_transactions').insert({
        'stockpile_id': inserted['id'],
        'type': 'allocation',
        'delta_tons': openingTons,
        'balance_after': openingTons,
      });
    }
  }
}

final productionServiceProvider =
    Provider<ProductionService>((ref) => ProductionService());

final productionEntriesProvider =
    FutureProvider.family.autoDispose<List<ProductionEntry>, String>(
  (ref, companyId) =>
      ref.read(productionServiceProvider).listEntries(companyId),
);

/// (companyId, days-back) → the daily mined/dispatched series.
final productionReportProvider = FutureProvider.family
    .autoDispose<List<ProductionDispatchDay>, ({String companyId, int days})>(
  (ref, key) {
    // The window is a run of pit days, and the report now buckets dispatch on
    // the same calendar (`ml_day`, migration 20260817240000) — before that the
    // mined and dispatched sides of the yield table were joined across two.
    final now = MlTime.now();
    return ref.read(productionServiceProvider).report(
          companyId: key.companyId,
          from: now.subtract(Duration(days: key.days)),
          to: now,
        );
  },
);
