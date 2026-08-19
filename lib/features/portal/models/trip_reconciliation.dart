/// One trip's weight reconciliation (CLAUDE.md §4). The mine Net Weight loaded
/// at source ([mineNetTons]) is authoritative; the [deliveredTons] re-weighed at
/// offload is stored separately, and [variance] = mine net − delivered (the
/// lost/stolen/swapped mass en route). Backed by `list_trip_reconciliations`.
class TripReconciliation {
  final String tripId;
  final String? reference;
  final String? truckReg;
  final String? commodity;
  final String? sourceName; // mine / supplier
  final String? customerName; // buyer
  final String? transporterName;
  final double? mineNetTons;
  final double? deliveredTons;
  final double? variance;
  final String? tripStatus;

  /// Object path of the POD photo (private `pod_photos` bucket), when uploaded.
  final String? podPhotoPath;
  final DateTime updatedAt;

  const TripReconciliation({
    required this.tripId,
    required this.updatedAt,
    this.reference,
    this.truckReg,
    this.commodity,
    this.sourceName,
    this.customerName,
    this.transporterName,
    this.mineNetTons,
    this.deliveredTons,
    this.variance,
    this.tripStatus,
    this.podPhotoPath,
  });

  /// Delivered leg captured (POD uploaded) — variance is meaningful.
  bool get isDelivered => deliveredTons != null;

  static double? _d(dynamic v) => (v as num?)?.toDouble();
  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory TripReconciliation.fromJson(Map<String, dynamic> j) =>
      TripReconciliation(
        tripId: j['trip_id'] as String,
        reference: _s(j['reference']),
        truckReg: _s(j['truck_reg']),
        commodity: _s(j['commodity']),
        sourceName: _s(j['source_name']),
        customerName: _s(j['customer_name']),
        transporterName: _s(j['transporter_name']),
        mineNetTons: _d(j['mine_net_tons']),
        deliveredTons: _d(j['delivered_tons']),
        variance: _d(j['variance']),
        tripStatus: _s(j['trip_status']),
        podPhotoPath: _s(j['pod_photo_path']),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}
