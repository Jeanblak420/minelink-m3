// Three fixtures describe the same four trucks, and until 2026-08-23 they gave
// two different answers about which of them was on route.
//
// `kFleetStatus` said `veh-1` was on route while its only trip (`t-1`) is
// **completed** and its own driver assignment (`va-2`) says `onRoute: false`;
// it said `veh-2` was NOT on route while `t-2` is **en route to offload** and
// `va-1` says `onRoute: true`. Whichever a screen happened to read is what it
// drew, and the transporter portal reads all three.
//
// It also set only the legacy `driverName`, never `drivers` — and
// `driversLabel`/`hasDriver` read `drivers` alone — so
// `screen-trucks-on-route-phone-dark` photographed an on-route truck as
// "No driver assigned", under a warning panel offering to assign one, while
// three fixtures next to it named its driver.
//
// This is not a test of the app. It is a test of the fixtures the pictures are
// made from, which is the only place a lie of this shape can be caught: every
// screen rendered *consistently* with the fixture it read.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/trip_status.dart';

import 'portal_capture_fixtures.dart';

void main() {
  // The server's own rule (CLAUDE.md §4): a truck is on route while it holds a
  // trip that is neither completed nor cancelled. `list_transporter_fleet_
  // status` derives `on_route` this way, so a fixture that disagrees with its
  // own trips is describing a database that cannot exist.
  test('kFleetStatus.onRoute agrees with the trips it is derived from', () {
    for (final status in kFleetStatus) {
      final trips = kLogistics.trips
          .where((t) => t.vehicleId == status.vehicleId)
          .toList();
      final hasActiveTrip =
          trips.any((t) => TripStatus.parse(t.status).isActive);
      expect(
        status.onRoute,
        hasActiveTrip,
        reason: '${status.registration} (${status.vehicleId}): kFleetStatus '
            'says onRoute=${status.onRoute}, but its trips are '
            '${trips.map((t) => t.status).toList()}',
      );
    }
  });

  test('kVehicleDrivers agrees with kFleetStatus about who is out working', () {
    for (final assignment in kVehicleDrivers) {
      final status = kFleetStatus
          .firstWhere((s) => s.vehicleId == assignment.vehicleId);
      expect(
        assignment.onRoute,
        status.onRoute,
        reason: '${assignment.driverName} is on ${assignment.registration}, '
            'so the driver is on route exactly when the truck is',
      );
    }
  });

  // `driversLabel` and `hasDriver` read `drivers`, not `driverName`. Setting
  // the legacy field alone renders "No driver assigned" for a truck that has
  // one — the fault this file was written for.
  test('every truck with a driver assignment carries the `drivers` field', () {
    for (final assignment in kVehicleDrivers) {
      final status = kFleetStatus
          .firstWhere((s) => s.vehicleId == assignment.vehicleId);
      expect(
        status.hasDriver,
        isTrue,
        reason: '${assignment.registration} has assignment '
            '${assignment.assignmentId} (${assignment.driverName}), so it '
            'must not render as "No driver assigned"',
      );
      expect(
        status.drivers,
        contains(assignment.driverName),
        reason: '${assignment.driverName} is assigned to '
            '${assignment.registration} and must appear in its drivers list',
      );
    }
  });

  // The case that must STAY GREEN under any sabotage of the above: a truck
  // with genuinely nobody on it is a real operational state (nothing in
  // `accept_request_dispatch` requires a driver), and the on-route card's
  // warning panel exists to photograph it. A "fix" that gave every truck a
  // driver would pass the three tests above and delete that state.
  test('one on-route truck still has nobody rostered on it', () {
    final driverless =
        kFleetStatus.where((s) => s.onRoute && !s.hasDriver).toList();
    expect(
      driverless,
      isNotEmpty,
      reason: 'the "No driver is assigned to this truck" warning has no '
          'fixture to render against',
    );
  });

  // All three derived fleet states must be in the picture — the whole reason
  // the fleet register and the stat cards exist.
  test('the fixture fleet holds all three derived states', () {
    expect(kFleetStatus.where((s) => s.onRoute), isNotEmpty);
    expect(kFleetStatus.where((s) => s.available), isNotEmpty);
    expect(kFleetStatus.where((s) => s.inMaintenance), isNotEmpty);
  });
}
