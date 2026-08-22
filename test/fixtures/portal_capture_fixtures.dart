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
import 'package:flutter_application_1/core/time/ml_time.dart';

import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/models/maintenance_record.dart';
import 'package:flutter_application_1/features/fleet/models/service_schedule.dart';
import 'package:flutter_application_1/features/fleet/models/vehicle_driver.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/fleet/providers/maintenance_providers.dart';
import 'package:flutter_application_1/features/portal/models/buyer_load_value.dart';
import 'package:flutter_application_1/features/portal/models/load_quality.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/mine_trip.dart';
import 'package:flutter_application_1/features/portal/models/production_entry.dart';
import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/models/request_tracking.dart';
import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';
import 'package:flutter_application_1/features/portal/models/trip_reconciliation.dart';
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
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
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
    // 96, not 90. At 90 this pile had exactly 72 t to go and so did the one
    // above it (200 - 128.4 = 71.6, which rounds to 72) — two different piles
    // printing the identical figure one card apart, which reads as a
    // copy-paste fault in a picture of the screen even though both numbers
    // are right.
    maxCapTons: 96,
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
// Reconciliation — Side A raw rows, Side B variances, quality certificates
// ---------------------------------------------------------------------------

/// Side A: the recon table exactly as captured, in the column order CLAUDE.md
/// §4 fixes — DATE · TIME-IN · WAYBILL · TRANSPORTER · REG · DESTINATION ·
/// PRODUCT · SOURCE · CUSTOMER · NET MASS · TIME-OUT.
///
/// **Two dates and two transporters, on purpose.** The table blanks `DATE` on
/// every row after the first of a group, so a fixture on one day cannot show
/// that behaviour at all — and the Transporter filter has nothing to filter.
///
/// Row 3 has a **null delivered weight and therefore a null variance**, which is
/// the state the model's own comment insists is not a measured zero: the truck
/// is loaded and gone but no POD has landed. A fixture where every load is
/// closed hides exactly the row a reconciler is looking for.
///
/// **Rows 4 and 5 are OLD, and that is the point.** The recon table's five
/// period cards — Day, Week, Month, Year, Total — are rolling windows over
/// these rows, and until 2026-08-21 every row here fell inside 24 hours. So
/// all five cards read `103.22 t`, identically, in every render of every recon
/// screen. Five stat cards showing one number cannot show that the windows
/// work, cannot show that they differ, and cannot fail if one of them breaks.
/// Rows 4–8 sit one in each window: four days back (inside the week, outside
/// the day), twenty-one days back (inside the month, outside the week), forty
/// days back (inside the year, outside the month), two hundred days back
/// (inside the year), and eighteen months back (inside the total only). So
/// Day < Week < Month < Year < Total — five DISTINCT figures, and a window
/// that stops working shows up as two cards agreeing.
/// A recon row's dates as the PARSER produces them.
///
/// `RawReconRow.fromJson` runs `MlTime.sast` on `trip_date`, `time_in` and
/// `time_out`, so those three fields are South African **wall clocks** by the
/// time any screen sees them — not instants. This fixture used raw
/// `DateTime.utc` values, which are the opposite, and the recon view then
/// converted them a second time. The two errors cancelled: the rendered time
/// was right in the test and wrong in production on any device outside South
/// Africa. Going through `MlTime.sast` here is what makes the fixture the same
/// kind of value the app really holds, and it is why `MlTime.sast`'s assert
/// now has something true to protect.
DateTime _sast(DateTime instant) => MlTime.sast(instant);

final List<RawReconRow> kRawReconRows = [
  RawReconRow(
    tripId: 't-1',
    tripDate: _sast(DateTime.utc(2026, 8, 15, 6, 12)),
    timeIn: _sast(DateTime.utc(2026, 8, 15, 6, 12)),
    waybillNumber: 'TRP-000123',
    transporterName: 'Roadhaul Logistics',
    truckReg: 'CK 84 RT GP',
    destination: 'Richards Bay',
    product: 'Chrome',
    sourceName: 'Iron Hills Mining',
    customerName: 'Atlas Buyer Group',
    netMass: 36.22,
    deliveredTons: 35.80,
    varianceTons: 0.42,
    timeOut: _sast(DateTime.utc(2026, 8, 15, 7, 4)),
    tripStatus: 'completed',
    podPhotoPath: 'FIXTURE-company/pod/t-1.jpg',
  ),
  RawReconRow(
    tripId: 't-2',
    tripDate: _sast(DateTime.utc(2026, 8, 15, 9, 30)),
    timeIn: _sast(DateTime.utc(2026, 8, 15, 9, 30)),
    waybillNumber: 'TRP-000124',
    transporterName: 'Roadhaul Logistics',
    truckReg: 'JD 22 PL MP',
    destination: 'Richards Bay',
    product: 'Chrome',
    sourceName: 'Iron Hills Mining',
    customerName: 'Atlas Buyer Group',
    netMass: 34.90,
    deliveredTons: 34.90,
    varianceTons: 0,
    timeOut: _sast(DateTime.utc(2026, 8, 15, 10, 11)),
    tripStatus: 'completed',
  ),
  RawReconRow(
    tripId: 't-3',
    tripDate: _sast(DateTime.utc(2026, 8, 14, 14, 48)),
    timeIn: _sast(DateTime.utc(2026, 8, 14, 14, 48)),
    waybillNumber: 'TRP-000119',
    transporterName: 'Northline Carriers',
    truckReg: 'BX 09 LM NW',
    destination: 'Maputo',
    product: 'Manganese',
    sourceName: 'Iron Hills Mining',
    customerName: 'Northvale Alloys',
    netMass: 32.10,
    timeOut: _sast(DateTime.utc(2026, 8, 14, 15, 22)),
    tripStatus: 'en_route_to_offload',
  ),
  RawReconRow(
    tripId: 't-wk-1',
    tripDate: _sast(DateTime.utc(2026, 8, 11, 6, 20)),
    timeIn: _sast(DateTime.utc(2026, 8, 11, 6, 20)),
    waybillNumber: 'TRP-000112',
    transporterName: 'Roadhaul Logistics',
    truckReg: 'JD 22 PL MP',
    destination: 'Richards Bay',
    product: 'Chrome',
    sourceName: 'Iron Hills Mining',
    customerName: 'Atlas Buyer Group',
    netMass: 33.48,
    deliveredTons: 33.10,
    varianceTons: 0.38,
    timeOut: _sast(DateTime.utc(2026, 8, 11, 7, 15)),
    tripStatus: 'completed',
  ),
  RawReconRow(
    tripId: 't-mo-1',
    tripDate: _sast(DateTime.utc(2026, 7, 25, 12, 5)),
    timeIn: _sast(DateTime.utc(2026, 7, 25, 12, 5)),
    waybillNumber: 'TRP-000101',
    transporterName: 'Northline Carriers',
    truckReg: 'BX 09 LM NW',
    destination: 'Maputo',
    product: 'Manganese',
    sourceName: 'Iron Hills Mining',
    customerName: 'Northvale Alloys',
    netMass: 31.76,
    deliveredTons: 31.20,
    varianceTons: 0.56,
    timeOut: _sast(DateTime.utc(2026, 7, 25, 12, 58)),
    tripStatus: 'completed',
  ),
  RawReconRow(
    tripId: 't-old-1',
    tripDate: _sast(DateTime.utc(2026, 7, 6, 7, 40)),
    timeIn: _sast(DateTime.utc(2026, 7, 6, 7, 40)),
    waybillNumber: 'TRP-000088',
    transporterName: 'Roadhaul Logistics',
    truckReg: 'CK 84 RT GP',
    destination: 'Richards Bay',
    product: 'Chrome',
    sourceName: 'Iron Hills Mining',
    customerName: 'Atlas Buyer Group',
    netMass: 35.64,
    deliveredTons: 35.64,
    varianceTons: 0,
    timeOut: _sast(DateTime.utc(2026, 7, 6, 8, 31)),
    tripStatus: 'completed',
  ),
  RawReconRow(
    tripId: 't-old-2',
    tripDate: _sast(DateTime.utc(2026, 1, 28, 5, 55)),
    timeIn: _sast(DateTime.utc(2026, 1, 28, 5, 55)),
    waybillNumber: 'TRP-000021',
    transporterName: 'Northline Carriers',
    truckReg: 'BX 09 LM NW',
    destination: 'Maputo',
    product: 'Manganese',
    sourceName: 'Iron Hills Mining',
    customerName: 'Northvale Alloys',
    netMass: 30.05,
    deliveredTons: 29.40,
    varianceTons: 0.65,
    timeOut: _sast(DateTime.utc(2026, 1, 28, 6, 48)),
    tripStatus: 'completed',
  ),
  RawReconRow(
    tripId: 't-old-3',
    tripDate: _sast(DateTime.utc(2025, 2, 10, 8, 5)),
    timeIn: _sast(DateTime.utc(2025, 2, 10, 8, 5)),
    waybillNumber: 'TRP-000004',
    transporterName: 'Northline Carriers',
    truckReg: 'BX 09 LM NW',
    destination: 'Maputo',
    product: 'Manganese',
    sourceName: 'Iron Hills Mining',
    customerName: 'Northvale Alloys',
    netMass: 28.90,
    deliveredTons: 28.90,
    varianceTons: 0,
    timeOut: _sast(DateTime.utc(2025, 2, 10, 9, 2)),
    tripStatus: 'completed',
  ),
];

/// Side B: the same three loads as the system's own cross-check.
///
/// One clean, one with mass that left the mine and did not arrive, one still
/// open. `variance` is positive-means-missing, per the model's contract.
final List<TripReconciliation> kTripReconciliations = [
  TripReconciliation(
    tripId: 't-1',
    updatedAt: _ago(const Duration(hours: 5)),
    reference: 'TRP-000123',
    truckReg: 'CK 84 RT GP',
    commodity: 'Chrome',
    sourceName: 'Iron Hills Mining',
    customerName: 'Atlas Buyer Group',
    transporterName: 'Roadhaul Logistics',
    mineNetTons: 36.22,
    deliveredTons: 35.80,
    variance: 0.42,
    tripStatus: 'completed',
    podPhotoPath: 'FIXTURE-company/pod/t-1.jpg',
  ),
  TripReconciliation(
    tripId: 't-2',
    updatedAt: _ago(const Duration(hours: 2)),
    reference: 'TRP-000124',
    truckReg: 'JD 22 PL MP',
    commodity: 'Chrome',
    sourceName: 'Iron Hills Mining',
    customerName: 'Atlas Buyer Group',
    transporterName: 'Roadhaul Logistics',
    mineNetTons: 34.90,
    deliveredTons: 34.90,
    variance: 0,
    tripStatus: 'completed',
  ),
  TripReconciliation(
    tripId: 't-3',
    updatedAt: _ago(const Duration(hours: 20)),
    reference: 'TRP-000119',
    truckReg: 'BX 09 LM NW',
    commodity: 'Manganese',
    sourceName: 'Iron Hills Mining',
    customerName: 'Northvale Alloys',
    transporterName: 'Northline Carriers',
    mineNetTons: 32.10,
    tripStatus: 'en_route_to_offload',
  ),
];

/// Quality certificates, and the absence of one.
///
/// `t-1` carries the worked example from CLAUDE.md §4 — 38% Cr₂O₃ against a 42%
/// spec and 10% moisture against an 8% maximum, giving 34.10 payable tons and a
/// 0.9048 grade factor. `t-3` has **no certificate at all**, which is what most
/// rows look like until the mine attaches one, and is the state the table has to
/// render as "not set" rather than as a zero.
final List<LoadQualityRow> kLoadQuality = [
  LoadQualityRow(
    tripId: 't-1',
    updatedAt: _ago(const Duration(hours: 5)),
    reference: 'TRP-000123',
    truckReg: 'CK 84 RT GP',
    commodity: 'Chrome',
    sourceName: 'Iron Hills Mining',
    customerName: 'Atlas Buyer Group',
    netTons: 36.22,
    deliveredTons: 35.80,
    cr2o3Pct: 38,
    moisturePct: 10,
    sizing: '0-6mm',
    certFileName: 'lab-TRP-000123.pdf',
    certPath: 'FIXTURE-company/quality/t-1.pdf',
    issuedAt: _ago(const Duration(days: 1)),
    specCr2o3Pct: 42,
    specMoistureMaxPct: 8,
    specSizing: '0-6mm',
    payableTons: 34.10,
    gradeFactor: 0.9048,
    tripStatus: 'completed',
    routeId: 'rt-1',
  ),
  LoadQualityRow(
    tripId: 't-3',
    updatedAt: _ago(const Duration(hours: 20)),
    reference: 'TRP-000119',
    truckReg: 'BX 09 LM NW',
    commodity: 'Manganese',
    sourceName: 'Iron Hills Mining',
    customerName: 'Northvale Alloys',
    netTons: 32.10,
    tripStatus: 'en_route_to_offload',
    routeId: 'rt-2',
  ),
];

/// The two retained versions of an exported-then-edited reconciliation.
///
/// One pair has an edited upload and one does not, because "Original only" and
/// "Original + Edited — uploaded {date}" are two different rows to draw and the
/// second is the whole point of the round-trip rule.
final List<ReconUploadPair> kReconUploadPairs = [
  ReconUploadPair(
    id: 'rup-1',
    companyId: 'FIXTURE-company',
    side: 'A',
    originalPath: 'FIXTURE-company/recon/A-original.xlsx',
    originalCreatedAt: _ago(const Duration(days: 3)),
    editedPath: 'FIXTURE-company/recon/A-edited.xlsx',
    editedUploadedAt: _ago(const Duration(days: 1)),
  ),
  ReconUploadPair(
    id: 'rup-2',
    companyId: 'FIXTURE-company',
    side: 'B',
    originalPath: 'FIXTURE-company/recon/B-original.xlsx',
    originalCreatedAt: _ago(const Duration(days: 2)),
  ),
];

// ---------------------------------------------------------------------------
// Requests and dispatches
// ---------------------------------------------------------------------------

/// A transportation request as the DATABASE actually returns one.
///
/// It used to set nine fields. A live row on production has twenty-odd, and
/// the transporter's route card and route-detail sheet read most of the ones
/// it was missing — `distance`, `tonsAvailable`, `numSlots`, `diesel`,
/// `contractDuration`, `routeNotes`, the operating window, `sealRequired`,
/// `endingDate`. Every one of them rendered as an absent row in
/// `screen-transporter-routes-desktop-dark.png`, so 225 renders photographed a
/// route sheet roughly half the size of the real one. A fixture that says less
/// than the service it stands in for cannot photograph a fault in what it does
/// not say — CLAUDE.md §10.5.
///
/// ⚠️ **`rate` is set on purpose, and is the one field that must NOT appear.**
/// It is the figure the BUYER typed. The transporter's own price is
/// `DispatchedRoute.transporterPricePerTon`, and the gap between the two is
/// the platform admin's margin, which the transporter must never see
/// (CLAUDE.md §4; the admin's due-diligence preview promises it in those
/// words). Until 2026-08-22 the route sheet printed `Rate 950` four rows under
/// `Your price / ton R 820.00` — found by signing in as a real transporter on
/// the live app, and invisible here precisely because this fixture had no
/// `rate` to leak. **Do not remove it to make a render tidy**: a fixture that
/// omits the dangerous value can never prove the value is withheld.
/// `dispatched_route_hides_requester_pricing_test.dart` reads it.
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
      diesel: 'On transporter',
      distance: '620 km',
      rate: '950',
      tonsAvailable: '120',
      numSlots: '1',
      contractDuration: '30 days',
      operatingHours24h: true,
      sealRequired: true,
      routeNotes: 'Weighbridge closes 18:00 on Saturdays. '
          'Gate crew needs the load number before the truck rolls.',
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

// ---------------------------------------------------------------------------
// The super-admin's four request inboxes
// ---------------------------------------------------------------------------

RequestCompanyInfo _requester(String id, String name, String orgType) =>
    RequestCompanyInfo(
      id: id,
      name: name,
      orgType: orgType,
      whatsappNumber: '+27000000000',
      ceoFirstName: 'Fixture',
      ceoLastName: 'Director',
      supportEmail: 'ops@fixture.co.za',
      status: 'active',
      memberSince: DateTime.utc(2025, 4, 12),
    );

/// The transportation queue as an admin actually meets it.
///
/// **Every stage of `requested -> sent_back -> resubmitted -> approved ->
/// linked` is here**, and that is the point: the inbox filters by status,
/// colours by status and offers different actions per status, so a fixture
/// sitting on one value photographs one fifth of the screen. The `requested`
/// and `resubmitted` rows are what `adminPendingRequestCountProvider` counts —
/// the number the console badge shows — and the closed ones are the history the
/// list deliberately keeps.
final List<TransportationRequest> kAdminTransportRequests = [
  TransportationRequest(
    id: 'areq-1',
    requestingCompanyId: 'co-buyer',
    buyerCompanyId: 'co-buyer',
    requestType: 'transportation',
    status: RequestStatus.requested,
    loadingPoint: 'Iron Hills Mining',
    offloadingPoint: 'Richards Bay',
    commodity: 'Chrome',
    paymentTerms: '30 days from invoice',
    numSlots: '6',
    isOngoing: true,
    operatingHours24h: true,
    sealRequired: true,
    routeNotes: 'Weighbridge closes 18:00 on Saturdays.',
    requesterOrgType: 'buyer',
    requesterCompany: _requester('co-buyer', 'Atlas Buyer Group', 'buyer'),
    startingDate: kCaptureNow.add(const Duration(days: 2)),
    createdAt: _ago(const Duration(hours: 6)),
    updatedAt: _ago(const Duration(hours: 6)),
  ),
  // THE APPROVED ONE, and the reason it exists.
  //
  // The linking panel only shows its dispatch step — the mine picker, the
  // margin-in-Rand pricing, the resulting transporter price and the ordered
  // due-diligence gate CLAUDE.md §4 is emphatic about — once a request is
  // `approved`. Until 2026-08-21 no fixture request had that status, so the
  // most consequential flow in the product was unreachable in every test and
  // every render: the queue said "Approved 0" and the panel stopped at
  // Approve / Decline / Send back.
  TransportationRequest(
    id: 'areq-5',
    requestingCompanyId: 'co-buyer',
    buyerCompanyId: 'co-buyer',
    requestType: 'transportation',
    status: RequestStatus.approved,
    loadingPoint: 'Iron Hills Mining',
    offloadingPoint: 'Maputo Port',
    commodity: 'Manganese',
    paymentTerms: '14 days from delivery',
    numSlots: '4',
    tonsAvailable: '2400',
    pricePerTon: 742.50,
    isOngoing: false,
    operatingStart: '05:00',
    operatingEnd: '18:00',
    sealRequired: true,
    routeNotes: 'Border post closes 22:00; no night crossings.',
    requesterOrgType: 'buyer',
    requesterCompany: _requester('co-buyer', 'Atlas Buyer Group', 'buyer'),
    startingDate: kCaptureNow.add(const Duration(days: 5)),
    createdAt: _ago(const Duration(days: 2)),
    updatedAt: _ago(const Duration(hours: 3)),
  ),
  TransportationRequest(
    id: 'areq-2',
    requestingCompanyId: 'co-mine',
    requestType: 'transportation',
    status: RequestStatus.resubmitted,
    loadingPoint: 'Iron Hills Mining',
    offloadingPoint: 'Maputo',
    commodity: 'Manganese',
    paymentTerms: 'COD',
    numSlots: '3',
    isOngoing: false,
    operatingStart: '06:00',
    operatingEnd: '18:00',
    adminNotes: 'Ending date was before the start date - please correct.',
    requesterOrgType: 'mineSupplier',
    requesterCompany:
        _requester('co-mine', 'Iron Hills Mining', 'mineSupplier'),
    startingDate: kCaptureNow.add(const Duration(days: 5)),
    endingDate: kCaptureNow.add(const Duration(days: 40)),
    createdAt: _ago(const Duration(days: 3)),
    updatedAt: _ago(const Duration(hours: 2)),
  ),
  TransportationRequest(
    id: 'areq-3',
    requestingCompanyId: 'co-mine-2',
    requestType: 'transportation',
    status: RequestStatus.sentBack,
    loadingPoint: 'Sable Ridge Chrome',
    offloadingPoint: 'Richards Bay',
    commodity: 'Chrome',
    paymentTerms: '14 days',
    numSlots: '2',
    isOngoing: true,
    adminNotes: 'No offloading contact on file. Add one and resubmit.',
    requesterOrgType: 'mineSupplier',
    requesterCompany:
        _requester('co-mine-2', 'Sable Ridge Chrome', 'mineSupplier'),
    startingDate: kCaptureNow.add(const Duration(days: 9)),
    createdAt: _ago(const Duration(days: 6)),
    updatedAt: _ago(const Duration(days: 1)),
  ),
  TransportationRequest(
    id: 'areq-4',
    requestingCompanyId: 'co-buyer',
    buyerCompanyId: 'co-buyer',
    requestType: 'transportation',
    status: RequestStatus.linked,
    supplierCompanyId: 'co-mine',
    loadingPoint: 'Iron Hills Mining',
    offloadingPoint: 'Richards Bay',
    commodity: 'Chrome',
    paymentTerms: '30 days from invoice',
    numSlots: '4',
    pricePerTon: 520,
    isOngoing: true,
    requesterOrgType: 'buyer',
    requesterCompany: _requester('co-buyer', 'Atlas Buyer Group', 'buyer'),
    startingDate: _ago(const Duration(days: 20)),
    createdAt: _ago(const Duration(days: 26)),
    updatedAt: _ago(const Duration(days: 26)),
  ),
];

/// Buyers asking for product (CLAUDE.md 4, Request 2).
final List<TransportationRequest> kAdminProductRequests = [
  TransportationRequest(
    id: 'preq-1',
    requestingCompanyId: 'co-buyer',
    buyerCompanyId: 'co-buyer',
    requestType: 'product',
    status: RequestStatus.requested,
    commodity: 'Chrome',
    productSpecifications: '38-42% Cr2O3, 0-6mm, moisture below 8%',
    tonsAvailable: '4000',
    paymentTerms: '30 days from invoice',
    pricePerTon: 495,
    isOngoing: false,
    requesterOrgType: 'buyer',
    requesterCompany: _requester('co-buyer', 'Atlas Buyer Group', 'buyer'),
    createdAt: _ago(const Duration(hours: 20)),
    updatedAt: _ago(const Duration(hours: 20)),
  ),
];

/// Mines asking to be introduced to a buyer (CLAUDE.md 4, Request 3).
///
/// Carries two lab-result PDFs and an image, because the multi-file uploader is
/// part of that form and an inbox that never shows an attachment chip cannot
/// show whether the admin can open one.
final List<TransportationRequest> kAdminBuyerRequests = [
  TransportationRequest(
    id: 'breq-1',
    requestingCompanyId: 'co-mine',
    requestType: 'buyer',
    status: RequestStatus.requested,
    commodity: 'Chrome',
    tonsAvailable: '12000',
    productSpecifications: '40% Cr2O3 lumpy, ex-stock',
    paymentTerms: 'Letter of credit',
    pricePerTon: 610,
    transactionKind: 'FOT',
    labResultPaths: const [
      'co-mine/lab/sgs-2026-08-11.pdf',
      'co-mine/lab/moisture-2026-08-12.pdf',
    ],
    productImagePath: 'co-mine/photos/stockpile.jpg',
    isOngoing: false,
    requesterOrgType: 'mineSupplier',
    requesterCompany:
        _requester('co-mine', 'Iron Hills Mining', 'mineSupplier'),
    createdAt: _ago(const Duration(days: 2)),
    updatedAt: _ago(const Duration(days: 2)),
  ),
];

/// Request tracking — how far each linked order has actually got.
///
/// One order part-delivered, one finished and one that has been linked but not
/// rolled a wheel. A tracking log where every row is complete cannot show the
/// progress treatment, and one where every row is at zero cannot show the
/// completed one.
final List<RequestTrackingRow> kRequestTracking = [
  RequestTrackingRow(
    requestId: 'areq-4',
    requestType: 'transportation',
    status: 'linked',
    requesterName: 'Atlas Buyer Group',
    supplierName: 'Iron Hills Mining',
    transporterNames: 'Roadhaul Logistics',
    commodity: 'Chrome',
    loadingPoint: 'Iron Hills Mining',
    offloadingPoint: 'Richards Bay',
    tripsTotal: 34,
    tripsCompleted: 21,
    tonsDelivered: 742.60,
    isCompleted: false,
    updatedAt: _ago(const Duration(hours: 4)),
  ),
  RequestTrackingRow(
    requestId: 'req-1',
    requestType: 'transportation',
    status: 'linked',
    requesterName: 'Northvale Alloys',
    supplierName: 'Sable Ridge Chrome',
    transporterNames: 'Northline Carriers, Vaal Bulk Movers',
    commodity: 'Manganese',
    loadingPoint: 'Sable Ridge Chrome',
    offloadingPoint: 'Maputo',
    tripsTotal: 12,
    tripsCompleted: 12,
    tonsDelivered: 408.30,
    isCompleted: true,
    updatedAt: _ago(const Duration(days: 2)),
  ),
  RequestTrackingRow(
    requestId: 'req-2',
    requestType: 'transportation',
    status: 'linked',
    requesterName: 'Atlas Buyer Group',
    supplierName: 'Iron Hills Mining',
    transporterNames: 'Roadhaul Logistics',
    commodity: 'Chrome',
    loadingPoint: 'Iron Hills Mining',
    offloadingPoint: 'Richards Bay',
    tripsTotal: 8,
    tripsCompleted: 0,
    tonsDelivered: 0,
    isCompleted: false,
    updatedAt: _ago(const Duration(hours: 30)),
  ),
];

/// The companies the admin picks from when linking and dispatching.
const List<({String id, String name})> kTransporterCompanies = [
  (id: 'co-transporter', name: 'Roadhaul Logistics'),
  (id: 'co-transporter-2', name: 'Northline Carriers'),
  (id: 'co-transporter-3', name: 'Vaal Bulk Movers'),
];
const List<({String id, String name})> kMineCompanies = [
  (id: 'co-mine', name: 'Iron Hills Mining'),
  (id: 'co-mine-2', name: 'Sable Ridge Chrome'),
];
const List<({String id, String name})> kBuyerCompanies = [
  (id: 'co-buyer', name: 'Atlas Buyer Group'),
  (id: 'co-buyer-2', name: 'Northvale Alloys'),
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
    // The ids the earnings rollups group by. Without them both trips fell
    // into ONE bucket keyed '—' on the By-vehicle panel (two trucks shown as
    // one vehicle) and into TWO buckets keyed by trip id on By-route (one lane
    // shown as two routes with one trip each).
    vehicleId: 'veh-1',
    routeId: 'rt-0042',
    commodity: 'Chrome',
    customerName: 'Atlas Buyer Group',
    sourceName: 'Iron Hills Mining',
    netTons: 36.22,
    ratePerTon: 410,
    revenue: 14850.20,
    // A real P&L, not three zeroes and a null. The earnings screen showed
    // "R14,850 / R0 / —" — a revenue, a zero cost and no net, which is a row
    // whose own arithmetic the reader can do and the screen cannot.
    // `list_transporter_trip_pnl` returns all four; the fixture returned one.
    directCost: 4120.00,
    allocatedCost: 1860.50,
    totalCost: 5980.50,
    net: 8869.70,
    status: 'completed',
  ),
  TripEarning(
    tripId: 't-2',
    currency: 'ZAR',
    updatedAt: _ago(const Duration(hours: 2)),
    reference: 'TRP-000124',
    truckReg: 'JD 22 PL MP',
    vehicleId: 'veh-2',
    routeId: 'rt-0042',
    commodity: 'Chrome',
    customerName: 'Atlas Buyer Group',
    sourceName: 'Iron Hills Mining',
    netTons: 34.90,
    ratePerTon: 410,
    revenue: 14309.00,
    directCost: 3980.00,
    allocatedCost: 1792.30,
    totalCost: 5772.30,
    net: 8536.70,
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
    // The parties, the weights and the person who raised it.
    //
    // Without them the card photographed as "— → —", "Variance —" and
    // "By —" — three em-dashes where a mine, a buyer, a figure and a name
    // belong, on the screen whose entire job is to say who disagrees with whom
    // about how much. `ReconDispute` carries all of it; the fixture simply
    // did not fill any of it in, and an honest-looking blank reads as a
    // product fault rather than a missing fixture.
    truckReg: 'CK 84 RT GP',
    sourceName: 'Iron Hills Mining',
    customerName: 'Atlas Buyer Group',
    transporterName: 'Roadhaul Logistics',
    mineNetTons: 36.22,
    deliveredTons: 35.80,
    variance: -0.42,
    raisedByName: 'Thandi Mokoena',
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

/// The TRANSACTIONS behind the trips — what `LogisticsSnapshot.waybills` holds.
///
/// These were `const []` until 2026-08-21, and that emptiness reached further
/// than the screen named after them:
///
///   * the buyer's Waybills screen photographed its empty state;
///   * the buyer's Reconciliations screen filters trips to those whose
///     `transactionId` is in this list, so it rendered ZERO trips — an empty
///     table photographed as though it were the design (CLAUDE.md §10.5);
///   * the mine dashboard's tonnage sparkline sums `netTonsOut` from here, so
///     every one of its windows was a flat zero;
///   * "Routes & Mines" counts this list in its header.
///
/// The ids match `kLogistics.trips` exactly (`txn-1`..`txn-3`), because that
/// join is what every one of those screens does. `txn-4` deliberately has NO
/// route metadata and no order number — the row that renders as em dashes and
/// groups under "— → —", which is what an operator sees before a transaction
/// has been linked to a route.
final List<OperationTransaction> kWaybills = [
  OperationTransaction(
    id: 'txn-1',
    referenceNumber: 'TRP-000121',
    supplierCompanyId: 'co-mine',
    buyerCompanyId: 'co-buyer',
    transporterCompanyId: 'co-transporter',
    status: 'completed',
    quantity: 200,
    netTonsOut: 36.22,
    metadata: const {
      'loading_point': 'Iron Hills Mining',
      'offloading_point': 'Richards Bay',
      'commodity': 'Chrome',
      'order_no': 'PO-88213',
    },
    createdAt: _ago(const Duration(days: 6)),
    updatedAt: _ago(const Duration(days: 1)),
  ),
  OperationTransaction(
    id: 'txn-2',
    referenceNumber: 'TRP-000123',
    supplierCompanyId: 'co-mine',
    buyerCompanyId: 'co-buyer',
    transporterCompanyId: 'co-transporter',
    status: 'in_transit',
    quantity: 200,
    netTonsOut: 34.90,
    metadata: const {
      'loading_point': 'Iron Hills Mining',
      'offloading_point': 'Richards Bay',
      'commodity': 'Chrome',
      'order_no': 'PO-88214',
    },
    createdAt: _ago(const Duration(days: 3)),
    updatedAt: _ago(const Duration(hours: 2)),
  ),
  OperationTransaction(
    id: 'txn-3',
    referenceNumber: 'TRP-000124',
    supplierCompanyId: 'co-mine',
    buyerCompanyId: 'co-buyer-2',
    transporterCompanyId: 'co-transporter',
    status: 'loading',
    quantity: 90,
    netTonsOut: 0,
    metadata: const {
      'loading_point': 'Iron Hills Mining',
      'offloading_point': 'Maputo',
      'commodity': 'Manganese',
      'order_no': 'PO-88301',
    },
    createdAt: _ago(const Duration(days: 2)),
    updatedAt: _ago(const Duration(minutes: 20)),
  ),
  // Nothing filled in yet. Groups under "— → —" and prints em dashes.
  OperationTransaction(
    id: 'txn-4',
    referenceNumber: 'TRP-000125',
    supplierCompanyId: 'co-mine',
    buyerCompanyId: 'co-buyer',
    status: 'draft',
    quantity: 0,
    metadata: const {},
    createdAt: _ago(const Duration(hours: 9)),
    updatedAt: _ago(const Duration(hours: 9)),
  ),
];

/// The newest GPS sample per vehicle — what the three Truck-locations screens
/// and the map draw. Also `const []` until 2026-08-21, so all three of those
/// screens could only ever have photographed "No trucks have GPS coordinates
/// recorded."
///
/// Three trucks, on three legs of the same haul, and deliberately NOT all
/// fresh: `veh-3` last reported nine hours ago, which is the row an operator
/// has to be able to tell apart from the two that reported minutes ago.
final List<VehiclePositionRecord> kPositions = [
  VehiclePositionRecord(
    id: 'pos-1',
    vehicleId: 'veh-1',
    lat: -25.8721,
    lng: 29.2334,
    heading: 118,
    recordedAt: _ago(const Duration(minutes: 4)),
  ),
  VehiclePositionRecord(
    id: 'pos-2',
    vehicleId: 'veh-2',
    lat: -27.4102,
    lng: 31.0455,
    heading: 143,
    recordedAt: _ago(const Duration(minutes: 21)),
  ),
  VehiclePositionRecord(
    id: 'pos-3',
    vehicleId: 'veh-3',
    lat: -28.7802,
    lng: 32.0377,
    recordedAt: _ago(const Duration(hours: 9)),
  ),
];

/// Reconciliation headers on the snapshot. One open, one settled.
final List<ReconciliationRecord> kSnapshotReconciliations = [
  ReconciliationRecord(
    id: 'rec-1',
    buyerCompanyId: 'co-buyer',
    supplierCompanyId: 'co-mine',
    transporterCompanyId: 'co-transporter',
    status: 'open',
    updatedAt: _ago(const Duration(hours: 6)),
  ),
  ReconciliationRecord(
    id: 'rec-2',
    buyerCompanyId: 'co-buyer',
    supplierCompanyId: 'co-mine',
    transporterCompanyId: 'co-transporter',
    status: 'settled',
    updatedAt: _ago(const Duration(days: 4)),
  ),
];

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
  positions: kPositions,
  reconciliations: kSnapshotReconciliations,
  waybills: kWaybills,
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
      // The four super-admin request inboxes, added 2026-08-20. Keyed by
      // request type, so each queue gets its own list rather than all four
      // rendering the same rows.
      adminRequestQueueProvider
          .overrideWith((ref, type) async => switch (type) {
                'product' => kAdminProductRequests,
                'buyer' => kAdminBuyerRequests,
                _ => kAdminTransportRequests,
              }),
      transporterCompaniesProvider
          .overrideWith((ref, _) async => kTransporterCompanies),
      mineCompaniesProvider.overrideWith((ref, _) async => kMineCompanies),
      buyerCompaniesProvider.overrideWith((ref, _) async => kBuyerCompanies),
      requestTrackingProvider.overrideWith((ref, _) async => kRequestTracking),
      // Only the linked request has a transporter on it. A fixture where every
      // row is dispatched cannot show the panel's own empty state.
      requestDispatchedTransportersProvider.overrideWith(
          (ref, requestId) async =>
              requestId == 'areq-4' ? {'co-transporter'} : <String>{}),
      transporterDispatchesProvider.overrideWith((ref, _) async => kDispatches),
      buyerTripValuesProvider.overrideWith((ref, _) async => kBuyerValues),
      tripEarningsProvider.overrideWith((ref, _) async => kTripEarnings),
      reconDisputesProvider.overrideWith((ref, _) async => kDisputes),
      productionReportProvider
          .overrideWith((ref, _) async => kProductionReport),
      logisticsSnapshotProvider.overrideWith((ref, _) async => kLogistics),
      // The reconciliation layer, added 2026-08-20 when the recon screens were
      // photographed for the first time. Without these the whole
      // Reconciliations tab — Side A, Side B, the quality table and the
      // two-version upload pairs — rendered four error cards.
      rawReconRowsProvider.overrideWith((ref, _) async => kRawReconRows),
      tripReconciliationsProvider
          .overrideWith((ref, _) async => kTripReconciliations),
      loadQualityProvider.overrideWith((ref, _) async => kLoadQuality),
      reconUploadPairsProvider
          .overrideWith((ref, _) async => kReconUploadPairs),
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
