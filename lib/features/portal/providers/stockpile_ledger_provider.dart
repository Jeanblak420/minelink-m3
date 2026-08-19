import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_transaction.dart';

/// Shared, immutable view of buyer-allocated stockpiles and their permanent
/// audit trail, loaded from the DB (see LifecycleService.loadLedger). The
/// previous in-memory ledger/notifier was removed once the Load Controller and
/// supervisor screens moved to the persistent stockpile RPCs.
///
/// Each stockpile is reserved exclusively for one buyer. The [stockpiles] list
/// always reflects the CURRENT remaining balance; [transactions] is an
/// append-only audit trail (newest first) of every allocation, addition and
/// confirmed-load deduction.
class StockpileLedgerState {
  final List<StockpileEntry> stockpiles; // tons == remaining balance
  final List<StockpileTransaction> transactions; // newest first

  const StockpileLedgerState({
    this.stockpiles = const [],
    this.transactions = const [],
  });

  StockpileLedgerState copyWith({
    List<StockpileEntry>? stockpiles,
    List<StockpileTransaction>? transactions,
  }) {
    return StockpileLedgerState(
      stockpiles: stockpiles ?? this.stockpiles,
      transactions: transactions ?? this.transactions,
    );
  }

  List<StockpileTransaction> forStockpile(String id) =>
      transactions.where((t) => t.stockpileId == id).toList();

  List<StockpileEntry> forBuyer(String buyer) =>
      stockpiles.where((s) => s.buyer == buyer).toList();

  double buyerBalance(String buyer) =>
      forBuyer(buyer).fold<double>(0, (a, s) => a + s.tons);

  double get totalBalance =>
      stockpiles.fold<double>(0, (a, s) => a + s.tons);
}
