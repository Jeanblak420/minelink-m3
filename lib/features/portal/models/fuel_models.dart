/// Fuel + operating-cost models feeding the transporter earnings net.
/// [FuelEntry] is one fill (litres/cost/odometer), [OperatingCost] a one-off
/// tyre/toll/etc, and [VehicleCostBreakdown] the per-vehicle rollup that the
/// earnings dashboard subtracts from revenue.
library;

class FuelEntry {
  final String id;
  final String vehicleId;
  final String? reg;
  final String? tripId;
  final double litres;
  final double costZar;
  final double? odometerKm;
  final String? station;
  final DateTime filledAt;
  final String? notes;
  final String? createdBy;

  const FuelEntry({
    required this.id,
    required this.vehicleId,
    required this.litres,
    required this.costZar,
    required this.filledAt,
    this.reg,
    this.tripId,
    this.odometerKm,
    this.station,
    this.notes,
    this.createdBy,
  });

  /// Rand-per-litre for this fill.
  double? get pricePerLitre => litres > 0 ? costZar / litres : null;

  static double? _d(dynamic v) => (v as num?)?.toDouble();
  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory FuelEntry.fromJson(Map<String, dynamic> j) => FuelEntry(
        id: j['id'] as String,
        vehicleId: j['vehicle_id'] as String,
        reg: _s(j['reg']),
        tripId: _s(j['trip_id']),
        litres: _d(j['litres']) ?? 0,
        costZar: _d(j['cost_zar']) ?? 0,
        odometerKm: _d(j['odometer_km']),
        station: _s(j['station']),
        filledAt: DateTime.parse(j['filled_at'] as String),
        notes: _s(j['notes']),
        createdBy: _s(j['created_by']),
      );
}

enum OperatingCostKind {
  tyre('tyre', 'Tyre'),
  toll('toll', 'Toll'),
  fine('fine', 'Fine'),
  cleaning('cleaning', 'Cleaning'),
  other('other', 'Other');

  const OperatingCostKind(this.wire, this.label);
  final String wire;
  final String label;

  static OperatingCostKind parse(String? v) {
    for (final k in OperatingCostKind.values) {
      if (k.wire == v) return k;
    }
    return OperatingCostKind.other;
  }
}

class OperatingCost {
  final String id;
  final String vehicleId;
  final String? reg;
  final String? tripId;
  final OperatingCostKind kind;
  final double costZar;
  final DateTime incurredAt;
  final String? description;

  const OperatingCost({
    required this.id,
    required this.vehicleId,
    required this.kind,
    required this.costZar,
    required this.incurredAt,
    this.reg,
    this.tripId,
    this.description,
  });

  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory OperatingCost.fromJson(Map<String, dynamic> j) => OperatingCost(
        id: j['id'] as String,
        vehicleId: j['vehicle_id'] as String,
        reg: _s(j['reg']),
        tripId: _s(j['trip_id']),
        kind: OperatingCostKind.parse(_s(j['kind'])),
        costZar: (j['cost_zar'] as num?)?.toDouble() ?? 0,
        incurredAt: DateTime.parse(j['incurred_at'] as String),
        description: _s(j['description']),
      );
}

class VehicleCostBreakdown {
  final String vehicleId;
  final String? reg;
  final double maintenanceCost;
  final double fuelCost;
  final double fuelLitres;
  final double tyreCost;
  final double tollCost;
  final double otherCost;
  final double? distanceKm;
  final double? lPer100km;
  final double? costPerKm;

  const VehicleCostBreakdown({
    required this.vehicleId,
    required this.maintenanceCost,
    required this.fuelCost,
    required this.fuelLitres,
    required this.tyreCost,
    required this.tollCost,
    required this.otherCost,
    this.reg,
    this.distanceKm,
    this.lPer100km,
    this.costPerKm,
  });

  double get totalCost =>
      maintenanceCost + fuelCost + tyreCost + tollCost + otherCost;

  static double? _d(dynamic v) => (v as num?)?.toDouble();

  factory VehicleCostBreakdown.fromJson(Map<String, dynamic> j) =>
      VehicleCostBreakdown(
        vehicleId: j['vehicle_id'] as String,
        reg: (j['reg'] as String?)?.trim(),
        maintenanceCost: _d(j['maintenance_cost']) ?? 0,
        fuelCost: _d(j['fuel_cost']) ?? 0,
        fuelLitres: _d(j['fuel_litres']) ?? 0,
        tyreCost: _d(j['tyre_cost']) ?? 0,
        tollCost: _d(j['toll_cost']) ?? 0,
        otherCost: _d(j['other_cost']) ?? 0,
        distanceKm: _d(j['distance_km']),
        lPer100km: _d(j['l_per_100km']),
        costPerKm: _d(j['cost_per_km']),
      );
}
