import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/portal/models/mine_trip.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_doc.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/providers/stockpile_ledger_provider.dart'
    show StockpileLedgerState;
import 'package:flutter_application_1/features/portal/services/lifecycle_service.dart';

final lifecycleServiceProvider =
    Provider<LifecycleService>((ref) => LifecycleService());

/// Trips inbound to a mine (supplier party) for the Security check-in + Load
/// Controller field screens. Invalidate after a status change / load.
final mineInboundTripsProvider = FutureProvider.autoDispose
    .family<List<MineTrip>, String>((ref, supplierCompanyId) async {
  final svc = ref.watch(lifecycleServiceProvider);
  return svc.listInboundTrips(supplierCompanyId);
});

/// Persistent stockpiles for a supplier (mine), loaded from the DB. Invalidate
/// after createStockpile / addTons / a confirmed load to refresh balances.
final stockpilesProvider = FutureProvider.autoDispose
    .family<List<StockpileEntry>, String>((ref, supplierCompanyId) async {
  final svc = ref.watch(lifecycleServiceProvider);
  return svc.listStockpiles(supplierCompanyId);
});

/// Full DB-backed stockpile ledger (balances + audit trail) for a supplier.
final stockpileLedgerDbProvider = FutureProvider.autoDispose
    .family<StockpileLedgerState, String>((ref, supplierCompanyId) async {
  final svc = ref.watch(lifecycleServiceProvider);
  return svc.loadLedger(supplierCompanyId);
});

/// Documents (lab results / pictures) attached to a stockpile. Invalidate after
/// an upload to refresh the list.
final stockpileDocsProvider = FutureProvider.autoDispose
    .family<List<StockpileDoc>, String>((ref, stockpileId) async {
  final svc = ref.watch(lifecycleServiceProvider);
  return svc.listStockpileDocs(stockpileId);
});
