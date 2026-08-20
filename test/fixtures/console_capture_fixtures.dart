// Fixture data for the SUPER-ADMIN CONSOLE's own screens.
//
// Separate from `portal_capture_fixtures.dart` because the providers are
// different — these are `super_admin_providers.dart` and the margin ledger's
// own — and because the two answer to different rules. A portal fixture is one
// company's view of its own loop; a console fixture is the platform's view of
// everybody, which is exactly the data that must never leak into a portal
// render.
//
// The figures are invented and named after the seeded demo companies, and they
// prove nothing about any KPI. What is real is every pixel of layout, type,
// colour and shape.
//
// NOT UNIFORM, on purpose. The margin ledger carries one route where the admin
// takes a wide cut and one where it is thin, and one route that has moved no
// tonnage at all — so `marginEarned` renders a real zero next to real figures.
// The insights bundle carries one company with nothing judgeable for on-time
// (0 of 0, which the model insists must render as a dash and never as 0%) and
// one that is genuinely late.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/super_admin/data/models/company_monthly_ops_stats.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/screens/margin_ledger_screen.dart';

import 'portal_capture_fixtures.dart' show kCaptureNow;

DateTime _ago(Duration d) => kCaptureNow.subtract(d);

// ---------------------------------------------------------------------------
// Margin ledger — the super-admin's private pricing record
// ---------------------------------------------------------------------------

/// Three routes, three shapes of margin.
///
/// `RT-0042` is the wide cut on a route that has moved real tonnage. `RT-0043`
/// is thin. `RT-0044` was linked and dispatched but nothing has rolled yet, so
/// its `marginEarned` is a genuine zero — the case a fixture of three healthy
/// rows would never show, and the one a reader most needs to be able to tell
/// apart from "we have not measured it".
final List<MarginLedgerEntry> kMarginLedger = [
  MarginLedgerEntry(
    id: 'ml-1',
    requestId: 'req-1',
    routeNumber: 'RT-0042',
    supplierName: 'Iron Hills Mining',
    buyerName: 'Atlas Buyer Group',
    transporterName: 'Roadhaul Logistics',
    commodity: 'Chrome',
    loadingPoint: 'Iron Hills Mining',
    offloadingPoint: 'Richards Bay',
    agreedPricePerTon: 520,
    adminMarginPerTon: 110,
    transporterPricePerTon: 410,
    currency: 'ZAR',
    tonsMoved: 1284.60,
    createdAt: _ago(const Duration(days: 26)),
  ),
  MarginLedgerEntry(
    id: 'ml-2',
    requestId: 'req-2',
    routeNumber: 'RT-0043',
    supplierName: 'Iron Hills Mining',
    buyerName: 'Northvale Alloys',
    transporterName: 'Northline Carriers',
    commodity: 'Manganese',
    loadingPoint: 'Iron Hills Mining',
    offloadingPoint: 'Maputo',
    agreedPricePerTon: 638,
    adminMarginPerTon: 28,
    transporterPricePerTon: 610,
    currency: 'ZAR',
    tonsMoved: 412.10,
    createdAt: _ago(const Duration(days: 11)),
  ),
  MarginLedgerEntry(
    id: 'ml-3',
    requestId: 'req-3',
    routeNumber: 'RT-0044',
    supplierName: 'Sable Ridge Chrome',
    buyerName: 'Atlas Buyer Group',
    transporterName: 'Roadhaul Logistics',
    commodity: 'Chrome',
    loadingPoint: 'Sable Ridge Chrome',
    offloadingPoint: 'Richards Bay',
    agreedPricePerTon: 495,
    adminMarginPerTon: 95,
    transporterPricePerTon: 400,
    currency: 'ZAR',
    tonsMoved: 0,
    createdAt: _ago(const Duration(days: 2)),
  ),
];

// ---------------------------------------------------------------------------
// Org insights — the per-org-type monthly bundle
// ---------------------------------------------------------------------------

CompanyMonthlyOpsStats _company({
  required String id,
  required String name,
  required String orgType,
  int fleet = 0,
  int drivers = 0,
  int employees = 0,
  int routes = 0,
  int trips = 0,
  int loads = 0,
  double tons = 0,
  int completedWaybills = 0,
  int pendingWaybills = 0,
  int onTime = 0,
  int due = 0,
}) =>
    CompanyMonthlyOpsStats(
      companyId: id,
      companyName: name,
      orgType: orgType,
      fleetVehicles: fleet,
      drivers: drivers,
      employees: employees,
      routesDistinct: routes,
      trips: trips,
      loadsCount: loads,
      tonsMoved: tons,
      completedWaybills: completedWaybills,
      pendingWaybills: pendingWaybills,
      onTimeTrips: onTime,
      dueTrips: due,
    );

/// The transporter bundle: four hauliers, deliberately unlike each other.
///
/// `co-t-3` has **0 of 0** judgeable trips. `CompanyMonthlyOpsStats` is emphatic
/// that this must render as a dash and never as 0% — "only a reader holding both
/// can tell 'nothing to measure yet' from 'every load was late'" — and a fixture
/// where every company has a rate is a fixture that cannot show whether the
/// screen honours it. `co-t-4` is the one that really is late.
MonthlyInsightsBundle kTransporterInsights = MonthlyInsightsBundle(
  companies: [
    _company(
      id: 'co-t-1',
      name: 'Roadhaul Logistics',
      orgType: 'transporter',
      fleet: 24,
      drivers: 31,
      employees: 44,
      routes: 6,
      trips: 128,
      loads: 128,
      tons: 4382.60,
      completedWaybills: 121,
      pendingWaybills: 7,
      onTime: 112,
      due: 121,
    ),
    _company(
      id: 'co-t-2',
      name: 'Northline Carriers',
      orgType: 'transporter',
      fleet: 11,
      drivers: 14,
      employees: 19,
      routes: 3,
      trips: 47,
      loads: 47,
      tons: 1520.40,
      completedWaybills: 44,
      pendingWaybills: 3,
      onTime: 39,
      due: 44,
    ),
    _company(
      id: 'co-t-3',
      name: 'Kopano Freight',
      orgType: 'transporter',
      fleet: 4,
      drivers: 5,
      employees: 8,
      routes: 1,
      trips: 3,
      loads: 3,
      tons: 96.20,
      completedWaybills: 0,
      pendingWaybills: 3,
    ),
    _company(
      id: 'co-t-4',
      name: 'Vaal Bulk Movers',
      orgType: 'transporter',
      fleet: 9,
      drivers: 9,
      employees: 12,
      routes: 2,
      trips: 22,
      loads: 22,
      tons: 704.80,
      completedWaybills: 20,
      pendingWaybills: 2,
      onTime: 6,
      due: 20,
    ),
  ],
  aggregate: const OrgTypeAggregateStats(
    orgType: 'transporter',
    companyCount: 4,
    activeTripsApprox: 12,
    fleetVehiclesTotal: 48,
    tonsMoved: 6704.00,
    transactionsTotal: 200,
    completedWaybills: 185,
    pendingWaybills: 15,
    onTimeTrips: 157,
    dueTrips: 185,
  ),
  rangeStartIso: '2026-08-01',
  rangeEndIso: '2026-08-31',
);

/// Overrides the console's own data providers.
///
/// `monthlyInsightsBundleProvider` is a family keyed by org type and is
/// overridden wholesale, so every org-type screen renders the transporter
/// bundle. That is honest for a LAYOUT reference and dishonest for anything
/// else — which is why the company names in it are visibly invented.
List<Override> consoleCaptureOverrides() => [
      marginLedgerProvider.overrideWith((ref) async => kMarginLedger),
      monthlyInsightsBundleProvider
          .overrideWith((ref, _) async => kTransporterInsights),
    ];
