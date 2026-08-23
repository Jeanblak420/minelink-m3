// The fleet screens shouted in Title Case; the reference speaks sentence case.
//
// Transporter pass, 2026-08-23 (reviewer findings #4 and #10). Eighteen labels
// across the fleet register and Trucks on route: "Fleet Management", "Fleet
// Register", "Total Fleet", "Inactive Vehicles", "Register Truck", "Unassign
// Driver", "Mark Vehicle as Inactive", "Reactivate Vehicle", "Assign Driver",
// "Trucks On Route", "On Route".
//
// The sharpest of them is `Trucks On Route`: the portal's app bar directly
// above that header already drew `Trucks on route`, so the screen spelled its
// own name two ways in one picture — visible in
// `screen-trucks-on-route-phone-dark` without measuring anything.
//
// Sentence case is the rule, and PRODUCT NAMES ARE THE EXCEPTION — "Mine
// Control", "Global Admin", "MineLink" keep their capitals, and so do
// ALL-CAPS micro-labels and column heads, which are the reference's own tell.
// So this asserts the specific strings rather than a blanket rule; a blanket
// rule would have renamed the products.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/widgets/fleet_vehicle_table.dart';

import '../../test_helpers/real_fonts.dart';

FleetVehicle _truck({bool withDriver = true, bool active = true}) =>
    FleetVehicle(
      id: 'veh-1',
      companyId: 'co',
      createdAt: DateTime.utc(2024, 1, 1),
      vehicleRegistrationNumber: 'CK 84 RT GP',
      vehicleMake: 'Freightliner',
      isActive: active,
      assignedDriverId: withDriver ? 'emp-1' : null,
      driverFirstName: withDriver ? 'Sipho' : null,
      driverLastName: withDriver ? 'Ndlovu' : null,
    );

void main() {
  setUpAll(() async {
    await loadRealFonts();
  });

  Future<void> pumpTable(
    WidgetTester tester, {
    required List<FleetVehicle> vehicles,
    bool reactivate = false,
  }) async {
    tester.view.physicalSize = const Size(1400, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 1250,
              child: FleetVehicleTable(
                vehicles: vehicles,
                statusByVehicleId: const {
                  'veh-1': FleetVehicleStatus(
                    vehicleId: 'veh-1',
                    registration: 'CK 84 RT GP',
                    isActive: true,
                    onRoute: false,
                  ),
                },
                onEditVehicle: (_) {},
                onAssignDriver: (_) {},
                onUnassignDriver: (_) {},
                onRemoveVehicle: reactivate ? null : (_) {},
                onReactivateVehicle: reactivate ? (_) {} : null,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Every tooltip the register's action buttons carry.
  Set<String> tooltips(WidgetTester tester) => tester
      .widgetList<IconButton>(find.byType(IconButton))
      .map((b) => b.tooltip)
      .whereType<String>()
      .toSet();

  testWidgets('the row actions are sentence case', (tester) async {
    await pumpTable(tester, vehicles: [_truck()]);

    expect(
      tooltips(tester),
      containsAll(<String>{
        'Edit vehicle details',
        'Manage drivers',
        'Unassign driver',
        'Mark as inactive',
      }),
    );
    expect(tooltips(tester), isNot(contains('Unassign Driver')));
  });

  testWidgets('a driverless truck offers "Assign driver", not "Assign Driver"',
      (tester) async {
    await pumpTable(tester, vehicles: [_truck(withDriver: false)]);

    expect(tooltips(tester), contains('Assign driver'));
    expect(tooltips(tester), isNot(contains('Assign Driver')));
  });

  testWidgets('a retired truck offers "Reactivate vehicle"', (tester) async {
    await pumpTable(
      tester,
      vehicles: [_truck(withDriver: false, active: false)],
      reactivate: true,
    );

    expect(tooltips(tester), contains('Reactivate vehicle'));
    expect(tooltips(tester), isNot(contains('Reactivate Vehicle')));
  });

  // THE CASE THAT MUST STAY GREEN. A blanket lower-casing pass would satisfy
  // every assertion above and destroy the product names and the ALL-CAPS
  // micro-labels, which are the reference's own texture and NOT drift.
  testWidgets('column heads stay ALL CAPS and the status pill keeps its shout',
      (tester) async {
    await pumpTable(tester, vehicles: [_truck()]);

    expect(find.text('REGISTRATION'), findsOneWidget);
    expect(find.text('DRIVERS'), findsOneWidget);
    // MlStatusBadge renders its label uppercase by design.
    expect(find.byType(MlStatusBadge), findsOneWidget);
  });
}
