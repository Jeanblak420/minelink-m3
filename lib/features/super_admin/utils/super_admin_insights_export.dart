import 'package:flutter_application_1/features/super_admin/data/models/company_monthly_ops_stats.dart';
import 'package:share_plus/share_plus.dart';

/// Shares a single-row CSV for one company’s monthly rollup (read-only insight export).
Future<void> shareCompanyMonthlyStatsCsv({
  required CompanyMonthlyOpsStats stats,
  required String orgTypeLabel,
}) async {
  final header = [
    'company_id',
    'company_name',
    'org_type',
    'employees',
    'drivers',
    'fleet_vehicles',
    'routes_distinct',
    'trips',
    'loads_count',
    'tons_moved',
    'completed_waybills',
    'pending_waybills',
  ].join(',');

  final row = [
    _csv(stats.companyId),
    _csv(stats.companyName),
    _csv(stats.orgType),
    '${stats.employees}',
    '${stats.drivers}',
    '${stats.fleetVehicles}',
    '${stats.routesDistinct}',
    '${stats.trips}',
    '${stats.loadsCount}',
    stats.tonsMoved.toStringAsFixed(2),
    '${stats.completedWaybills}',
    '${stats.pendingWaybills}',
  ].join(',');

  final body = '$header\n$row';
  await SharePlus.instance.share(
    ShareParams(
      text: body,
      subject: 'Monthly insights · ${stats.companyName} · $orgTypeLabel',
    ),
  );
}

/// Shares a multi-row CSV — one row per company of an org type, current
/// calendar month (read-only insight export for the org overview screen).
Future<void> shareOrgCompaniesCsv({
  required List<CompanyMonthlyOpsStats> companies,
  required String orgTypeLabel,
}) async {
  final header = [
    'company_id',
    'company_name',
    'org_type',
    'employees',
    'drivers',
    'fleet_vehicles',
    'routes_distinct',
    'trips',
    'loads_count',
    'tons_moved',
    'completed_waybills',
    'pending_waybills',
  ].join(',');

  final lines = [
    header,
    for (final s in companies)
      [
        _csv(s.companyId),
        _csv(s.companyName),
        _csv(s.orgType),
        '${s.employees}',
        '${s.drivers}',
        '${s.fleetVehicles}',
        '${s.routesDistinct}',
        '${s.trips}',
        '${s.loadsCount}',
        s.tonsMoved.toStringAsFixed(2),
        '${s.completedWaybills}',
        '${s.pendingWaybills}',
      ].join(','),
  ];
  await SharePlus.instance.share(
    ShareParams(
      text: lines.join('\n'),
      subject: 'Monthly insights · $orgTypeLabel · all companies',
    ),
  );
}

String _csv(String value) {
  final v = value.replaceAll('"', '""');
  if (v.contains(',') || v.contains('\n') || v.contains('"')) {
    return '"$v"';
  }
  return v;
}
