// The second driver on a truck must be reachable from the screens.
//
// CLAUDE.md §4: up to two drivers ride one truck by default, five with the
// super-admin's approval, and `DriverAssignmentDialog` is where both the second
// driver and the "request more" path live. Driven on 2026-08-23: the Fleet
// register offered Edit + Unassign once a driver was on the truck, the
// Trucks-on-route card offered nothing at all, and the dialog's
// "1/2 drivers assigned" state could not be reached from any screen — the
// multi-driver rule had no entry point the moment the first driver was
// assigned.
//
// Sabotage: put `!isAssigned &&` back on the Fleet row's button, or delete
// `manage` from the on-route card, and the matching case below fails. The
// unassigned cases stay green under either sabotage, which is what proves the
// fix did not go too far (a truck with nobody on it still says "Assign").
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/fleet/widgets/fleet_vehicle_table.dart';
import 'package:flutter_application_1/features/portal/screens/trucks_on_route_screen.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/portal_tail_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/frozen_clock.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/test_supabase.dart';

FleetVehicle _vehicle({String? driverId}) => FleetVehicle(
      id: 'v1',
      vehicleRegistrationNumber: 'S6W001GP',
      vehicleMake: 'Scania',
      vehicleType: 'Side tipper',
      vehicleYearModel: 2023,
      companyId: 'c1',
      createdAt: DateTime(2024, 1, 1),
      isActive: true,
      assignedDriverId: driverId,
    );

Future<void> _pumpTable(
  WidgetTester tester,
  FleetVehicle vehicle,
  void Function(FleetVehicle) onAssignDriver,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: SizedBox(
          width: 1400,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: FleetVehicleTable(
              vehicles: [vehicle],
              showDriver: true,
              onAssignDriver: onAssignDriver,
              onUnassignDriver: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRealFonts);
  setUpAll(ensureTestSupabaseInitialized);
  setUp(freezeCaptureClock);

  group('Fleet register row', () {
    testWidgets('a truck that already has a driver still opens the dialog',
        (tester) async {
      FleetVehicle? opened;
      await _pumpTable(tester, _vehicle(driverId: 'emp-1'), (v) => opened = v);

      final manage = find.byTooltip('Manage drivers');
      expect(manage, findsOneWidget,
          reason: 'the second driver can only be added from this dialog');
      expect(find.byTooltip('Unassign Driver'), findsOneWidget,
          reason: 'the quick unassign stays beside it');

      await tester.ensureVisible(manage);
      await tester.tap(manage);
      await tester.pump();
      expect(opened?.id, 'v1');
    });

    testWidgets('a truck with nobody on it still says Assign Driver',
        (tester) async {
      await _pumpTable(tester, _vehicle(), (_) {});
      expect(find.byTooltip('Assign Driver'), findsOneWidget);
      expect(find.byTooltip('Manage drivers'), findsNothing);
      expect(find.byTooltip('Unassign Driver'), findsNothing);
    });
  });

  group('Trucks on route card', () {
    Future<void> pump(WidgetTester tester, List<FleetVehicleStatus> fleet) async {
      tester.view.physicalSize = const Size(1600, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authOverride(userType: UserType.employee),
          companyOverride(orgType: OrgType.transporter),
          employeeOverride(orgType: OrgType.transporter),
          ...portalTailOverrides(),
          ...portalCaptureOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: ProviderScope(
            overrides: [
              fleetStatusProvider.overrideWith((ref, _) async => fleet),
            ],
            child: const TrucksOnRouteScreen(),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    const withDriver = FleetVehicleStatus(
      vehicleId: 'veh-1',
      registration: 'S6W001GP',
      isActive: true,
      onRoute: true,
      drivers: 'Driver Test',
      driverCount: 1,
      tripStatus: 'scheduled',
      commodity: 'Chrome Ore',
    );
    const driverless = FleetVehicleStatus(
      vehicleId: 'veh-2',
      registration: 'KVK007MP',
      isActive: true,
      onRoute: true,
      tripStatus: 'en_route_to_offload',
      commodity: 'Chrome Ore',
    );

    testWidgets('a rostered truck offers Manage drivers', (tester) async {
      await pump(tester, const [withDriver]);
      expect(find.text('Manage drivers'), findsOneWidget);
      expect(find.text('Assign driver'), findsNothing);
    });

    testWidgets('a driverless truck keeps its warning and Assign driver',
        (tester) async {
      await pump(tester, const [driverless]);
      expect(find.text('Assign driver'), findsOneWidget);
      expect(find.text('Manage drivers'), findsNothing);
    });
  });
}
