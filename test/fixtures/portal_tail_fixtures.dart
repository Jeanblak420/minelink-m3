// Fixtures for the portal screens that had never been photographed.
//
// The companion to `console_tail_fixtures.dart`, and it exists for the same
// reason: `portal_capture_fixtures.dart` covers the providers the dashboards
// and the working-day screens read, and the tail of the portal reads a
// different set — allocated trucks, partner companies, assigned routes, saved
// locations, the stockpile ledger, trip waypoints, compliance documents and
// the fuel/operating-cost ledgers. Un-overridden, every one of those rejects
// against the missing backend and the screen photographs an error card.
//
// Same rule as everywhere else in this directory: **no list is uniform.**
// Every one carries the row a tidy fixture would never have — the truck with
// no driver named, the location with no coordinate, the document that has
// already expired, the cost row for a vehicle that burned nothing. Those are
// the states the design has to survive, and they are the states nobody looks
// at until a picture forces them to.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/mcp/models/company_model.dart';
import 'package:flutter_application_1/core/mcp/repositories/company_repository.dart';
import 'package:flutter_application_1/core/mcp/models/employee_model.dart';
import 'package:flutter_application_1/core/mcp/repositories/employee_repository.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/mcp/repository_providers.dart';
import 'package:flutter_application_1/features/portal/models/available_route.dart';
import 'package:flutter_application_1/features/portal/models/compliance_document.dart';
import 'package:flutter_application_1/features/portal/models/fuel_models.dart';
import 'package:flutter_application_1/features/portal/models/mine_location.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_transaction.dart';
import 'package:flutter_application_1/features/portal/models/tons_out_entry.dart';
import 'package:flutter_application_1/features/portal/models/logistics_models.dart';
import 'package:flutter_application_1/features/portal/models/trip_waypoint.dart';
import 'package:flutter_application_1/features/portal/models/company_location.dart';
import 'package:flutter_application_1/features/portal/models/live_trip_position.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/live_tracking_provider.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/providers/company_location_provider.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/mine_location_provider.dart';
import 'package:flutter_application_1/features/portal/providers/trip_waypoint_provider.dart';
import 'package:flutter_application_1/features/portal/services/compliance_service.dart';
import 'package:flutter_application_1/features/portal/services/fuel_service.dart';
import 'package:flutter_application_1/features/portal/providers/stockpile_ledger_provider.dart'
    show StockpileLedgerState;
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/providers/order_stockpile_provider.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart';

import 'portal_capture_fixtures.dart';
import 'screen_fixtures.dart';

DateTime _ago(Duration d) => kCaptureNow.subtract(d);

// ---------------------------------------------------------------------------
// Allocated trucks — what the transporter committed to a linked request
// ---------------------------------------------------------------------------

/// Only `req-1` is `linked`, so only `req-1` has trucks. The other two return
/// an empty list, which is the section's own "the transporter has not accepted
/// the route" state and has to be in a picture too.
///
/// One row names two drivers and one names none: `drivers` is a joined string
/// off the RPC and is null until a driver is assigned to the truck.
final Map<String, List<AllocatedTruck>> kAllocatedTrucks = {
  'req-1': [
    AllocatedTruck(
      tripId: 't-1',
      truckReg: 'CK 84 RT GP',
      transporterName: 'Roadhaul Logistics',
      drivers: 'S. Nkosi, T. Mokoena',
      tripStatus: 'en_route_to_offload',
      createdAt: _ago(const Duration(days: 2)),
    ),
    AllocatedTruck(
      tripId: 't-2',
      truckReg: 'JD 22 PL MP',
      transporterName: 'Roadhaul Logistics',
      tripStatus: 'loading',
      createdAt: _ago(const Duration(days: 1)),
    ),
  ],
};

// ---------------------------------------------------------------------------
// Partner companies — the buyer's linked mines, the mine's linked buyers
// ---------------------------------------------------------------------------

/// `orgType` here is the WIRE value, exactly as `companies.org_type` stores it
/// — `mineSupplier`, not "Mine/Supplier". That is deliberate: the screen that
/// renders it has to cope with the string the database actually returns.
final List<CompanyPin> kMinePartners = const [
  CompanyPin(id: 'co-mine', name: 'Iron Hills Mining', orgType: 'mineSupplier'),
  CompanyPin(
      id: 'co-mine-2', name: 'Selati Chrome Works', orgType: 'mineSupplier'),
];

final List<CompanyPin> kBuyerPartners = const [
  CompanyPin(id: 'co-buyer', name: 'Atlas Buyer Group', orgType: 'buyer'),
  CompanyPin(id: 'co-buyer-2', name: 'Northvale Alloys', orgType: 'buyer'),
];

final List<CompanyPin> kTransporterPartners = const [
  CompanyPin(
      id: 'co-transporter',
      name: 'Roadhaul Logistics',
      orgType: 'transporter'),
];

// ---------------------------------------------------------------------------
// Available routes — the learned routes an admin assigned to this org
// ---------------------------------------------------------------------------

/// One permanent assignment and one temporary; one 24-hour route and one with
/// real operating hours; one with route notes and one without.
final List<AvailableRoute> kMyAvailableRoutes = [
  AvailableRoute(
    routeId: 'rt-1',
    routeNumber: 'RT-0042',
    commodity: 'Chrome',
    loadingPoint: 'Iron Hills Mining',
    offloadingPoint: 'Richards Bay',
    paymentTerms: '30 days',
    operatingHours24h: true,
    tons: '4000',
    numTrucks: '6',
    routeNotes: 'Weighbridge closes 18:00 on Sundays.',
    permanent: true,
    assignedAt: _ago(const Duration(days: 21)),
  ),
  AvailableRoute(
    routeId: 'rt-2',
    routeNumber: 'RT-0043',
    commodity: 'Manganese',
    loadingPoint: 'Iron Hills Mining',
    offloadingPoint: 'Maputo',
    paymentTerms: 'COD',
    operatingStart: '06:00',
    operatingEnd: '17:30',
    tons: '900',
    numTrucks: '2',
    permanent: false,
    assignedAt: _ago(const Duration(days: 4)),
  ),
];

// ---------------------------------------------------------------------------
// Order fill — the stockpile the mine is building for a linked order
// ---------------------------------------------------------------------------

/// Keyed to `req-1`, the linked request, and matched to `sp-1` in
/// `portal_capture_fixtures.dart` so the buyer's fill line and the mine's
/// supervisor card cannot disagree about the same pile.
final Map<String, OrderStockpileFill> kOrderFills = {
  'req-1': const OrderStockpileFill(
    stockpileId: 'sp-1',
    balanceTons: 128.4,
    maxCapTons: 200,
    mineral: 'Chrome',
  ),
};

// ---------------------------------------------------------------------------
// Company locations — the saved map points a company navigates to
// ---------------------------------------------------------------------------

/// The third has NO coordinate in its link, so `point` is null. That is the
/// row that proves the screen can say "no pin" rather than dropping a marker
/// at (0, 0) in the Gulf of Guinea.
final List<CompanyLocation> kCompanyLocations = const [
  CompanyLocation(
    id: 'loc-1',
    companyId: 'co-mine',
    name: 'Primary collection point',
    mapLink: 'https://www.google.com/maps?q=-25.8721,29.2334',
    isPrimary: true,
  ),
  CompanyLocation(
    id: 'loc-2',
    companyId: 'co-mine',
    name: 'North Pit loading bay',
    mapLink: 'https://www.google.com/maps?q=-25.8809,29.2417',
    isPrimary: false,
  ),
  CompanyLocation(
    id: 'loc-3',
    companyId: 'co-mine',
    name: 'Old weighbridge (address only, no pin yet)',
    mapLink: 'Plot 14, Steelpoort Road, Burgersfort',
    isPrimary: false,
  ),
];

// ---------------------------------------------------------------------------
// Mine anchor points — Main Gate / Weighbridge / Loading Point
// ---------------------------------------------------------------------------

/// Deliberately only TWO of the three anchors, and one of those has no
/// coordinate.
///
/// The screen draws a row per anchor type whether or not a row exists, so a
/// fixture with all three configured photographs only the "CONFIGURED" state
/// and never the "NOT SET" one — which is what a mine sees on the day it signs
/// up, and the state the whole screen exists to get out of. The Loading Point
/// is absent entirely; the Weighbridge exists as a NAME with no pin, which is
/// the halfway state (`hasCoordinates` false) that decides whether
/// `auto_generate_trip_waypoints` can use it.
final List<MineLocation> kMineAnchors = const [
  MineLocation(
    id: 'ml-1',
    mineCompanyId: 'co-mine',
    locationType: MineLocationType.mainGate,
    name: 'Main Gate — R37 entrance',
    address: 'R37, Burgersfort, Limpopo',
    latitude: -25.8721,
    longitude: 29.2334,
  ),
  MineLocation(
    id: 'ml-2',
    mineCompanyId: 'co-mine',
    locationType: MineLocationType.weighbridge,
    name: 'Weighbridge (pin not dropped yet)',
    address: 'Beside the workshop',
  ),
];

// ---------------------------------------------------------------------------
// Stockpile ledger — the audit trail
// ---------------------------------------------------------------------------

/// The append-only history behind the piles in [kStockpiles].
///
/// Newest first, and covering all three transaction types — an allocation, two
/// additions and two deductions — because the screen tones and signs each one
/// differently and a fixture of one type photographs one treatment. One
/// deduction names no truck, which is the shape a load recorded before the
/// plate was captured takes.
final List<StockpileTransaction> kStockpileLedger = [
  StockpileTransaction(
    stockpileId: 'sp-1',
    stockpileName: 'Order pile · Atlas Buyer Group',
    buyer: 'Atlas Buyer Group',
    type: StockpileTxnType.deduction,
    delta: -36.22,
    balanceAfter: 128.4,
    truckReg: 'CK 84 RT GP',
    at: _ago(const Duration(hours: 5)),
  ),
  StockpileTransaction(
    stockpileId: 'sp-1',
    stockpileName: 'Order pile · Atlas Buyer Group',
    buyer: 'Atlas Buyer Group',
    type: StockpileTxnType.addition,
    delta: 64.62,
    balanceAfter: 164.62,
    at: _ago(const Duration(days: 1)),
  ),
  StockpileTransaction(
    stockpileId: 'sp-2',
    stockpileName: 'Order pile · Northvale Alloys',
    buyer: 'Northvale Alloys',
    type: StockpileTxnType.addition,
    delta: 18.0,
    balanceAfter: 18.0,
    at: _ago(const Duration(days: 2)),
  ),
  StockpileTransaction(
    stockpileId: 'sp-1',
    stockpileName: 'Order pile · Atlas Buyer Group',
    buyer: 'Atlas Buyer Group',
    type: StockpileTxnType.deduction,
    delta: -34.90,
    balanceAfter: 100.0,
    at: _ago(const Duration(days: 3)),
  ),
  StockpileTransaction(
    stockpileId: 'sp-1',
    stockpileName: 'Order pile · Atlas Buyer Group',
    buyer: 'Atlas Buyer Group',
    type: StockpileTxnType.allocation,
    delta: 134.9,
    balanceAfter: 134.9,
    at: _ago(const Duration(days: 6)),
  ),
];

final StockpileLedgerState kStockpileLedgerState = StockpileLedgerState(
  stockpiles: kStockpiles,
  transactions: kStockpileLedger,
);

// ---------------------------------------------------------------------------
// Tons out — the dispatch register the drill-down filters
// ---------------------------------------------------------------------------

/// Six loads over three days, two transporters, two products, two customers.
///
/// The screen's filters are by transporter, product, customer, date and a mass
/// RANGE, and every one of those needs at least two distinct values to do
/// anything at all. The last row has **no delivered weight and therefore no
/// variance**, which the model's own comment insists is not a measured zero:
/// the truck is loaded and gone and no POD has landed.
final List<TonsOutEntry> kTonsOut = [
  TonsOutEntry(
    date: DateTime.utc(2026, 8, 15),
    time: '06:12',
    transporter: 'Roadhaul Logistics',
    truckReg: 'CK 84 RT GP',
    destination: 'Richards Bay',
    product: 'Chrome',
    customer: 'Atlas Buyer Group',
    netMass: 36.22,
    waybillNumber: 'TRP-000121',
    source: 'Iron Hills Mining',
    deliveredTons: 36.10,
    varianceTons: 0.12,
    tripId: 't-1',
  ),
  TonsOutEntry(
    date: DateTime.utc(2026, 8, 15),
    time: '09:41',
    transporter: 'Roadhaul Logistics',
    truckReg: 'JD 22 PL MP',
    destination: 'Richards Bay',
    product: 'Chrome',
    customer: 'Atlas Buyer Group',
    netMass: 34.90,
    waybillNumber: 'TRP-000123',
    source: 'Iron Hills Mining',
    deliveredTons: 34.48,
    varianceTons: 0.42,
    tripId: 't-2',
  ),
  TonsOutEntry(
    date: DateTime.utc(2026, 8, 14),
    time: '14:05',
    transporter: 'Summit Carriers',
    truckReg: 'BX 09 LM NW',
    destination: 'Maputo',
    product: 'Manganese',
    customer: 'Northvale Alloys',
    netMass: 31.08,
    waybillNumber: 'TRP-000118',
    source: 'Iron Hills Mining',
    deliveredTons: 31.08,
    varianceTons: 0,
    tripId: 't-3',
  ),
  TonsOutEntry(
    date: DateTime.utc(2026, 8, 14),
    time: '07:33',
    transporter: 'Summit Carriers',
    truckReg: 'TN 55 QQ GP',
    destination: 'Maputo',
    product: 'Manganese',
    customer: 'Northvale Alloys',
    netMass: 29.74,
    waybillNumber: 'TRP-000117',
    source: 'Iron Hills Mining',
    deliveredTons: 28.90,
    varianceTons: 0.84,
  ),
  TonsOutEntry(
    date: DateTime.utc(2026, 8, 13),
    time: '11:20',
    transporter: 'Roadhaul Logistics',
    truckReg: 'CK 84 RT GP',
    destination: 'Richards Bay',
    product: 'Chrome',
    customer: 'Atlas Buyer Group',
    netMass: 35.61,
    waybillNumber: 'TRP-000114',
    source: 'Iron Hills Mining',
    deliveredTons: 35.61,
    varianceTons: 0,
  ),
  // Loaded and gone; no POD yet, so no delivered weight and no variance.
  TonsOutEntry(
    date: DateTime.utc(2026, 8, 13),
    time: '05:58',
    transporter: 'Summit Carriers',
    truckReg: 'BX 09 LM NW',
    destination: 'Maputo',
    product: 'Manganese',
    customer: 'Northvale Alloys',
    netMass: 30.15,
    waybillNumber: 'TRP-000112',
    source: 'Iron Hills Mining',
  ),
];

// ---------------------------------------------------------------------------
// Trip waypoints — the mine-nav sequence, and the drop-off at the end of it
// ---------------------------------------------------------------------------

/// The `auto_generate_trip_waypoints` sequence for `t-2`: MG → WB → LP → WB →
/// MG → drop-off, 1..6.
///
/// The first four are completed and the last two are not, so the screen shows
/// both states; the DROP-OFF has no coordinate at all, which is the state the
/// drop-off screen exists to get out of and the only one worth photographing
/// it in.
final List<TripWaypoint> kTripWaypoints = [
  TripWaypoint(
    id: 'wp-1',
    tripId: 't-2',
    sequenceOrder: 1,
    locationType: WaypointType.mainGate,
    name: 'Main Gate — R37 entrance',
    latitude: -25.8721,
    longitude: 29.2334,
    address: 'R37, Burgersfort, Limpopo',
    isCompleted: true,
    completedAt: _ago(const Duration(hours: 7)),
  ),
  TripWaypoint(
    id: 'wp-2',
    tripId: 't-2',
    sequenceOrder: 2,
    locationType: WaypointType.weighbridge,
    name: 'Weighbridge (tare)',
    latitude: -25.8750,
    longitude: 29.2361,
    isCompleted: true,
    completedAt: _ago(const Duration(hours: 6, minutes: 40)),
  ),
  TripWaypoint(
    id: 'wp-3',
    tripId: 't-2',
    sequenceOrder: 3,
    locationType: WaypointType.loadingPoint,
    name: 'North Pit loading bay',
    latitude: -25.8809,
    longitude: 29.2417,
    isCompleted: true,
    completedAt: _ago(const Duration(hours: 5, minutes: 30)),
  ),
  TripWaypoint(
    id: 'wp-4',
    tripId: 't-2',
    sequenceOrder: 4,
    locationType: WaypointType.weighbridge,
    name: 'Weighbridge (gross)',
    latitude: -25.8750,
    longitude: 29.2361,
    isCompleted: true,
    completedAt: _ago(const Duration(hours: 5)),
  ),
  TripWaypoint(
    id: 'wp-5',
    tripId: 't-2',
    sequenceOrder: 5,
    locationType: WaypointType.mainGate,
    name: 'Main Gate — R37 entrance',
    latitude: -25.8721,
    longitude: 29.2334,
  ),
  // No coordinate: `hasCoordinates` false, and the transporter has to set it.
  TripWaypoint(
    id: 'wp-6',
    tripId: 't-2',
    sequenceOrder: 6,
    locationType: WaypointType.dropOff,
    name: 'Drop-off',
    address: 'Richards Bay — bay not confirmed',
  ),
];

// ---------------------------------------------------------------------------
// Compliance — the documents a transporter is chased for
// ---------------------------------------------------------------------------

/// One of each STATUS, because the screen is a traffic light and a fixture in
/// one colour photographs one colour: expired, expiring, valid, and one with
/// no expiry date at all. One of each OWNER TYPE too — a vehicle, a driver and
/// the company — because the list groups by owner.
final List<ComplianceDocument> kComplianceDocs = [
  ComplianceDocument(
    id: 'cd-1',
    companyId: 'FIXTURE-company',
    ownerType: ComplianceOwnerType.vehicle,
    ownerId: 'veh-1',
    ownerName: 'CK 84 RT GP',
    docType: 'license_disc',
    docNumber: 'LD-4471902',
    issuedAt: _ago(const Duration(days: 380)),
    expiresAt: _ago(const Duration(days: 12)),
    daysToExpiry: -12,
    status: ComplianceStatus.expired,
    createdAt: _ago(const Duration(days: 380)),
    updatedAt: _ago(const Duration(days: 12)),
  ),
  ComplianceDocument(
    id: 'cd-2',
    companyId: 'FIXTURE-company',
    ownerType: ComplianceOwnerType.employee,
    ownerId: 'emp-1',
    ownerName: 'S. Nkosi',
    docType: 'prdp',
    title: 'Professional driving permit',
    docNumber: 'PRDP-882301',
    issuedAt: _ago(const Duration(days: 700)),
    expiresAt: kCaptureNow.add(const Duration(days: 19)),
    daysToExpiry: 19,
    status: ComplianceStatus.expiring,
    createdAt: _ago(const Duration(days: 700)),
    updatedAt: _ago(const Duration(days: 30)),
  ),
  ComplianceDocument(
    id: 'cd-3',
    companyId: 'FIXTURE-company',
    ownerType: ComplianceOwnerType.company,
    ownerId: 'FIXTURE-company',
    ownerName: 'Fixture Haulage',
    docType: 'git_insurance',
    docNumber: 'GIT-2026-114',
    issuedAt: _ago(const Duration(days: 60)),
    expiresAt: kCaptureNow.add(const Duration(days: 305)),
    daysToExpiry: 305,
    filePath: 'FIXTURE-company/compliance/git-2026.pdf',
    status: ComplianceStatus.valid,
    createdAt: _ago(const Duration(days: 60)),
    updatedAt: _ago(const Duration(days: 60)),
  ),
  // No expiry at all — a permanent record. Renders differently from a real
  // "expires in 0 days", and that difference is the point.
  ComplianceDocument(
    id: 'cd-4',
    companyId: 'FIXTURE-company',
    ownerType: ComplianceOwnerType.company,
    ownerId: 'FIXTURE-company',
    ownerName: 'Fixture Haulage',
    docType: 'company_registration',
    docNumber: '2019/442190/07',
    issuedAt: _ago(const Duration(days: 2100)),
    status: ComplianceStatus.noExpiry,
    createdAt: _ago(const Duration(days: 2100)),
    updatedAt: _ago(const Duration(days: 2100)),
  ),
];

// ---------------------------------------------------------------------------
// Fuel and operating costs
// ---------------------------------------------------------------------------

/// Five fills across three trucks. One has NO odometer and no station, which
/// is what a fill captured in a hurry at a roadside pump looks like — and the
/// row whose litres-per-100km cannot be computed.
final List<FuelEntry> kFuelEntries = [
  FuelEntry(
    id: 'fu-1',
    vehicleId: 'veh-1',
    reg: 'CK 84 RT GP',
    tripId: 't-1',
    litres: 412.5,
    costZar: 9487.50,
    odometerKm: 418302,
    station: 'Engen Ultra City, Middelburg',
    filledAt: _ago(const Duration(days: 1, hours: 3)),
  ),
  FuelEntry(
    id: 'fu-2',
    vehicleId: 'veh-2',
    reg: 'JD 22 PL MP',
    tripId: 't-2',
    litres: 388.0,
    costZar: 8924.00,
    odometerKm: 302114,
    station: 'Shell, Steelpoort',
    filledAt: _ago(const Duration(days: 2, hours: 5)),
  ),
  FuelEntry(
    id: 'fu-3',
    vehicleId: 'veh-3',
    reg: 'BX 09 LM NW',
    litres: 205.0,
    costZar: 4715.00,
    filledAt: _ago(const Duration(days: 4)),
  ),
  FuelEntry(
    id: 'fu-4',
    vehicleId: 'veh-1',
    reg: 'CK 84 RT GP',
    litres: 401.2,
    costZar: 9227.60,
    odometerKm: 417120,
    station: 'Engen Ultra City, Middelburg',
    filledAt: _ago(const Duration(days: 6)),
  ),
  FuelEntry(
    id: 'fu-5',
    vehicleId: 'veh-2',
    reg: 'JD 22 PL MP',
    litres: 372.4,
    costZar: 8565.20,
    odometerKm: 300880,
    station: 'Sasol, Burgersfort',
    filledAt: _ago(const Duration(days: 8)),
  ),
];

/// One of every kind, including a fine — the row nobody puts in a demo.
final List<OperatingCost> kOperatingCosts = [
  OperatingCost(
    id: 'oc-1',
    vehicleId: 'veh-1',
    reg: 'CK 84 RT GP',
    kind: OperatingCostKind.tyre,
    costZar: 14200,
    incurredAt: _ago(const Duration(days: 3)),
    description: 'Two steer tyres',
  ),
  OperatingCost(
    id: 'oc-2',
    vehicleId: 'veh-2',
    reg: 'JD 22 PL MP',
    kind: OperatingCostKind.toll,
    costZar: 812.50,
    incurredAt: _ago(const Duration(days: 2)),
    description: 'N4 Middelburg – Emalahleni',
  ),
  OperatingCost(
    id: 'oc-3',
    vehicleId: 'veh-3',
    reg: 'BX 09 LM NW',
    kind: OperatingCostKind.fine,
    costZar: 1500,
    incurredAt: _ago(const Duration(days: 9)),
    description: 'Overload — 1.2 t on the drive axle',
  ),
  OperatingCost(
    id: 'oc-4',
    vehicleId: 'veh-1',
    reg: 'CK 84 RT GP',
    kind: OperatingCostKind.cleaning,
    costZar: 350,
    incurredAt: _ago(const Duration(days: 5)),
  ),
];

/// The per-vehicle rollup. `veh-4` is in maintenance and has burned nothing —
/// the row whose cost-per-km cannot be computed, and which must not read as a
/// zero-rand truck.
final List<VehicleCostBreakdown> kVehicleCosts = const [
  VehicleCostBreakdown(
    vehicleId: 'veh-1',
    reg: 'CK 84 RT GP',
    maintenanceCost: 8400,
    fuelCost: 18715.10,
    fuelLitres: 813.7,
    tyreCost: 14200,
    tollCost: 0,
    otherCost: 350,
    distanceKm: 2410,
    lPer100km: 33.8,
    costPerKm: 17.29,
  ),
  VehicleCostBreakdown(
    vehicleId: 'veh-2',
    reg: 'JD 22 PL MP',
    maintenanceCost: 0,
    fuelCost: 17489.20,
    fuelLitres: 760.4,
    tyreCost: 0,
    tollCost: 812.50,
    otherCost: 0,
    distanceKm: 2234,
    lPer100km: 34.0,
    costPerKm: 8.19,
  ),
  VehicleCostBreakdown(
    vehicleId: 'veh-3',
    reg: 'BX 09 LM NW',
    maintenanceCost: 2600,
    fuelCost: 4715,
    fuelLitres: 205,
    tyreCost: 0,
    tollCost: 0,
    otherCost: 1500,
    distanceKm: 612,
    lPer100km: 33.5,
    costPerKm: 14.08,
  ),
  VehicleCostBreakdown(
    vehicleId: 'veh-4',
    reg: 'TN 55 QQ GP',
    maintenanceCost: 21400,
    fuelCost: 0,
    fuelLitres: 0,
    tyreCost: 0,
    tollCost: 0,
    otherCost: 0,
  ),
];

// ---------------------------------------------------------------------------
// The company profile — read through a REPOSITORY, not a provider
// ---------------------------------------------------------------------------

/// `CompanyDetailsLoaderScreen` calls `repository.getById()` inside a
/// `FutureBuilder` rather than watching an overridable data provider, so
/// nothing in `companyScopeOverrides()` reaches it. Un-faked it photographed
///
///     Failed to load company:
///     PostgrestException(message: , code: 400, details: , hint: null)
///
/// under a "Company" app bar — an error card standing in for the design, which
/// is the one thing CLAUDE.md §10.5 says a render must never be.
///
/// The seam is the repository provider. Subclassing rather than implementing
/// an interface, because `SupabaseRepository` has a wide surface and this
/// screen calls exactly one method of it.
class FixtureCompanyRepository extends CompanyRepository {
  FixtureCompanyRepository(this.company, {this.registry = const []});

  final CompanyMCP company;

  /// What `/companies/:orgType` pages through. Empty by default so the screens
  /// that only resolve ONE company keep the behaviour they had.
  final List<CompanyMCP> registry;

  @override
  Future<CompanyMCP> getById(String id) async =>
      registry.where((c) => c.id == id).firstOrNull ?? company;

  /// `InfiniteList` asks for a page at a time and stops when a page comes back
  /// SHORTER than the page size. Honouring `offset`/`limit` is therefore not
  /// politeness — a fixture that returns the whole list for every page never
  /// terminates, and the screen renders the same companies over and over.
  @override
  Future<List<CompanyMCP>> getByOrgType(
    String orgType, {
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    final matching =
        registry.where((c) => c.orgType.name == orgType).toList()
          ..sort((a, b) => ascending
              ? a.companyName.compareTo(b.companyName)
              : b.companyName.compareTo(a.companyName));
    final start = (offset ?? 0).clamp(0, matching.length);
    final end =
        limit == null ? matching.length : (start + limit).clamp(0, matching.length);
    return matching.sublist(start, end);
  }
}

/// The employee half of the same seam.
///
/// `EmployeeGridScreen` reads `employeeRepositoryProvider` and nothing else,
/// so without this it photographs `InfiniteGrid`'s error state.
class FixtureEmployeeRepository extends EmployeeRepository {
  FixtureEmployeeRepository(this.roster);

  final List<EmployeeMCP> roster;

  @override
  Future<EmployeeMCP> getById(String id) async =>
      roster.firstWhere((e) => e.id == id, orElse: () => roster.first);

  @override
  Future<List<EmployeeMCP>> getByCompanyId(
    String companyId, {
    String? orderBy,
    bool ascending = true,
    int? limit,
    int? offset,
  }) async {
    final matching = roster
        .where((e) => e.companyId == null || e.companyId == companyId)
        .toList()
      ..sort((a, b) => ascending
          ? a.firstName.compareTo(b.firstName)
          : b.firstName.compareTo(a.firstName));
    final start = (offset ?? 0).clamp(0, matching.length);
    final end = limit == null
        ? matching.length
        : (start + limit).clamp(0, matching.length);
    return matching.sublist(start, end);
  }
}

/// The platform's transporter registry, as `/companies/transporter` lists it.
///
/// Deliberately NOT uniform: one company has no CEO recorded, one has no
/// reference (it predates the column), one carries a name long enough to need
/// the row to decide what to do about it, and the WhatsApp numbers are not all
/// the same length. Those are the rows a tidy fixture never has.
List<CompanyMCP> kCompanyRegistry = [
  CompanyMCP(
    id: 'co-transporter',
    userId: 'u-co-1',
    companyName: 'Fixture Haulage',
    whatsappNumber: '+27 82 000 0001',
    orgType: OrgType.transporter,
    createdAt: _ago(const Duration(days: 420)),
    updatedAt: _ago(const Duration(days: 9)),
    ceoFirstName: 'Thandi',
    ceoLastName: 'Mokoena',
    regRef: 'FXH001',
  ),
  CompanyMCP(
    id: 'co-roadhaul',
    userId: 'u-co-2',
    companyName: 'Roadhaul Logistics',
    whatsappNumber: '+27 83 000 0002',
    orgType: OrgType.transporter,
    createdAt: _ago(const Duration(days: 310)),
    updatedAt: _ago(const Duration(days: 2)),
    ceoFirstName: 'Sipho',
    ceoLastName: 'Ndlovu',
    regRef: 'RHL014',
  ),
  CompanyMCP(
    id: 'co-longname',
    userId: 'u-co-3',
    companyName: 'Highveld Bulk Commodity Carriers & Logistics',
    whatsappNumber: '+27 71 555 0134',
    orgType: OrgType.transporter,
    createdAt: _ago(const Duration(days: 96)),
    regRef: 'HBC207',
  ),
  CompanyMCP(
    id: 'co-nocdetails',
    userId: 'u-co-4',
    companyName: 'Kalahari Freight',
    whatsappNumber: '+27 60 12 3456',
    orgType: OrgType.transporter,
    createdAt: _ago(const Duration(days: 41)),
  ),
];

/// The roster `/employees/:companyId` grids.
///
/// One of everything the card has to survive: a role it has no tone for, no
/// role at all, a name long enough to ellipsis, and a photo URL that will
/// never resolve in a test (which is the state a real broken image is in).
List<EmployeeMCP> kCompanyRoster = [
  EmployeeMCP(
    id: 'emp-1',
    userId: 'u-emp-1',
    firstName: 'Thandi',
    lastName: 'Mokoena',
    whatsappNumber: '+27 82 000 0001',
    companyId: 'co-transporter',
    role: UserRole.admin,
    status: 'active',
    createdAt: _ago(const Duration(days: 400)),
  ),
  EmployeeMCP(
    id: 'emp-2',
    userId: 'u-emp-2',
    firstName: 'Bongani',
    lastName: 'Khumalo',
    whatsappNumber: '+27 83 000 0002',
    companyId: 'co-transporter',
    role: UserRole.driver,
    status: 'active',
    createdAt: _ago(const Duration(days: 220)),
  ),
  EmployeeMCP(
    id: 'emp-3',
    userId: 'u-emp-3',
    firstName: 'Annelize',
    lastName: 'van der Merwe-Botha',
    whatsappNumber: '+27 71 555 0134',
    companyId: 'co-transporter',
    role: UserRole.management,
    status: 'active',
    createdAt: _ago(const Duration(days: 150)),
  ),
  EmployeeMCP(
    id: 'emp-4',
    userId: 'u-emp-4',
    firstName: 'Pieter',
    lastName: 'Nel',
    whatsappNumber: '+27 60 12 3456',
    companyId: 'co-transporter',
    status: 'pending',
    createdAt: _ago(const Duration(days: 3)),
  ),
];

CompanyMCP fixtureCompanyRecord({OrgType orgType = OrgType.transporter}) {
  final base = fixtureCompany(orgType: orgType);
  return CompanyMCP(
    id: base.id,
    userId: base.userId,
    companyName: base.companyName,
    whatsappNumber: base.whatsappNumber,
    orgType: base.orgType,
    createdAt: base.createdAt,
    updatedAt: _ago(const Duration(days: 9)),
    ceoFirstName: 'Thandi',
    ceoLastName: 'Mokoena',
    regRef: 'FXH001',
  );
}

// ---------------------------------------------------------------------------
// The live map, from ONE company's side
// ---------------------------------------------------------------------------

/// The portal's own live feed — the fixture company's own two trucks, on the
/// two routes `kLogistics` describes.
///
/// Deliberately NOT `kLivePositions` from `console_tail_fixtures.dart`: that
/// list is the platform's view of every transporter on the network, which is
/// exactly the data a portal render must never show. A mine looking at its own
/// live map sees its own trucks.
///
/// One moving and one standing still, because a map where everything is moving
/// cannot show the state anybody opens a live map to find.
final List<LiveTripPosition> kPortalLivePositions = [
  LiveTripPosition(
    tripId: 't-2',
    status: TripStatus.enRouteToOffload,
    vehicleId: 'veh-2',
    truckReg: 'JD 22 PL MP',
    transporterName: 'Fixture Haulage',
    supplierName: 'Iron Hills Mining',
    buyerName: 'Atlas Buyer Group',
    loadingPoint: 'Iron Hills Mining, Steelpoort',
    offloadingPoint: 'Richards Bay Dry Bulk Terminal',
    lat: -25.9,
    lng: 30.68,
    heading: 118,
    speedKmh: 74.2,
    recordedAt: _ago(const Duration(seconds: 40)),
    driverName: 'Bongani Khumalo',
    driverPhone: '+27 83 000 0002',
    tripCreatedAt: _ago(const Duration(hours: 9)),
    arrivedAt: _ago(const Duration(hours: 8)),
    loadedAt: _ago(const Duration(hours: 6)),
    leftAt: _ago(const Duration(hours: 5, minutes: 40)),
    navInstruction: 'In 1.2 km — Turn left onto the N4 towards Komatipoort',
    navTimeLeftS: 4 * 60 * 60 + 600,
    navDistanceLeftM: 318000,
    navSpeedKmh: 74.2,
    navUpdatedAt: _ago(const Duration(seconds: 40)),
  ),
  LiveTripPosition(
    tripId: 't-3',
    status: TripStatus.loading,
    vehicleId: 'veh-3',
    truckReg: 'BX 09 LM NW',
    transporterName: 'Fixture Haulage',
    supplierName: 'Iron Hills Mining',
    buyerName: 'Northvale Alloys',
    loadingPoint: 'Iron Hills Mining, Steelpoort',
    offloadingPoint: 'Maputo Port',
    lat: -24.71,
    lng: 30.19,
    heading: 74,
    speedKmh: 0,
    recordedAt: _ago(const Duration(minutes: 2)),
    stationarySince: _ago(const Duration(minutes: 38)),
    driverName: 'Pieter Nel',
    driverPhone: '+27 60 12 3456',
    tripCreatedAt: _ago(const Duration(hours: 3)),
    arrivedAt: _ago(const Duration(hours: 1)),
  ),
];

// ---------------------------------------------------------------------------
// A driver who has actually delivered something this week
// ---------------------------------------------------------------------------

/// The fixture driver holds ONE trip (`t-2`, en route) and no completed one,
/// which is honest and is what the driver dashboard photographs — but it means
/// the "Tons delivered · This week" chart's populated state is never drawn by
/// anything. Two completed trips on the driver's own truck, three and five
/// days back, so the bars land on two different weekdays and the today column
/// is not one of them.
///
/// Deliberately an OVERRIDE rather than a change to `kLogistics`: adding
/// completed trips to the shared snapshot would move the tonnage on the recon
/// tables, the dashboards and the earnings screens, all to photograph one card.
List<Override> driverDeliveredWeekOverride() => [
      logisticsSnapshotProvider.overrideWith((ref, _) async {
        final base = kLogistics;
        return LogisticsSnapshot(
          routes: base.routes,
          positions: base.positions,
          reconciliations: base.reconciliations,
          waybills: base.waybills,
          trips: [
            ...base.trips,
            TripRecord(
              id: 't-week-1',
              transactionId: 'txn-1',
              dispatchId: 'dsp-1',
              vehicleId: 'veh-2',
              routeId: 'rt-1',
              status: 'completed',
              netTons: 34.10,
              truckReg: 'JD 22 PL MP',
              updatedAt: _ago(const Duration(days: 3)),
            ),
            TripRecord(
              id: 't-week-2',
              transactionId: 'txn-1',
              dispatchId: 'dsp-1',
              vehicleId: 'veh-2',
              routeId: 'rt-1',
              status: 'completed',
              netTons: 28.75,
              truckReg: 'JD 22 PL MP',
              updatedAt: _ago(const Duration(days: 5)),
            ),
          ],
        );
      }),
    ];

// ---------------------------------------------------------------------------
// The override list
// ---------------------------------------------------------------------------

/// Install alongside [portalCaptureOverrides] — this list adds to it rather
/// than replacing anything in it.
List<Override> portalTailOverrides() => [
      allocatedTrucksProvider.overrideWith(
          (ref, requestId) async => kAllocatedTrucks[requestId] ?? const []),
      // CASE-INSENSITIVE, like the service it stands in for
      // (`listPartnerCompanies` lowercases both sides). It matched exactly,
      // and the mine's Buyers screen asked for `'Buyer'` — so the fixture fell
      // through its default and handed a mine's BUYERS page a list of MINES.
      // The picture showed Iron Hills Mining and Selati Chrome Works as this
      // mine's customers, which is not a layout anybody would look at twice.
      partnerCompaniesProvider.overrideWith((ref, args) async =>
          switch (args.orgFilter.toLowerCase()) {
            'buyer' => kBuyerPartners,
            'transporter' => kTransporterPartners,
            _ => kMinePartners,
          }),
      myAvailableRoutesProvider
          .overrideWith((ref, _) async => kMyAvailableRoutes),
      orderStockpileProvider
          .overrideWith((ref, requestId) async => kOrderFills[requestId]),
      companyLocationsProvider
          .overrideWith((ref, _) async => kCompanyLocations),
      mineLocationsProvider.overrideWith((ref, _) async => kMineAnchors),
      stockpileLedgerDbProvider
          .overrideWith((ref, _) async => kStockpileLedgerState),
      tripWaypointsProvider.overrideWith((ref, _) async => kTripWaypoints),
      complianceDocumentsProvider
          .overrideWith((ref, _) async => kComplianceDocs),
      fuelEntriesProvider.overrideWith((ref, _) async => kFuelEntries),
      operatingCostsProvider
          .overrideWith((ref, _) async => kOperatingCosts),
      vehicleCostBreakdownProvider
          .overrideWith((ref, _) async => kVehicleCosts),
      companyRepositoryProvider.overrideWithValue(
        FixtureCompanyRepository(
          fixtureCompanyRecord(),
          registry: kCompanyRegistry,
        ),
      ),
      employeeRepositoryProvider
          .overrideWithValue(FixtureEmployeeRepository(kCompanyRoster)),
      // A StreamProvider over Supabase realtime. Left alone it does not merely
      // render an empty map — its subscription outlives the widget tree and
      // throws from `runOnDispose` AFTER the harness has restored
      // `FlutterError.onError`, so the test fails with the capture already on
      // disk. It is also order-dependent, which is why the portal live map
      // passed on its own and failed inside the suite.
      liveTripPositionsProvider
          .overrideWith((ref, _) => Stream.value(kPortalLivePositions)),
    ];
