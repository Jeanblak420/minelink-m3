import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';

/// The live fill of the stockpile the mine is preparing for an order. Visible
/// to the buyer and the transporter (RLS lets both read the linked stockpile)
/// so they can see how much of the mineral has been added and how many full
/// loads are ready to collect — without guessing or sending a half-empty truck.
class OrderStockpileFill {
  final String stockpileId;
  final double balanceTons;
  final double? maxCapTons;
  final String? mineral;

  const OrderStockpileFill({
    required this.stockpileId,
    required this.balanceTons,
    this.maxCapTons,
    this.mineral,
  });

  /// Full trailer loads (30 t) ready to collect right now.
  int get loadsReady => (balanceTons / 30).floor();

  /// 0..1 fill fraction against the order cap (0 when there is no cap).
  double get fraction =>
      (maxCapTons == null || maxCapTons! <= 0)
          ? 0
          : (balanceTons / maxCapTons!).clamp(0.0, 1.0);

  bool get isComplete => maxCapTons != null && balanceTons >= maxCapTons!;
}

/// Fill of the stockpile linked to [requestId], or null if none exists yet.
final orderStockpileProvider =
    FutureProvider.family<OrderStockpileFill?, String>((ref, requestId) async {
  final rows = await SupabaseConfig.client
      .from('stockpiles')
      .select('id, balance_tons, max_cap_tons, mineral')
      .eq('request_id', requestId)
      .limit(1);
  if (rows.isEmpty) return null;
  final m = Map<String, dynamic>.from(rows.first);
  return OrderStockpileFill(
    stockpileId: m['id'] as String,
    balanceTons: ((m['balance_tons'] as num?) ?? 0).toDouble(),
    maxCapTons: (m['max_cap_tons'] as num?)?.toDouble(),
    mineral: m['mineral'] as String?,
  );
});
