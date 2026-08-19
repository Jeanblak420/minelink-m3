/// A single stockpile bin shown on the Stockpile levels detail screen.
///
/// Each stockpile holds a tonnage and is typically allocated to a buyer.
/// Entries are created at runtime by the supervisor/mine-admin via the
/// stockpile ledger — the screen starts from a clean empty state.
class StockpileEntry {
  final String id; // stable id (DB uuid)
  final String name; // e.g. "Stockpile A"
  final String? buyer; // display label, e.g. "Buyer B" (null = unallocated)
  final String? buyerCompanyId; // resolved buyer company (drives recon cascade)
  final double tons; // current remaining balance
  final String? mineral;
  final String? grade;

  /// The order cap: the maximum tonnage that may be added to this stockpile,
  /// set from the buyer's ordered tonnage when the system created it. Null for
  /// legacy stockpiles with no linked order.
  final double? maxCapTons;

  /// The transportation request this stockpile was auto-created for (null for
  /// legacy, manually-created stockpiles).
  final String? requestId;

  /// 'order' = system-created capped order stockpile; 'production' = the
  /// mine's own ROM/production pile (mine-creatable).
  final String kind;

  const StockpileEntry({
    required this.name,
    required this.tons,
    this.id = '',
    this.buyer,
    this.buyerCompanyId,
    this.mineral,
    this.grade,
    this.maxCapTons,
    this.requestId,
    this.kind = 'order',
  });

  /// True for the mine's own ROM/production piles.
  bool get isProduction => kind == 'production';

  /// True when this stockpile is linked to an order (has a cap).
  bool get isOrderLinked => requestId != null || maxCapTons != null;

  /// Tonnage that can still be added before hitting the order cap. Null when
  /// there is no cap.
  double? get remainingToCap =>
      maxCapTons == null ? null : (maxCapTons! - tons).clamp(0, maxCapTons!);

  /// Full trailer loads (30 t) currently ready to collect.
  int get loadsReady => (tons / 30).floor();

  StockpileEntry copyWith({
    String? id,
    String? name,
    String? buyer,
    String? buyerCompanyId,
    double? tons,
    String? mineral,
    String? grade,
    double? maxCapTons,
    String? requestId,
    String? kind,
  }) {
    return StockpileEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      buyer: buyer ?? this.buyer,
      buyerCompanyId: buyerCompanyId ?? this.buyerCompanyId,
      tons: tons ?? this.tons,
      mineral: mineral ?? this.mineral,
      grade: grade ?? this.grade,
      maxCapTons: maxCapTons ?? this.maxCapTons,
      requestId: requestId ?? this.requestId,
      kind: kind ?? this.kind,
    );
  }
}
