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

import 'package:flutter_application_1/features/portal/models/available_route.dart';
import 'package:flutter_application_1/features/portal/models/company_location.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/providers/company_location_provider.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/providers/order_stockpile_provider.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart';

import 'portal_capture_fixtures.dart';

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
// The override list
// ---------------------------------------------------------------------------

/// Install alongside [portalCaptureOverrides] — this list adds to it rather
/// than replacing anything in it.
List<Override> portalTailOverrides() => [
      allocatedTrucksProvider.overrideWith(
          (ref, requestId) async => kAllocatedTrucks[requestId] ?? const []),
      partnerCompaniesProvider.overrideWith((ref, args) async =>
          switch (args.orgFilter) {
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
    ];
