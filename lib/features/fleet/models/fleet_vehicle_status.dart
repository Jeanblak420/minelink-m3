/// A fleet vehicle plus its live route-availability, as returned by the
/// `list_transporter_fleet_status` RPC (CLAUDE.md §4 truck Available↔On-Route
/// state machine). Availability is derived server-side from active trips, so a
/// truck is [onRoute] while it has a trip that is not completed/cancelled.
class FleetVehicleStatus {
  final String vehicleId;
  final String registration;
  final String? make;
  final String? vehicleType;
  final String? driverEmployeeId;
  final String? driverName;

  /// Every assigned driver's name, comma-joined (multi-driver per truck,
  /// CLAUDE.md §4). Falls back to the legacy single embedded driver.
  final String? drivers;
  final int driverCount;
  final int maxDrivers;
  final bool isActive;
  final bool onRoute;

  // Populated only when [onRoute] — details of the current route.
  final String? activeTripId;
  final String? tripStatus;
  final String? buyerName;
  final String? commodity;
  final String? offloadingPoint;
  final String? loadingPoint;

  /// Derived third fleet state (spec 2026-07-17): true while the truck has an
  /// open maintenance record with takes_out_of_service. Closing the record is
  /// the only thing needed to return the truck to Available.
  final bool inMaintenance;

  /// Title of the blocking open maintenance record, when [inMaintenance].
  final String? maintenanceTitle;

  const FleetVehicleStatus({
    required this.vehicleId,
    required this.registration,
    required this.isActive,
    required this.onRoute,
    this.make,
    this.vehicleType,
    this.driverEmployeeId,
    this.driverName,
    this.drivers,
    this.driverCount = 0,
    this.maxDrivers = 2,
    this.activeTripId,
    this.tripStatus,
    this.buyerName,
    this.commodity,
    this.offloadingPoint,
    this.loadingPoint,
    this.inMaintenance = false,
    this.maintenanceTitle,
  });

  /// Selectable for a new route: an active truck not already on one and not
  /// down for maintenance.
  bool get available => isActive && !onRoute && !inMaintenance;

  String get driverLabel =>
      (driverName != null && driverName!.trim().isNotEmpty)
          ? driverName!.trim()
          : 'No driver assigned';

  /// All assigned drivers, or the no-driver placeholder.
  String get driversLabel =>
      (drivers != null && drivers!.trim().isNotEmpty)
          ? drivers!.trim()
          : 'No driver assigned';

  /// Whether anybody is actually rostered on this truck.
  ///
  /// Read this rather than string-matching `driversLabel` against the
  /// placeholder: a truck with no driver is a real operational state, not a
  /// display quirk. `accept_request_dispatch` checks that a truck is in the
  /// fleet, active, not already on a route and not in maintenance — but not
  /// that it has a driver — so a truck can run a whole trip with nobody on it.
  bool get hasDriver => drivers != null && drivers!.trim().isNotEmpty;

  static String? _str(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory FleetVehicleStatus.fromJson(Map<String, dynamic> j) {
    return FleetVehicleStatus(
      vehicleId: j['vehicle_id'] as String,
      registration: (j['registration'] as String?) ?? '—',
      make: _str(j['make']),
      vehicleType: _str(j['vehicle_type']),
      driverEmployeeId: _str(j['driver_employee_id']),
      driverName: _str(j['driver_name']),
      drivers: _str(j['drivers']),
      driverCount: (j['driver_count'] as num?)?.toInt() ?? 0,
      maxDrivers: (j['max_drivers'] as num?)?.toInt() ?? 2,
      isActive: (j['is_active'] as bool?) ?? true,
      onRoute: (j['on_route'] as bool?) ?? false,
      activeTripId: _str(j['active_trip_id']),
      tripStatus: _str(j['trip_status']),
      buyerName: _str(j['buyer_name']),
      commodity: _str(j['commodity']),
      offloadingPoint: _str(j['offloading_point']),
      loadingPoint: _str(j['loading_point']),
      inMaintenance: (j['in_maintenance'] as bool?) ?? false,
      maintenanceTitle: _str(j['maintenance_title']),
    );
  }
}
