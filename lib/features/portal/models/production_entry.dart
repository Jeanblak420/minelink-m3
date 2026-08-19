/// One tons-mined input row (backed by `production_entries`): the ROM
/// production the mine recorded for a day, optionally tied to the production
/// pile the material was placed on.
class ProductionEntry {
  final String id;
  final String companyId;
  final DateTime entryDate;
  final double tons;
  final String? commodity;
  final String? pitSection;
  final String? stockpileId;
  final String? notes;
  final DateTime createdAt;

  const ProductionEntry({
    required this.id,
    required this.companyId,
    required this.entryDate,
    required this.tons,
    required this.createdAt,
    this.commodity,
    this.pitSection,
    this.stockpileId,
    this.notes,
  });

  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory ProductionEntry.fromJson(Map<String, dynamic> j) => ProductionEntry(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        entryDate: DateTime.parse(j['entry_date'] as String),
        tons: ((j['tons'] as num?) ?? 0).toDouble(),
        commodity: _s(j['commodity']),
        pitSection: _s(j['pit_section']),
        stockpileId: _s(j['stockpile_id']),
        notes: _s(j['notes']),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}

/// One day of the production-vs-dispatch series (backed by
/// `mine_production_dispatch_report`): tons mined vs weighbridge net tons
/// dispatched out of the mine — the raw numbers behind yield % and
/// pit-to-port loss.
class ProductionDispatchDay {
  final DateTime day;
  final double minedTons;
  final double dispatchedTons;

  const ProductionDispatchDay({
    required this.day,
    required this.minedTons,
    required this.dispatchedTons,
  });

  factory ProductionDispatchDay.fromJson(Map<String, dynamic> j) =>
      ProductionDispatchDay(
        day: DateTime.parse(j['day'] as String),
        minedTons: ((j['mined_tons'] as num?) ?? 0).toDouble(),
        dispatchedTons: ((j['dispatched_tons'] as num?) ?? 0).toDouble(),
      );
}
