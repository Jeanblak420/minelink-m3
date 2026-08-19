/// The kind of movement recorded against a stockpile in the audit trail.
enum StockpileTxnType {
  allocation, // initial tonnage allocated to the buyer when created
  addition, // supervisor added more tonnage later
  deduction, // confirmed truck load deducted from the buyer's stockpile
}

extension StockpileTxnTypeX on StockpileTxnType {
  String get label {
    switch (this) {
      case StockpileTxnType.allocation:
        return 'Allocated';
      case StockpileTxnType.addition:
        return 'Added';
      case StockpileTxnType.deduction:
        return 'Loaded out';
    }
  }
}

/// A single immutable, append-only audit entry for a stockpile movement.
///
/// Together these form the permanent audit trail: initial allocation, any
/// additions, and every confirmed truck-load deduction — each capturing the
/// signed tonnage and the running balance after the movement.
class StockpileTransaction {
  final String stockpileId;
  final String stockpileName;
  final String buyer;
  final StockpileTxnType type;
  final double delta; // signed: + for allocation/addition, - for deduction
  final double balanceAfter; // remaining balance of the stockpile after this
  final String? truckReg; // set for deductions (which load caused it)
  final DateTime at;

  const StockpileTransaction({
    required this.stockpileId,
    required this.stockpileName,
    required this.buyer,
    required this.type,
    required this.delta,
    required this.balanceAfter,
    required this.at,
    this.truckReg,
  });

  double get magnitude => delta.abs();
}
