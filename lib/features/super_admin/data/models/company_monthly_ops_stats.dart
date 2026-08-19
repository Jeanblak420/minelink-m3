/// Per-company operational snapshot for the current calendar month (device-local window).
/// Party attribution: transporter → `transporter_company_id`, buyer → `buyer_company_id`,
/// mine/supplier → `supplier_company_id` on [transactions] / joined [trips].
class CompanyMonthlyOpsStats {
  final String companyId;
  final String companyName;
  final String orgType;
  final int fleetVehicles;
  final int drivers;
  final int employees;
  final int routesDistinct;
  final int trips;
  final int loadsCount;
  final double tonsMoved;
  final int completedWaybills;
  final int pendingWaybills;

  /// Trips in the window that were delivered no later than gate-out plus the
  /// route's agreed transit time (`public.trip_is_on_time`).
  final int onTimeTrips;

  /// Trips in the window that could be judged at all — the route has an agreed
  /// `expected_transit_hours`, the truck left the mine, and it offloaded.
  ///
  /// Carried alongside [onTimeTrips] instead of a percentage on purpose: only a
  /// reader holding both can tell "nothing to measure yet" (0 of 0) from "every
  /// load was late" (0 of 9). See [onTimePercent].
  final int dueTrips;

  /// Whole-percent on-time rate, or **null when nothing was judgeable** — which
  /// callers must render as a dash, never as 0%.
  int? get onTimePercent =>
      dueTrips <= 0 ? null : ((onTimeTrips / dueTrips) * 100).round();

  const CompanyMonthlyOpsStats({
    required this.companyId,
    required this.companyName,
    required this.orgType,
    required this.fleetVehicles,
    required this.drivers,
    required this.employees,
    required this.routesDistinct,
    required this.trips,
    required this.loadsCount,
    required this.tonsMoved,
    required this.completedWaybills,
    required this.pendingWaybills,
    this.onTimeTrips = 0,
    this.dueTrips = 0,
  });

  factory CompanyMonthlyOpsStats.fromRpcJson(Map<String, dynamic> j) {
    return CompanyMonthlyOpsStats(
      companyId: j['company_id'] as String,
      companyName: j['company_name'] as String? ?? '',
      orgType: j['org_type'] as String? ?? '',
      fleetVehicles: (j['fleet_vehicles'] as num?)?.toInt() ?? 0,
      drivers: (j['drivers'] as num?)?.toInt() ?? 0,
      employees: (j['employees'] as num?)?.toInt() ?? 0,
      routesDistinct: (j['routes_distinct'] as num?)?.toInt() ?? 0,
      trips: (j['trips'] as num?)?.toInt() ?? 0,
      loadsCount: (j['loads_count'] as num?)?.toInt() ?? 0,
      tonsMoved: (j['tons_moved'] as num?)?.toDouble() ?? 0,
      completedWaybills: (j['completed_waybills'] as num?)?.toInt() ?? 0,
      pendingWaybills: (j['pending_waybills'] as num?)?.toInt() ?? 0,
      // Absent on an older database: 0 of 0 reads as "no measure", which is the
      // correct answer for a deployment that has not got the column yet.
      onTimeTrips: (j['on_time_trips'] as num?)?.toInt() ?? 0,
      dueTrips: (j['due_trips'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Summed metrics for all companies of one org type this month.
class OrgTypeAggregateStats {
  final String orgType;
  final int companyCount;
  final int activeTripsApprox;
  final int fleetVehiclesTotal;
  final double tonsMoved;
  final int transactionsTotal;
  final int completedWaybills;
  final int pendingWaybills;

  /// Network on-time, same rule and same caveat as
  /// [CompanyMonthlyOpsStats.onTimeTrips] / [CompanyMonthlyOpsStats.dueTrips].
  final int onTimeTrips;
  final int dueTrips;

  /// Null when nothing in the window was judgeable — render a dash, not 0%.
  int? get onTimePercent =>
      dueTrips <= 0 ? null : ((onTimeTrips / dueTrips) * 100).round();

  const OrgTypeAggregateStats({
    required this.orgType,
    required this.companyCount,
    required this.activeTripsApprox,
    required this.fleetVehiclesTotal,
    required this.tonsMoved,
    required this.transactionsTotal,
    required this.completedWaybills,
    required this.pendingWaybills,
    this.onTimeTrips = 0,
    this.dueTrips = 0,
  });

  factory OrgTypeAggregateStats.fromRpcJson(Map<String, dynamic> j) {
    return OrgTypeAggregateStats(
      orgType: j['org_type'] as String? ?? '',
      companyCount: (j['company_count'] as num?)?.toInt() ?? 0,
      activeTripsApprox: (j['active_trips_approx'] as num?)?.toInt() ?? 0,
      fleetVehiclesTotal: (j['fleet_vehicles_total'] as num?)?.toInt() ?? 0,
      tonsMoved: (j['tons_moved'] as num?)?.toDouble() ?? 0,
      transactionsTotal: (j['transactions_total'] as num?)?.toInt() ?? 0,
      completedWaybills: (j['completed_waybills'] as num?)?.toInt() ?? 0,
      pendingWaybills: (j['pending_waybills'] as num?)?.toInt() ?? 0,
      onTimeTrips: (j['on_time_trips'] as num?)?.toInt() ?? 0,
      dueTrips: (j['due_trips'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Single RPC round-trip for layer 1–2 insights (companies + aggregate).
class MonthlyInsightsBundle {
  final List<CompanyMonthlyOpsStats> companies;
  final OrgTypeAggregateStats aggregate;
  final String? rangeStartIso;
  final String? rangeEndIso;
  final bool fromDatabaseRpc;

  const MonthlyInsightsBundle({
    required this.companies,
    required this.aggregate,
    this.rangeStartIso,
    this.rangeEndIso,
    this.fromDatabaseRpc = true,
  });
}
