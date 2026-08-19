class HaulRouteRecord {
  final String id;
  final String? supplierCompanyId;
  final String? buyerCompanyId;
  final String originLabel;
  final String destinationLabel;
  final DateTime updatedAt;

  const HaulRouteRecord({
    required this.id,
    this.supplierCompanyId,
    this.buyerCompanyId,
    required this.originLabel,
    required this.destinationLabel,
    required this.updatedAt,
  });

  factory HaulRouteRecord.fromJson(Map<String, dynamic> json) {
    return HaulRouteRecord(
      id: json['id'] as String,
      supplierCompanyId: json['supplier_company_id'] as String?,
      buyerCompanyId: json['buyer_company_id'] as String?,
      originLabel: json['origin_label'] as String,
      destinationLabel: json['destination_label'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class TripRecord {
  final String id;
  final String transactionId;
  final String? vehicleId;
  final String? routeId;
  final String? dispatchId;
  final String status;
  final double? netTons;
  final String? truckReg;
  final DateTime updatedAt;

  /// When the driver reported arriving at the offload point
  /// (`metadata.arrived_at_offload_at`, written by
  /// `mark_trip_arrived_at_offload`).
  ///
  /// This is bookkeeping, NOT a lifecycle status: the trip stays
  /// `en_route_to_offload` until the POD closes it as offloaded + completed in
  /// one step (CLAUDE.md §4). The driver's "Arrived at offloading" button used
  /// to write the `offloaded` status directly, which said the load was already
  /// off the truck — sometimes before it had even been checked out of the mine.
  final DateTime? arrivedAtOffloadAt;

  const TripRecord({
    required this.id,
    required this.transactionId,
    this.vehicleId,
    this.routeId,
    this.dispatchId,
    required this.status,
    this.netTons,
    this.truckReg,
    required this.updatedAt,
    this.arrivedAtOffloadAt,
  });

  factory TripRecord.fromJson(Map<String, dynamic> json) {
    final meta = json['metadata'];
    final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : const {};
    return TripRecord(
      id: json['id'] as String,
      transactionId: json['transaction_id'] as String,
      vehicleId: json['vehicle_id'] as String?,
      routeId: json['route_id'] as String?,
      dispatchId: json['dispatch_id'] as String?,
      status: (json['status'] as String?) ?? 'scheduled',
      netTons: (json['net_tons'] as num?)?.toDouble(),
      truckReg: metaMap['truck_reg'] as String?,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      arrivedAtOffloadAt:
          DateTime.tryParse('${metaMap['arrived_at_offload_at'] ?? ''}'),
    );
  }
}

class VehiclePositionRecord {
  final String id;
  final String vehicleId;
  final double lat;
  final double lng;
  final double? heading;
  final DateTime recordedAt;

  const VehiclePositionRecord({
    required this.id,
    required this.vehicleId,
    required this.lat,
    required this.lng,
    this.heading,
    required this.recordedAt,
  });

  factory VehiclePositionRecord.fromJson(Map<String, dynamic> json) {
    return VehiclePositionRecord(
      id: json['id'] as String,
      vehicleId: json['vehicle_id'] as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }
}

class ReconciliationRecord {
  final String id;
  final String? buyerCompanyId;
  final String? supplierCompanyId;
  final String? transporterCompanyId;
  final String status;
  final DateTime updatedAt;

  const ReconciliationRecord({
    required this.id,
    this.buyerCompanyId,
    this.supplierCompanyId,
    this.transporterCompanyId,
    required this.status,
    required this.updatedAt,
  });

  factory ReconciliationRecord.fromJson(Map<String, dynamic> json) {
    return ReconciliationRecord(
      id: json['id'] as String,
      buyerCompanyId: json['buyer_company_id'] as String?,
      supplierCompanyId: json['supplier_company_id'] as String?,
      transporterCompanyId: json['transporter_company_id'] as String?,
      status: (json['status'] as String?) ?? 'draft',
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
