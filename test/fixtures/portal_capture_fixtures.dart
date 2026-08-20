// Fixture data for the portal reference captures.
//
// WHY THIS EXISTS
// ---------------
// `docs/design-reference/portal-*.png` were pictures of ERROR CARDS. The
// capture harness runs with no backend, every portal data provider rejects,
// and each screen's whole body — page title included — lives inside
// `.when(data:)`, so what got captured was "Could not load this / The server
// refused the request" on an otherwise empty canvas. Recorded in
// `docs/design-reference.md` §7 on 2026-08-15.
//
// That was not a cosmetic problem. S5-20/21 ask for a per-screen *visual
// comparison* against the console, and the comparison surface did not work for
// portal screens: three of them could not be migrated at all, because the
// remaining literals there are real design decisions (a second tone system, a
// bespoke driver gradient) and there was no way to look at the result.
//
// The seam is the provider, not the service. Every portal data provider is a
// `FutureProvider.family` that reads a service and returns a model list, so an
// override on the provider itself skips the network without anyone having to
// implement a service interface.
//
// WHAT THESE NUMBERS ARE, AND ARE NOT
// -----------------------------------
// They are invented, and they are named after the seeded demo companies (Iron
// Hills Mining, Atlas Buyer Group, Roadhaul Logistics) so a capture reads like
// the product rather than like lorem ipsum. **They prove nothing about any
// KPI** — the same caveat `docs/design-reference.md` §7 already carries for the
// console dashboard's fixtures. A capture is a reference for *layout and
// treatment*.
//
// Deliberately NOT uniform: one stockpile is over its 30 t collect threshold
// and one is not, one truck is on route and one is available, one load carries
// a quality penalty, one dispute is open. A fixture where every row looks the
// same hides exactly the states a design has to handle — and this project has
// already shipped one screen whose empty state nobody had seen.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/models/maintenance_record.dart';
import 'package:flutter_application_1/features/fleet/models/service_schedule.dart';
import 'package:flutter_application_1/features/fleet/models/vehicle_driver.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/fleet/providers/maintenance_providers.dart';
import 'package:flutter_application_1/features/portal/models/buyer_load_value.dart';
import 'package:flutter_application_1/features/portal/models/load_quality.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/mine_trip.dart';
import 'package:flutter_application_1/features/portal/models/production_entry.dart';
import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/models/trip_earning.dart';
import 'package:flutter_application_1/features/portal/models/trip_waypoint.dart';
import 'package:flutter_application_1/features/super_admin/providers/targets_provider.dart';
import 'ml_targets_sample.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/providers/security_confirmation_provider.dart';
import 'package:flutter_application_1/features/portal/services/buyer_value_service.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';
import 'package:flutter_application_1/features/portal/services/earnings_service.dart';
import 'package:flutter_application_1/features/portal/services/production_service.dart';
import 'package:flutter_application_1/features/portal/services/quality_service.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart';

/// A fixed instant, so a capture re-run produces the same pixels. `DateTime.now()`
/// in a fixture makes every regeneration a diff.
final DateTime kCaptureNow = DateTime.utc(2026, 8, 15, 9, 30);

DateTime _ago(Duration d) => kCaptureNow.subtract(d);

// ---------------------------------------------------------------------------
// Mine — stockpiles, production, quality
// ---------------------------------------------------------------------------

final List<StockpileEntry> kStockpiles = [
  // Over the 30 t collect threshold: 4 full loads ready.
  StockpileEntry(
    id: 'sp-1',
    name: 'Order pile · Atlas Buyer Group',
    buyer: 'Atlas Buyer Group',
    buyerCompanyId: 'co-buyer',
    tons: 128.4,
    mineral: 'Chrome',
    grade: '38% Cr2O3',
    maxCapTons: 200,
    requestId: 'req-1',
  ),
  // Under the threshold: nothing ready yet, which must not look like an error.
  StockpileEntry(
    id: 'sp-2',
    name: 'Order pile · Northvale Alloys',
    buyer: 'Northvale Alloys',
    buyerCompanyId: 'co-buyer-2',
    tons: 18.0,
    mineral: 'Chrome',
    maxCapTons: 90,
    requestId: 'req-2',
  ),
  // A ROM production pile — no buyer, no cap.
  StockpileEntry(
    id: 'sp-3',
    name: 'ROM — North Pit',
    tons: 412.6,
    mineral: 'Chrome',
    kind: 'production',
  ),
];

final List<ProductionEntry> kProductionEntries = [
  ProductionEntry(
    id: 'pe-1',
    companyId: 'co-mine',
    entryDate: _ago(const Duration(days: 1)),
    tons: 120.5,
    commodity: 'Chrome',
    pitSection: 'North Pit',
    stockpileId: 'sp-3',
    createdAt: _ago(const Duration(days: 1)),
  ),
  ProductionEntry(
    id: 'pe-2',
    companyId: 'co-mine',
    entryDate: _ago(const Duration(days: 2)),
    tons: 96.0,
    commodity: 'Chrome',
    pitSection: 'South Pit',
    createdAt: _ago(const Duration(days: 2)),
  ),
  ProductionEntry(
    id: 'pe-3',
    companyId: 'co-mine',
    entryDate: _ago(const Duration(days: 3)),
    tons: 143.2,
    commodity: 'Chrome',
    pitSection: 'North Pit',
    createdAt: _ago(const Duration(days: 3)),
  ),
];

final List<RouteQualitySpec> kRouteSpecs = const [
  RouteQualitySpec(
    routeId: 'rt-1',
    routeNumber: 'RT-0042',
    commodity: 'Chrome',
    offloadingPoint: 'Richards Bay',
    specCr2o3Pct: 42,
    specMoistureMaxPct: 8,
    specSizing: '0-6mm',
  ),
  // A route with no spec set — renders "Not set", never a zero.
  RouteQualitySpec(
    routeId: 'rt-2',
    routeNumber: 'RT-0043',
    commodity: 'Chrome',
    offloadingPoint: 'Maputo',
  ),
];

// ---------------------------------------------------------------------------
// Mine floor — inbound trips for Security and the Load Controller
// ---------------------------------------------------------------------------

MineTrip _trip({
  required String id,
  required TripStatus status,
  required String reg,
  double? netTons,
  bool seal = false,
}) =>
    MineTrip(
      tripId: id,
      status: status,
      vehicleId: 'veh-$id',
      truckReg: reg,
      routeId: 'rt-1',
      sealRequired: seal,
      netTons: netTons,
      transactionId: 'txn-$id',
      buyerCompanyId: 'co-buyer',
      buyerName: 'Atlas Buyer Group',
      transporterName: 'Roadhaul Logistics',
      commodity: 'Chrome',
      reference: 'TRP-0001$id',
      offloadingPoint: 'Richards Bay',
      loadingPoint: 'Iron Hills Mining',
      updatedAt: _ago(const Duration(minutes: 12)),
    );

/// One truck at each stage the mine floor actually sees, so the queue is not
/// four rows of the same pill.
final List<MineTrip> kInboundTrips = [
  _trip(id: '1', status: TripStatus.arrivedAtMine, reg: 'CK 84 RT GP'),
  _trip(id: '2', status: TripStatus.loading, reg: 'JD 22 PL MP', seal: true),
  _trip(
      id: '3',
      status: TripStatus.loaded,
      reg: 'BX 09 LM NW',
      netTons: 36.22),
  _trip(id: '4', status: TripStatus.enRouteToLoad, reg: 'TN 55 QQ GP'),
];

final List<SecurityConfirmation> kPendingConfirmations = [
  SecurityConfirmation(
    id: 'sc-1',
    tripId: '1',
    confirmationType: SecurityConfirmationType.arrival,
    driverConfirmed: true,
    driverConfirmedAt: _ago(const Duration(minutes: 6)),
  ),
];

// ---------------------------------------------------------------------------
// Requests and dispatches
// ---------------------------------------------------------------------------

TransportationRequest _request({
  required String id,
  required RequestStatus status,
  String commodity = 'Chrome',
}) =>
    TransportationRequest(
      id: id,
      requestingCompanyId: 'co-buyer',
      buyerCompanyId: 'co-buyer',
      requestType: 'transportation',
      status: status,
      supplierCompanyId: 'co-mine',
      loadingPoint: 'Iron Hills Mining',
      offloadingPoint: 'Richards Bay',
      commodity: commodity,
      paymentTerms: '30 days',
      isOngoing: true,
      startingDate: _ago(const Duration(days: 4)),
      createdAt: _ago(const Duration(days: 5)),
      updatedAt: _ago(const Duration(days: 1)),
    );

/// Three points of the request lifecycle, because a screen that only ever
/// renders `requested` never shows its own revision loop.
final List<TransportationRequest> kRequests = [
  _request(id: 'req-1', status: RequestStatus.linked),
  _request(id: 'req-2', status: RequestStatus.approved),
  _request(id: 'req-3', status: RequestStatus.sentBack, commodity: 'Manganese'),
];

final List<DispatchedRoute> kDispatches = [
  DispatchedRoute(
    dispatchId: 'dsp-1',
    transporterCompanyId: 'co-transporter',
    status: DispatchStatus.accepted,
    dispatchedAt: _ago(const Duration(days: 3)),
    request: kRequests.first,
    transporterPricePerTon: 410,
    routeId: 'rt-1',
    routeNumber: 'RT-0042',
  ),
];

// ---------------------------------------------------------------------------
// Money — buyer load values, transporter earnings
// ---------------------------------------------------------------------------

final List<BuyerLoadValue> kBuyerValues = [
  // Invoiced, with a variance against the payable value.
  BuyerLoadValue(
    tripId: 't-1',
    currency: 'ZAR',
    updatedAt: _ago(const Duration(hours: 5)),
    reference: 'TRP-000123',
    truckReg: 'CK 84 RT GP',
    commodity: 'Chrome',
    sourceName: 'Iron Hills Mining',
    transporterName: 'Roadhaul Logistics',
    netTons: 36.22,
    deliveredTons: 35.80,
    ratePerTon: 1200,
    loadedValue: 43464,
    deliveredValue: 42960,
    payableTons: 34.10,
    gradeFactor: 0.9048,
    payableValue: 40920,
    invoiceId: 'inv-1',
    invoiceNumber: 'INV-2026-0001',
    invoicedTons: 35.80,
    invoicedAmount: 42960,
    invoiceDate: _ago(const Duration(days: 2)),
    invoiceVariance: 2040,
    tripStatus: 'completed',
  ),
  // Delivered but not yet invoiced — nulls, not zeros.
  BuyerLoadValue(
    tripId: 't-2',
    currency: 'ZAR',
    updatedAt: _ago(const Duration(hours: 2)),
    reference: 'TRP-000124',
    truckReg: 'JD 22 PL MP',
    commodity: 'Chrome',
    sourceName: 'Iron Hills Mining',
    transporterName: 'Roadhaul Logistics',
    netTons: 34.90,
    deliveredTons: 34.90,
    ratePerTon: 1200,
    loadedValue: 41880,
    deliveredValue: 41880,
    tripStatus: 'completed',
  ),
];

final List<TripEarning> kTripEarnings = [
  TripEarning(
    tripId: 't-1',
    currency: 'ZAR',
    updatedAt: _ago(const Duration(hours: 5)),
    reference: 'TRP-000123',
    truckReg: 'CK 84 RT GP',
    commodity: 'Chrome',
    customerName: 'Atlas Buyer Group',
    sourceName: 'Iron Hills Mining',
    netTons: 36.22,
    ratePerTon: 410,
    revenue: 14850.20,
    status: 'completed',
  ),
  TripEarning(
    tripId: 't-2',
    currency: 'ZAR',
    updatedAt: _ago(const Duration(hours: 2)),
    reference: 'TRP-000124',
    truckReg: 'JD 22 PL MP',
    commodity: 'Chrome',
    customerName: 'Atlas Buyer Group',
    sourceName: 'Iron Hills Mining',
    netTons: 34.90,
    ratePerTon: 410,
    revenue: 14309.00,
    status: 'completed',
  ),
];

// ---------------------------------------------------------------------------
// Fleet
// ---------------------------------------------------------------------------

final List<FleetVehicleStatus> kFleetStatus = const [
  FleetVehicleStatus(
    vehicleId: 'veh-1',
    registration: 'CK 84 RT GP',
    isActive: true,
    onRoute: true,
    make: 'Freightliner',
    driverEmployeeId: 'emp-1',
    driverName: 'Sipho Ndlovu',
  ),
  FleetVehicleStatus(
    vehicleId: 'veh-2',
    registration: 'JD 22 PL MP',
    isActive: true,
    onRoute: false,
    make: 'Scania',
    driverEmployeeId: 'emp-2',
    driverName: 'Thandi Mokoena',
  ),
  // Available with nobody assigned — a real state the fleet screen must show.
  FleetVehicleStatus(
    vehicleId: 'veh-3',
    registration: 'BX 09 LM NW',
    isActive: true,
    onRoute: false,
    make: 'Volvo',
  ),
  // IN MAINTENANCE — the third fleet state, and the one that had no fixture at
  // all until 2026-08-20. `CLAUDE.md` §4 makes it a derived state: a truck is
  // in maintenance while an open record takes it out of service, and that is
  // what keeps `accept_request_dispatch` from booking it. A fixture that showed
  // two of the three positions proves the design handles two of them.
  FleetVehicleStatus(
    vehicleId: 'veh-4',
    registration: 'MN 07 PL GP',
    isActive: true,
    onRoute: false,
    make: 'MAN',
    inMaintenance: true,
    maintenanceTitle: 'Gearbox rebuild',
  ),
];

/// Who is on which truck.
///
/// `FIXTURE-employee` is on `veh-2`, which is the truck carrying trip `t-2`
/// (en route to offload) — so the driver's Trip screen resolves a truck AND a
/// live trip, and its hero card has something in it. A fixture that resolved
/// the truck but no trip would photograph the empty state and prove only that
/// the empty state exists.
final List<VehicleDriver> kVehicleDrivers = [
  VehicleDriver(
    assignmentId: 'va-1',
    vehicleId: 'veh-2',
    registration: 'JD 22 PL MP',
    driverEmployeeId: 'FIXTURE-employee',
    driverName: 'Fixture Operator',
    onRoute: true,
    assignedAt: _ago(const Duration(days: 12)),
  ),
  VehicleDriver(
    assignmentId: 'va-2',
    vehicleId: 'veh-1',
    registration: 'CK 84 RT GP',
    driverEmployeeId: 'emp-1',
    driverName: 'Sipho Ndlovu',
    onRoute: false,
    assignedAt: _ago(const Duration(days: 40)),
  ),
];

// ---------------------------------------------------------------------------
// Maintenance
// ---------------------------------------------------------------------------

/// One open repair and one service falling due.
///
/// The repair is the record that puts `veh-4` above into maintenance — the two
/// fixtures have to agree, because the dashboard reads the fleet status for its
/// counts and the maintenance feed for its queue, and a screen where those two
/// disagree is a screen nobody can read.
final ({List<MaintenanceRecord> records, List<ServiceSchedule> schedules})
    kMaintenance = (
  records: [
    MaintenanceRecord(
      id: 'mr-1',
      vehicleId: 'veh-4',
      registration: 'MN 07 PL GP',
      kind: MaintenanceKind.repair,
      title: 'Gearbox rebuild',
      status: MaintenanceStatus.open,
      takesOutOfService: true,
      startedAt: _ago(const Duration(days: 4)),
      expectedBackAt: kCaptureNow.add(const Duration(days: 3)),
      costZar: 48500,
      odometerKm: 91500,
    ),
  ],
  schedules: [
    ServiceSchedule(
      id: 'ss-1',
      vehicleId: 'veh-1',
      registration: 'CK 84 RT GP',
      name: 'Major service',
      notifyDaysBefore: 14,
      active: true,
      vehicleOdometerKm: 412300,
      // Inside the reminder window, so the "services due" queue has something
      // in it. A queue rendered empty says nothing about how a full one looks.
      dueDate: kCaptureNow.add(const Duration(days: 9)),
      repeatMonths: 6,
      lastDoneAt: _ago(const Duration(days: 170)),
    ),
  ],
);

// ---------------------------------------------------------------------------
// Disputes
// ---------------------------------------------------------------------------

final List<ReconDispute> kDisputes = [
  ReconDispute(
    id: 'dp-1',
    tripId: 't-1',
    transactionId: 'txn-1',
    category: DisputeCategory.weightVariance,
    reason: 'Mine net mass and delivered tons differ by more than 0.5 t.',
    status: DisputeStatus.open,
    commentCount: 2,
    createdAt: _ago(const Duration(days: 1)),
    updatedAt: _ago(const Duration(hours: 3)),
    claimedTons: 0.42,
    reference: 'TRP-000123',
  ),
];

// ---------------------------------------------------------------------------
// Production report — the daily mined-vs-dispatched series behind the mine's
// Yield % and Pit-to-port-loss cards
// ---------------------------------------------------------------------------

/// Fourteen days, deliberately uneven: two days mined nothing, one dispatched
/// more than it mined (drawing an existing pile down, which is a legitimate
/// day and reads as yield above 100%).
final List<ProductionDispatchDay> kProductionReport = [
  for (var i = 13; i >= 0; i--)
    ProductionDispatchDay(
      day: DateTime.utc(kCaptureNow.year, kCaptureNow.month, kCaptureNow.day)
          .subtract(Duration(days: i)),
      minedTons: switch (i) { 4 => 0, 9 => 0, _ => 90 + (i * 7) % 60 },
      dispatchedTons: switch (i) { 4 => 34.2, _ => 30 + (i * 11) % 45 },
    ),
];

// ---------------------------------------------------------------------------
// Logistics snapshot — routes, trips and reconciliations for the dashboards
// ---------------------------------------------------------------------------

final LogisticsSnapshot kLogistics = LogisticsSnapshot(
  routes: [
    HaulRouteRecord(
      id: 'rt-1',
      supplierCompanyId: 'co-mine',
      buyerCompanyId: 'co-buyer',
      originLabel: 'Iron Hills Mining',
      destinationLabel: 'Richards Bay',
      updatedAt: _ago(const Duration(days: 3)),
    ),
    HaulRouteRecord(
      id: 'rt-2',
      supplierCompanyId: 'co-mine',
      buyerCompanyId: 'co-buyer-2',
      originLabel: 'Iron Hills Mining',
      destinationLabel: 'Maputo',
      updatedAt: _ago(const Duration(days: 8)),
    ),
  ],
  trips: [
    TripRecord(
      id: 't-1',
      transactionId: 'txn-1',
      vehicleId: 'veh-1',
      routeId: 'rt-1',
      status: 'completed',
      netTons: 36.22,
      truckReg: 'CK 84 RT GP',
      updatedAt: _ago(const Duration(hours: 5)),
    ),
    // `dispatchId` matters here and nowhere else in this list: the driver's
    // Trip screen looks its route up BY DISPATCH to draw the From -> To
    // timeline and name the commodity. Without it the hero card renders with a
    // plate and a status pill and no route at all, which reads as a design
    // that forgot to say where the truck is going.
    TripRecord(
      id: 't-2',
      transactionId: 'txn-2',
      dispatchId: 'dsp-1',
      vehicleId: 'veh-2',
      routeId: 'rt-1',
      status: 'en_route_to_offload',
      netTons: 34.90,
      truckReg: 'JD 22 PL MP',
      updatedAt: _ago(const Duration(hours: 2)),
    ),
    TripRecord(
      id: 't-3',
      transactionId: 'txn-3',
      vehicleId: 'veh-3',
      routeId: 'rt-2',
      status: 'loading',
      truckReg: 'BX 09 LM NW',
      updatedAt: _ago(const Duration(minutes: 20)),
    ),
  ],
  positions: const [],
  reconciliations: const [],
  waybills: const [],
);

// ---------------------------------------------------------------------------
// The override list the capture harness installs
// ---------------------------------------------------------------------------

/// Overrides that make every portal data provider resolve to [kCaptureNow]-
/// stamped fixture data instead of rejecting against a missing backend.
///
/// Families are overridden wholesale, so the argument (a company id) is
/// ignored — a capture renders one org's worth of data whichever id the screen
/// resolves.
List<Override> portalCaptureOverrides() => [
      stockpilesProvider.overrideWith((ref, _) async => kStockpiles),
      mineInboundTripsProvider.overrideWith((ref, _) async => kInboundTrips),
      minePendingConfirmationsProvider
          .overrideWith((ref, _) async => kPendingConfirmations),
      productionEntriesProvider
          .overrideWith((ref, _) async => kProductionEntries),
      supplierRouteSpecsProvider.overrideWith((ref, _) async => kRouteSpecs),
      companyRequestsProvider.overrideWith((ref, _) async => kRequests),
      transporterDispatchesProvider.overrideWith((ref, _) async => kDispatches),
      buyerTripValuesProvider.overrideWith((ref, _) async => kBuyerValues),
      tripEarningsProvider.overrideWith((ref, _) async => kTripEarnings),
      reconDisputesProvider.overrideWith((ref, _) async => kDisputes),
      productionReportProvider
          .overrideWith((ref, _) async => kProductionReport),
      logisticsSnapshotProvider.overrideWith((ref, _) async => kLogistics),
      // Added 2026-08-20, when the three role dashboards were photographed for
      // the first time. `kFleetStatus` had existed in this file all along and
      // was never registered, so the transporter dashboard rendered with FOUR
      // panels reading "fleet status unavailable", "Could not read this queue"
      // and "The fleet status could not be read" — honest error states, and
      // half a screen of apology in what was supposed to be a picture of the
      // design. Nothing looked at it, so nothing noticed.
      fleetStatusProvider.overrideWith((ref, _) async => kFleetStatus),
      fleetMaintenanceProvider.overrideWith((ref, _) async => kMaintenance),
      // The driver's Trip screen rejects the whole screen when this one errors
      // — `DriverResolutionError`, deliberately, so an RLS or network failure
      // can never read as "no truck assigned". Un-overridden it errored, and
      // the hero screen of the mobile app photographed as
      // "Couldn't load your trip".
      vehicleDriversProvider.overrideWith((ref, _) async => kVehicleDrivers),
      // A StreamProvider over Supabase realtime. Left un-overridden it does
      // not merely render an error — it throws from `runOnDispose` when the
      // container tears down, AFTER the harness has restored
      // `FlutterError.onError`, which fails the test with a capture already
      // written to disk. A green PNG behind a red test is the most confusing
      // outcome available, so the stream is replaced rather than tolerated.
      targetsProvider.overrideWith(
        (ref, _) => Stream.value(MlTargetsSample.build(asOf: kCaptureNow)),
      ),
    ];
