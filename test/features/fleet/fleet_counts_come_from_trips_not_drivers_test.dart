// "Available" is the number a transporter allocates from. It was inverted.
//
// Driving the live app as roadhaul.owner on 2026-08-22, three screens
// described the same three trucks at the same moment and did not agree:
//
//     dashboard          2 trucks on route of 3 · 67% utilisation
//     Trucks On Route    On Route 2 · Available 1 · Fleet total 3
//     Fleet Management   On Trip / Assigned 1 · Available 2      <- wrong
//
// The database settles it — two vehicles hold a trip that is neither completed
// nor cancelled:
//
//     reg        driver rostered   active trips
//     fa243ad    no                1  (en_route_to_offload)
//     KVK007MP   no                1  (en_route_to_offload)
//     S6W001GP   yes               0
//
// So it was not merely a wrong total: EVERY VEHICLE WAS IN THE WRONG BUCKET.
// `FleetState.assignedVehicles` filters on `hasAssignedDriver`, and the card
// above it is labelled "On Trip". The two trucks actually carrying loads to
// Johannesburg have no driver row, so they were reported as **Available to
// allocate**; the one truck standing still had a driver, so it was reported as
// on a trip.
//
// Driver rostering and route availability are different questions, and
// `accept_request_dispatch` proves it: it refuses a truck that is inactive,
// already on a route, or in maintenance — and does NOT require a driver. A
// truck can run a whole trip with nobody recorded on it, which is exactly the
// state these two were in.
//
// CLAUDE.md §4 has said all along that the Available ↔ On-Route machine is
// DERIVED from active trips, and `list_transporter_fleet_status` already
// computes it server-side. Two of the three screens were reading it. This
// makes the third read it too, so they agree by construction.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';

/// Roadhaul exactly as production held it when this was found.
final _roadhaul = <FleetVehicleStatus>[
  const FleetVehicleStatus(
    vehicleId: 'v1',
    registration: 'fa243ad',
    isActive: true,
    onRoute: true, // carrying a load…
    drivers: null, // …with nobody rostered on it
  ),
  const FleetVehicleStatus(
    vehicleId: 'v2',
    registration: 'KVK007MP',
    isActive: true,
    onRoute: true,
    drivers: null,
  ),
  const FleetVehicleStatus(
    vehicleId: 'v3',
    registration: 'S6W001GP',
    isActive: true,
    onRoute: false, // standing still…
    drivers: 'Sipho Ndlovu', // …with a driver rostered
  ),
];

int _onRoute(List<FleetVehicleStatus> v) => v.where((x) => x.onRoute).length;
int _available(List<FleetVehicleStatus> v) =>
    v.where((x) => x.available).length;

void main() {
  test('the live fleet: on-route and available follow the TRIPS', () {
    expect(
      _onRoute(_roadhaul),
      2,
      reason: 'two trucks are en_route_to_offload',
    );
    expect(
      _available(_roadhaul),
      1,
      reason: 'one truck is free — the one that is standing still',
    );
  });

  test('the driver-rostering answer is the OPPOSITE, which is the bug', () {
    // Reproduced here so the test states what the old code computed rather
    // than only what the new code should. These two numbers are the ones the
    // Fleet Management screen was showing.
    final byDriver = _roadhaul.where((v) => v.hasDriver).length;
    final byNoDriver = _roadhaul.where((v) => !v.hasDriver).length;

    expect(byDriver, 1);
    expect(byNoDriver, 2);
    expect(
      byDriver,
      isNot(_onRoute(_roadhaul)),
      reason: 'rostering and route state are different questions',
    );
    expect(
      byNoDriver,
      isNot(_available(_roadhaul)),
      reason: 'and on this fleet they are exactly inverted',
    );
  });

  test('a truck in maintenance is not available, and not on route either', () {
    final fleet = [
      ..._roadhaul,
      const FleetVehicleStatus(
        vehicleId: 'v4',
        registration: 'BX09LMNW',
        isActive: true,
        onRoute: false,
        inMaintenance: true,
        drivers: 'Thabo Dlamini',
      ),
    ];

    expect(_onRoute(fleet), 2);
    expect(
      _available(fleet),
      1,
      reason: 'the maintenance truck must not be offered for allocation',
    );

    // And the four buckets still account for every vehicle — which is why the
    // Available card names the maintenance exclusion in its caption. Without
    // that, 4 total against 2 + 1 + 0 is an unexplained gap.
    final inMaintenance = fleet.where((v) => v.inMaintenance).length;
    final inactive = fleet.where((v) => !v.isActive).length;
    expect(
      _onRoute(fleet) + _available(fleet) + inMaintenance + inactive,
      fleet.length,
    );
  });

  test('an inactive truck is never available, whatever its driver', () {
    final fleet = [
      const FleetVehicleStatus(
        vehicleId: 'v5',
        registration: 'OLD1GP',
        isActive: false,
        onRoute: false,
        drivers: 'Someone',
      ),
    ];
    expect(_available(fleet), 0);
  });

  test('the screen reads the derived provider, not the driver flags', () {
    // The counts above are pure. This is the half that regressed: WHICH source
    // the screen asks. Comments stripped first — the note left at the call
    // site names both `fleetStatusProvider` and `hasAssignedDriver`, and would
    // otherwise satisfy the search on its own.
    final source =
        File('lib/features/fleet/screens/fleet_management_screen.dart')
            .readAsStringSync()
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');

    expect(
      source,
      contains('fleetStatusProvider'),
      reason: 'availability is derived server-side from active trips',
    );
    expect(
      source,
      isNot(contains('assignedVehicles')),
      reason: 'that getter is driver rostering, under an On-Trip label',
    );
    expect(
      source,
      isNot(contains('unassignedVehicles')),
      reason: 'and this one was labelled Available',
    );
  });
}
