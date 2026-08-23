import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/widgets/fleet_vehicle_table.dart';

FleetVehicle _sampleVehicle({required String registration}) {
  return FleetVehicle(
    id: 'v1',
    vehicleRegistrationNumber: registration,
    vehicleMake: 'Volvo',
    vehicleType: 'Truck',
    vehicleYearModel: 2020,
    companyId: 'c1',
    createdAt: DateTime(2024, 1, 1),
    isActive: true,
  );
}

void main() {
  group('FleetVehicleTable layout', () {
    testWidgets('uses compact cards below compactTableMax width', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SizedBox(
              width: 500,
              child: FleetVehicleTable(
                vehicles: [_sampleVehicle(registration: 'ABC123GP')],
                showDriver: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('ABC123GP'), findsOneWidget);
      expect(find.text('Volvo · Truck · 2020'), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
      expect(find.byType(MlDataTable), findsNothing);
    });

    // WAS `uses DataTable at wide width`, asserting a Material `DataTable`.
    // The register was the last one in the product and moved onto
    // `MlDataTable` on 2026-08-23 — uppercase overline heads on a plain
    // surface, plate pills, one empty marker. The assertion is inverted rather
    // than deleted, so a return to the Material widget fails here.
    testWidgets('uses the design system table at wide width', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: FleetVehicleTable(
                vehicles: [_sampleVehicle(registration: 'XYZ999GP')],
                showDriver: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('XYZ999GP'), findsOneWidget);
      expect(find.byType(MlDataTable), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
    });
  });
}
