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
import 'package:flutter_application_1/features/super_admin/data/models/token_request.dart';
import 'package:flutter_application_1/features/super_admin/data/models/platform_role.dart';
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


// ---------------------------------------------------------------------------
// The registry — organisations, seats and token requests
// ---------------------------------------------------------------------------

/// One organisation row, shaped exactly as `companies` selects it.
///
/// `organizationsProvider` returns raw maps rather than a model, so the fixture
/// has to be a map too. The keys are the column names; getting one wrong shows
/// up as a blank cell rather than an error, which is why they are written once
/// here instead of at each call site.
Map<String, dynamic> _org(
  String id,
  String name,
  String type, {
  String status = 'active',
  int seatLimit = 5,
  int seatsUsed = 4,
  String tokenExpiresAt = '2026-12-01T08:00:00Z',
}) =>
    {
      'id': id,
      'company_name': name,
      'org_type': type,
      'status': status,
      'seat_limit': seatLimit,
      'seats_used': seatsUsed,
      'created_at': '2026-07-01T08:00:00Z',
      'token_expires_at': tokenExpiresAt,
      'physical_address': '12 Long Industrial Road, Emalahleni, Mpumalanga',
      'email': 'ops@example.com',
    };

/// The registry, in five states rather than one.
///
/// Active, seats FULL, suspended, expired, and a name long enough to test a
/// row — "Consolidated Mineral Offtake & Logistics Holdings" is the string the
/// console sweep has used since Phase 2 to find rigid columns, and it belongs
/// with the rest of the fixture rather than in a test file's private helper.
final List<Map<String, dynamic>> kOrganizations = [
  _org('o1', 'Iron Hills Mining', 'mineSupplier'),
  _org('o2', 'Atlas Buyer Group', 'buyer', seatLimit: 3, seatsUsed: 3),
  _org('o3', 'Roadhaul Logistics', 'transporter'),
  _org('o4', 'Consolidated Mineral Offtake & Logistics Holdings', 'buyer',
      status: 'suspended'),
  _org('o5', 'Sable Ridge Chrome', 'mineSupplier',
      status: 'expired', tokenExpiresAt: '2026-08-01T08:00:00Z'),
];

/// Seat requests waiting on the admin.
///
/// One org at its limit asking for more, one asking for a longer token, and one
/// already being handled by another admin — that last state is the one a second
/// admin has to see, and a fixture of identical rows cannot show it.
///
/// The `requestKind` and `status` strings are the WIRE values the model
/// switches on (`seat_expansion` / `token_renewal`, `open` / `in_progress`).
/// The first draft invented `seats` and `validity`, which fall through
/// `requestKindLabel`'s `default:` — so a token-renewal request rendered as
/// "Seat expansion", and a row carrying a `handlingDisplayName` with
/// `status: 'open'` described a state `isInProgress` can never see. Rendering
/// the screen is what caught both.
final List<TokenRequest> kTokenRequests = [
  TokenRequest(
    id: 'tr-1',
    organizationId: 'o2',
    organizationName: 'Atlas Buyer Group',
    organizationType: 'buyer',
    requestKind: 'seat_expansion',
    currentSeatLimit: 3,
    currentSeatsUsed: 3,
    requestedExtraSeats: 2,
    requestedNewTotal: 5,
    reason: 'Two new procurement officers start on the 1st.',
    requestedByUserId: 'u-1',
    requestedByEmail: 'ops@atlas.co.za',
    status: 'open',
    createdAt: _ago(const Duration(hours: 9)),
    updatedAt: _ago(const Duration(hours: 9)),
  ),
  TokenRequest(
    id: 'tr-2',
    organizationId: 'o1',
    organizationName: 'Iron Hills Mining',
    organizationType: 'mineSupplier',
    requestKind: 'token_renewal',
    currentSeatLimit: 5,
    currentSeatsUsed: 4,
    requestedExtraSeats: 0,
    requestedNewTotal: 5,
    requestedValidDays: 365,
    reason: 'Annual renewal ahead of the token lapsing in December.',
    requestedByUserId: 'u-2',
    requestedByEmail: 'admin@ironhills.co.za',
    status: 'open',
    createdAt: _ago(const Duration(days: 2)),
    updatedAt: _ago(const Duration(days: 2)),
  ),
  TokenRequest(
    id: 'tr-3',
    organizationId: 'o3',
    organizationName: 'Roadhaul Logistics',
    organizationType: 'transporter',
    requestKind: 'seat_expansion',
    currentSeatLimit: 5,
    currentSeatsUsed: 5,
    requestedExtraSeats: 3,
    requestedNewTotal: 8,
    reason: 'Three new drivers rostered for the Richards Bay run.',
    requestedByUserId: 'u-3',
    requestedByEmail: 'fleet@roadhaul.co.za',
    status: 'in_progress',
    handlingUserId: 'admin-2',
    handlingStartedAt: _ago(const Duration(minutes: 4)),
    handlingDisplayName: 'Second Admin',
    createdAt: _ago(const Duration(days: 1)),
    updatedAt: _ago(const Duration(minutes: 4)),
  ),
];

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
      organizationsProvider.overrideWith((ref) async => kOrganizations),
      openTokenRequestsProvider.overrideWith((ref) async => kTokenRequests),
      // The console's own screens gate on this: without a platform role the
      // registry renders its restricted notice, which is a real state and not
      // the one worth photographing.
      currentPlatformRoleProvider
          .overrideWith((ref) async => PlatformRole.superGlobalSerialAdminMain),
      // No socket. `TokenRequestsScreen` keeps a realtime channel alive by
      // watching this; against the dummy Supabase instance a render harness
      // uses, that is a real connect attempt whose retry timer outlives the
      // widget tree — which fails the test with "A Timer is still pending even
      // after the widget tree was disposed", exactly as the three portal
      // notifiers did before they grew a `start()`.
      tokenRequestsRealtimeProvider.overrideWithValue(null),
    ];
