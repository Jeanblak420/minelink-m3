/// One tracked request as seen by an involved party or the super-admin
/// (`list_request_tracking`). [isCompleted] is derived server-side: linked,
/// trips exist, every trip completed.
class RequestTrackingRow {
  final String requestId;
  final String requestType;
  final String status;
  final String? requesterName;
  final String? supplierName;
  final String? transporterNames;
  final String? commodity;
  final String? loadingPoint;
  final String? offloadingPoint;
  final int tripsTotal;
  final int tripsCompleted;
  final double tonsDelivered;
  final bool isCompleted;
  final DateTime updatedAt;

  const RequestTrackingRow({
    required this.requestId,
    required this.requestType,
    required this.status,
    required this.tripsTotal,
    required this.tripsCompleted,
    required this.tonsDelivered,
    required this.isCompleted,
    required this.updatedAt,
    this.requesterName,
    this.supplierName,
    this.transporterNames,
    this.commodity,
    this.loadingPoint,
    this.offloadingPoint,
  });

  String get routeLabel => requestType == 'transportation'
      ? '${loadingPoint ?? '—'} → ${offloadingPoint ?? '—'}'
      : (commodity ?? '—');

  String get typeLabel => switch (requestType) {
    'product' => 'Product',
    'buyer' => 'Buyers',
    _ => 'Transport',
  };

  /// Display status: the derived Completed overrides 'linked'.
  String get displayStatus => isCompleted ? 'Completed' : status;

  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory RequestTrackingRow.fromJson(Map<String, dynamic> j) =>
      RequestTrackingRow(
        requestId: j['request_id'] as String,
        requestType: (j['request_type'] as String?) ?? 'transportation',
        status: (j['status'] as String?) ?? 'requested',
        requesterName: _s(j['requester_name']),
        supplierName: _s(j['supplier_name']),
        transporterNames: _s(j['transporter_names']),
        commodity: _s(j['commodity']),
        loadingPoint: _s(j['loading_point']),
        offloadingPoint: _s(j['offloading_point']),
        tripsTotal: (j['trips_total'] as num?)?.toInt() ?? 0,
        tripsCompleted: (j['trips_completed'] as num?)?.toInt() ?? 0,
        tonsDelivered: (j['tons_delivered'] as num?)?.toDouble() ?? 0,
        isCompleted: (j['is_completed'] as bool?) ?? false,
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}
