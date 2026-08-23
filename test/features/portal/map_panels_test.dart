// The map list panels in the reference's vocabulary, and a stale sample that
// looks stale.
//
// Phase 3 mine-portal pass, 2026-08-23. `kPositions` has carried a nine-hour-
// old sample since it was written — its own comment says it is "the row an
// operator has to be able to tell apart from the two that reported minutes
// ago" — and the panel drew it exactly like the fresh ones: the same faint
// mono "9h" beside "4m", the same blue well. The desktop list ran its rows
// together with no hairline (only the phone Column had the Divider) and
// carried no section head. And the live map's highlighted marker took
// `scheme.error` — red, the fault colour — for a selection.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/models/live_trip_position.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/widgets/live_truck_marker.dart';
import 'package:flutter_application_1/features/portal/widgets/truck_locations_panel.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'map-panels-test',
    );
  });

  Future<void> pumpTruckLocations(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.admin, orgType: OrgType.mineSupplier),
        ...portalCaptureOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: MineSupplierTruckLocationsScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  test('a sample over an hour old is stale; one under is not', () {
    final now = DateTime.utc(2026, 8, 15, 12);
    expect(isPositionStale(now.subtract(const Duration(minutes: 59)), asOf: now),
        isFalse);
    expect(isPositionStale(now.subtract(const Duration(hours: 9)), asOf: now),
        isTrue);
  });

  testWidgets('a nine-hour-old sample reads in the warn tone; a fresh one does '
      'not', (tester) async {
    await pumpTruckLocations(tester);
    final stale = kPositions.where((p) => isPositionStale(p.recordedAt));
    expect(stale, isNotEmpty,
        reason: 'the fixture must carry a stale sample for this to bite');
    final warn = MlTone.warn.colors(Brightness.dark).fg;

    TextStyle? styleOf(String text) =>
        (find.text(text).evaluate().single.renderObject! as RenderParagraph)
            .text
            .style;
    expect(styleOf('9h')?.color, warn, reason: '"9h" is not in the warn tone');
    expect(styleOf('4m')?.color, isNot(warn), reason: '"4m" is toned as stale');
  });

  testWidgets('the desktop list has a hairline between rows and a head',
      (tester) async {
    await pumpTruckLocations(tester);
    final rows = kPositions.length;
    // Inside the list itself — the page has a hairline of its own elsewhere.
    expect(
      find.descendant(of: find.byType(ListView), matching: find.byType(Divider)),
      findsNWidgets(rows - 1),
      reason: 'expected ${rows - 1} separators between $rows rows',
    );
    expect(
      find.descendant(
          of: find.byType(MlSectionTitle), matching: find.text('Trucks')),
      findsOneWidget,
    );
    // The count lives on the page header, once.
    expect(find.text('$rows trucks reporting'), findsOneWidget);
  });

  testWidgets('the highlighted marker takes the accent, not the fault colour',
      (tester) async {
    const trip = LiveTripPosition(
      tripId: 't-1',
      status: TripStatus.enRouteToOffload,
      truckReg: 'CK 84 RT GP',
      transporterName: 'Roadhaul Logistics',
      lat: -25.87,
      lng: 29.23,
    );
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: const Scaffold(
        body: SizedBox(
          width: 60,
          height: 60,
          child: LiveTruckMarker(trip: trip, highlighted: true),
        ),
      ),
    ));
    await tester.pump();
    final icon = tester.widget<Icon>(find.byIcon(Icons.local_shipping_rounded));
    expect(icon.color, MlTokens.accent);
    expect(icon.color, isNot(AppTheme.darkTheme.colorScheme.error));
  });
}
