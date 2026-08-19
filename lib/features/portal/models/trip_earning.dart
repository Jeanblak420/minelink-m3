/// Transporter earnings models. A [TripEarning] is one trip's revenue
/// (net tons × the transporter's rate/ton, from list_transporter_trip_earnings);
/// a [VehicleCost] is a vehicle's total maintenance spend
/// (list_transporter_vehicle_costs). The admin margin is never included.
library;

class TripEarning {
  final String tripId;
  final String? reference;
  final String? truckReg;
  final String? vehicleId;
  final String? routeId;
  final String? commodity;
  final String? customerName;
  final String? sourceName;
  final double? netTons;
  final double? ratePerTon;
  final String currency;
  final double? revenue;
  final String? status;
  final DateTime updatedAt;

  /// Per-trip P&L (from list_transporter_trip_pnl): [directCost] = costs tagged
  /// to this trip; [allocatedCost] = this trip's share of the vehicle's untagged
  /// cost pool (untagged fuel/operating + maintenance) split by tonnage;
  /// [totalCost] = direct + allocated; [net] = revenue − total cost.
  final double directCost;
  final double allocatedCost;
  final double totalCost;
  final double? net;

  const TripEarning({
    required this.tripId,
    required this.currency,
    required this.updatedAt,
    this.reference,
    this.truckReg,
    this.vehicleId,
    this.routeId,
    this.commodity,
    this.customerName,
    this.sourceName,
    this.netTons,
    this.ratePerTon,
    this.revenue,
    this.status,
    this.directCost = 0,
    this.allocatedCost = 0,
    this.totalCost = 0,
    this.net,
  });

  bool get isPriced => revenue != null;

  static double? _d(dynamic v) => (v as num?)?.toDouble();
  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory TripEarning.fromJson(Map<String, dynamic> j) => TripEarning(
        tripId: j['trip_id'] as String,
        reference: _s(j['reference']),
        truckReg: _s(j['truck_reg']),
        vehicleId: _s(j['vehicle_id']),
        routeId: _s(j['route_id']),
        commodity: _s(j['commodity']),
        customerName: _s(j['customer_name']),
        sourceName: _s(j['source_name']),
        netTons: _d(j['net_tons']),
        ratePerTon: _d(j['rate_per_ton']),
        currency: (_s(j['currency']) ?? 'ZAR'),
        revenue: _d(j['revenue']),
        status: _s(j['status']),
        directCost: _d(j['direct_cost']) ?? 0,
        allocatedCost: _d(j['allocated_cost']) ?? 0,
        totalCost: _d(j['total_cost']) ?? 0,
        net: _d(j['net']),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

class VehicleCost {
  final String vehicleId;
  final String? reg;
  final double maintenanceCost;
  final int recordCount;

  const VehicleCost({
    required this.vehicleId,
    required this.maintenanceCost,
    required this.recordCount,
    this.reg,
  });

  factory VehicleCost.fromJson(Map<String, dynamic> j) => VehicleCost(
        vehicleId: j['vehicle_id'] as String,
        reg: (j['reg'] as String?)?.trim(),
        maintenanceCost: (j['maintenance_cost'] as num?)?.toDouble() ?? 0,
        recordCount: (j['record_count'] as num?)?.toInt() ?? 0,
      );
}
