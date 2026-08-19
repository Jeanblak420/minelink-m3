/// One delivered load's quality picture (backed by `list_load_quality`):
/// the structured certificate the mine attached (Cr2O3 % / moisture % /
/// sizing + the lab PDF), the route's contract spec it is judged against, and
/// the server-computed penalty outputs — [payableTons] (excess moisture over
/// the contract max deducted pro-rata from the delivered tonnage) and
/// [gradeFactor] (pro-rata price factor for grade below spec, capped at 1).
class LoadQualityRow {
  final String tripId;
  final String? reference;
  final String? truckReg;
  final String? commodity;
  final String? sourceName;
  final String? customerName;
  final double? netTons;
  final double? deliveredTons;

  // Certificate (null until the mine attaches one).
  final double? cr2o3Pct;
  final double? moisturePct;
  final String? sizing;
  final String? certNotes;
  final String? certPath;
  final String? certFileName;
  final DateTime? issuedAt;

  // Contract spec on the route.
  final double? specCr2o3Pct;
  final double? specMoistureMaxPct;
  final String? specSizing;

  // Penalty-calc outputs.
  final double? payableTons;
  final double? gradeFactor;

  final String? tripStatus;
  final String? routeId;
  final DateTime updatedAt;

  const LoadQualityRow({
    required this.tripId,
    required this.updatedAt,
    this.reference,
    this.truckReg,
    this.commodity,
    this.sourceName,
    this.customerName,
    this.netTons,
    this.deliveredTons,
    this.cr2o3Pct,
    this.moisturePct,
    this.sizing,
    this.certNotes,
    this.certPath,
    this.certFileName,
    this.issuedAt,
    this.specCr2o3Pct,
    this.specMoistureMaxPct,
    this.specSizing,
    this.payableTons,
    this.gradeFactor,
    this.tripStatus,
    this.routeId,
  });

  /// A certificate exists once any structured value or file was attached.
  bool get hasCert =>
      cr2o3Pct != null ||
      moisturePct != null ||
      sizing != null ||
      certPath != null;

  /// Moisture over the contract max — the penalised excess (null when in spec
  /// or not yet measured).
  double? get excessMoisturePct {
    if (moisturePct == null || specMoistureMaxPct == null) return null;
    final excess = moisturePct! - specMoistureMaxPct!;
    return excess > 0 ? excess : null;
  }

  /// Grade below the contract target (null when on/above spec or unmeasured).
  bool get isBelowGradeSpec =>
      gradeFactor != null && gradeFactor! < 0.9999;

  static double? _d(dynamic v) => (v as num?)?.toDouble();
  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  factory LoadQualityRow.fromJson(Map<String, dynamic> j) => LoadQualityRow(
        tripId: j['trip_id'] as String,
        reference: _s(j['reference']),
        truckReg: _s(j['truck_reg']),
        commodity: _s(j['commodity']),
        sourceName: _s(j['source_name']),
        customerName: _s(j['customer_name']),
        netTons: _d(j['net_tons']),
        deliveredTons: _d(j['delivered_tons']),
        cr2o3Pct: _d(j['cr2o3_pct']),
        moisturePct: _d(j['moisture_pct']),
        sizing: _s(j['sizing']),
        certNotes: _s(j['cert_notes']),
        certPath: _s(j['cert_path']),
        certFileName: _s(j['cert_file_name']),
        issuedAt: _dt(j['issued_at']),
        specCr2o3Pct: _d(j['spec_cr2o3_pct']),
        specMoistureMaxPct: _d(j['spec_moisture_max_pct']),
        specSizing: _s(j['spec_sizing']),
        payableTons: _d(j['payable_tons']),
        gradeFactor: _d(j['grade_factor']),
        tripStatus: _s(j['trip_status']),
        routeId: _s(j['route_id']),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

/// A route's contract quality spec (the mine's yardstick per Route ID).
class RouteQualitySpec {
  final String routeId;
  final String? routeNumber;
  final String? commodity;
  final String? offloadingPoint;
  final double? specCr2o3Pct;
  final double? specMoistureMaxPct;
  final String? specSizing;

  /// Every load on this route needs a seal number AND a seal photo before the
  /// Load Controller can record it — enforced in `record_truck_load`, not only
  /// in the UI. Editable here because the seals are physically applied at the
  /// mine (RPC `set_route_seal_requirement`).
  final bool sealRequired;

  const RouteQualitySpec({
    required this.routeId,
    this.routeNumber,
    this.commodity,
    this.offloadingPoint,
    this.specCr2o3Pct,
    this.specMoistureMaxPct,
    this.specSizing,
    this.sealRequired = false,
  });

  bool get hasSpec =>
      specCr2o3Pct != null || specMoistureMaxPct != null || specSizing != null;

  factory RouteQualitySpec.fromJson(Map<String, dynamic> j) => RouteQualitySpec(
        routeId: j['id'] as String,
        routeNumber: LoadQualityRow._s(j['route_number']),
        commodity: LoadQualityRow._s(j['commodity']),
        offloadingPoint: LoadQualityRow._s(j['offloading_point']),
        specCr2o3Pct: LoadQualityRow._d(j['spec_cr2o3_pct']),
        specMoistureMaxPct: LoadQualityRow._d(j['spec_moisture_max_pct']),
        specSizing: LoadQualityRow._s(j['spec_sizing']),
        sealRequired: (j['seal_required'] as bool?) ?? false,
      );
}
