import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart';
import 'package:flutter_application_1/features/portal/utils/mine_supplier_overview_metrics.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// One product a buyer is purchasing (grouped by commodity), aggregated from the
/// buyer's transactions and their trips (§7.2). Tonnage is the delivered/loaded
/// amount carried on the trips, windowed by trip update time.
class BuyerProduct {
  final String name;
  final List<OperationTransaction> transactions;
  final List<TripRecord> trips;

  const BuyerProduct({
    required this.name,
    required this.transactions,
    required this.trips,
  });

  int get loads => trips.where((t) => t.netTons != null).length;
  List<TripRecord> get activeTrips =>
      trips.where((t) => TripStatus.parse(t.status).isActive).toList();

  /// Distinct source mines (supplier company ids) feeding this product.
  Set<String> get supplierIds =>
      transactions.map((t) => t.supplierCompanyId).whereType<String>().toSet();

  /// Tons loaded across rolling windows (D/W/M/Y/T) from this product's trips.
  TonsOutWindows tonsWindows(DateTime now) {
    final dayAgo = now.subtract(const Duration(days: 1));
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthAgo = now.subtract(const Duration(days: 30));
    final yearAgo = now.subtract(const Duration(days: 365));
    double d = 0, w = 0, m = 0, y = 0, total = 0;
    for (final t in trips) {
      final q = t.netTons;
      if (q == null) continue;
      // The pit clock — this read the raw UTC instant, so a late-evening
      // load counted against the wrong day of the product window.
      final at = MlTime.sast(t.updatedAt);
      total += q;
      if (at.isAfter(yearAgo)) y += q;
      if (at.isAfter(monthAgo)) m += q;
      if (at.isAfter(weekAgo)) w += q;
      if (at.isAfter(dayAgo)) d += q;
    }
    return TonsOutWindows(daily: d, weekly: w, monthly: m, yearly: y, total: total);
  }
}

/// Groups a buyer's transactions into products by commodity (§7.1/7.2).
List<BuyerProduct> buildBuyerProducts(
  LogisticsSnapshot snap,
  String buyerCompanyId,
) {
  final mine = snap.waybills
      .where((w) => w.buyerCompanyId == buyerCompanyId)
      .toList();
  final byName = <String, List<OperationTransaction>>{};
  for (final w in mine) {
    final raw = (w.metadata['commodity'] as String?)?.trim();
    final key = (raw == null || raw.isEmpty) ? 'Unspecified product' : raw;
    byName.putIfAbsent(key, () => []).add(w);
  }
  final products = <BuyerProduct>[];
  for (final e in byName.entries) {
    final txnIds = e.value.map((t) => t.id).toSet();
    products.add(BuyerProduct(
      name: e.key,
      transactions: e.value,
      trips: snap.trips.where((t) => txnIds.contains(t.transactionId)).toList(),
    ));
  }
  products.sort((a, b) => a.name.compareTo(b.name));
  return products;
}
