// THE FLEET REGISTER AND THE STAT CARDS ABOVE IT ANSWER THE SAME QUESTION.
//
// Transporter pass, 2026-08-23 (reviewer finding #7, the sharpest of the
// fleet-register set). The table decided each row's status from
// `assignedDriverId` — "Assigned" / "Unassigned" — while the four cards
// directly above it read `fleetStatusProvider`. Two sources, one question,
// on one screen.
//
// The comment beside those cards already said what that costs, because the
// cards had made the same mistake and had it taken out of them on 2026-08-22:
// reading `hasAssignedDriver` "put every one of Roadhaul's three trucks in the
// WRONG bucket" — the two carrying loads to Johannesburg have no driver row
// and counted as Available, while the one parked truck has a driver and
// counted as On Trip. The table was still doing exactly that.
//
// Availability here is derived server-side from active trips and open
// maintenance records (CLAUDE.md §4). Whether anybody is rostered on the truck
// is a different fact with its own column. The two cases below are the ones
// where the old rule and the right one give OPPOSITE answers, which is why
// they are the ones worth a test.
//
// It also killed a fourth status vocabulary: a hand-rolled solid-gradient pill
// that painted **RED for "Unassigned"**. Red is this system's declined/error
// tone (§5), so the register drew the truck an admin allocates from in the
// colour reserved for the worst thing on the screen.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/widgets/fleet_vehicle_table.dart';

import '../../test_helpers/real_fonts.dart';

final _created = DateTime.utc(2026, 1, 1);

/// A truck WITH a driver that is NOT on a route. `assignedDriverId != null`
/// used to make this one "Assigned", in green.
FleetVehicle _parkedWithDriver() => FleetVehicle(
      id: 'veh-parked',
      companyId: 'co',
      createdAt: _created,
      vehicleRegistrationNumber: 'CK 84 RT GP',
      vehicleMake: 'Freightliner',
      assignedDriverId: 'emp-1',
      driverFirstName: 'Sipho',
      driverLastName: 'Ndlovu',
    );

/// A truck with NOBODY on it that IS carrying a load. Nothing in
/// `accept_request_dispatch` requires a driver, so this is reachable — and the
/// old rule called it "Unassigned", in RED.
FleetVehicle _workingWithNoDriver() => FleetVehicle(
      id: 'veh-working',
      companyId: 'co',
      createdAt: _created,
      vehicleRegistrationNumber: 'BX 09 LM NW',
      vehicleMake: 'Volvo',
    );

FleetVehicle _downForRepair() => FleetVehicle(
      id: 'veh-down',
      companyId: 'co',
      createdAt: _created,
      vehicleRegistrationNumber: 'MN 07 PL GP',
      vehicleMake: 'MAN',
    );

Map<String, FleetVehicleStatus> _derived() => {
      'veh-parked': const FleetVehicleStatus(
        vehicleId: 'veh-parked',
        registration: 'CK 84 RT GP',
        isActive: true,
        onRoute: false,
        drivers: 'Sipho Ndlovu',
        driverCount: 1,
      ),
      'veh-working': const FleetVehicleStatus(
        vehicleId: 'veh-working',
        registration: 'BX 09 LM NW',
        isActive: true,
        onRoute: true,
      ),
      'veh-down': const FleetVehicleStatus(
        vehicleId: 'veh-down',
        registration: 'MN 07 PL GP',
        isActive: true,
        onRoute: false,
        inMaintenance: true,
        maintenanceTitle: 'Gearbox rebuild',
      ),
    };

void main() {
  setUpAll(() async {
    await loadRealFonts();
  });

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    required List<FleetVehicle> vehicles,
    Map<String, FleetVehicleStatus>? statuses,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: FleetVehicleTable(
              vehicles: vehicles,
              statusByVehicleId: statuses,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  MlStatusBadge badgeFor(WidgetTester tester, String label) =>
      tester.widget<MlStatusBadge>(find.byWidgetPredicate(
        (w) => w is MlStatusBadge && w.label == label,
      ));

  // Phone width: the compact card list, which is what a transporter's admin
  // actually reads on a handset.
  for (final width in const [412.0, 1600.0]) {
    final shape = width < 600 ? 'compact cards' : 'the wide table';

    testWidgets('$shape: a truck with a driver but no trip reads AVAILABLE',
        (tester) async {
      await pump(
        tester,
        width: width,
        vehicles: [_parkedWithDriver()],
        statuses: _derived(),
      );

      expect(find.text('AVAILABLE'), findsOneWidget);
      expect(badgeFor(tester, 'Available').tone, MlTone.done);
      // The words the old vocabulary used, in the colour it used them in.
      expect(find.text('ASSIGNED'), findsNothing);
    });

    testWidgets('$shape: a truck with no driver but a live trip reads ON ROUTE',
        (tester) async {
      await pump(
        tester,
        width: width,
        vehicles: [_workingWithNoDriver()],
        statuses: _derived(),
      );

      expect(find.text('ON ROUTE'), findsOneWidget);
      expect(badgeFor(tester, 'On route').tone, MlTone.transit);
      expect(find.text('UNASSIGNED'), findsNothing);
    });

    testWidgets('$shape: an open out-of-service record reads IN MAINTENANCE',
        (tester) async {
      await pump(
        tester,
        width: width,
        vehicles: [_downForRepair()],
        statuses: _derived(),
      );

      expect(find.text('IN MAINTENANCE'), findsOneWidget);
      expect(badgeFor(tester, 'In maintenance').tone, MlTone.warn);
    });
  }

  // A status is a claim about a truck on a road. While the derived read is in
  // flight there is nothing to claim, and the cards say "—" rather than a
  // confident zero — so the rows do too.
  testWidgets('no derived status yet renders a dash, not a guess',
      (tester) async {
    await pump(
      tester,
      width: 412,
      vehicles: [_parkedWithDriver()],
      statuses: null,
    );

    expect(find.text('—'), findsWidgets);
    expect(find.byType(MlStatusBadge), findsNothing);
  });

  // THE CASE THAT MUST STAY GREEN. `isActive` is a fact about the vehicle row,
  // not about the derived feed — the inactive table is built from vehicles the
  // feed need not carry at all, so this must keep working with no status map.
  // A "fix" that routed every badge through the derived map would pass all of
  // the above and leave the inactive register blank.
  testWidgets('an inactive truck reads INACTIVE with no derived feed at all',
      (tester) async {
    final retired = FleetVehicle(
      id: 'veh-retired',
      companyId: 'co',
      createdAt: _created,
      vehicleRegistrationNumber: 'JD 22 PL MP',
      isActive: false,
    );
    await pump(tester, width: 412, vehicles: [retired], statuses: null);

    expect(find.text('INACTIVE'), findsOneWidget);
    // Neutral, not green. `"inactive".contains("active")` is true, and this
    // map returned MlTone.done for it until 2026-08-23 — a truck taken out of
    // the fleet drawn in the same green as one standing ready to load.
    expect(badgeFor(tester, 'Inactive').tone, MlTone.neutral);
  });
}
