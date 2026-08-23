// A truck's registration is never traded for its own status word.
//
// Transporter pass, 2026-08-23. The on-route card laid its identity and its
// status badge out as `Row(Expanded(identity), badge)` — and an UNFLEXED child
// of a Row is served its natural width FIRST, so the badge was paid before the
// plate and the plate took whatever was left.
//
// With `ON ROUTE` in the badge that was invisible. The moment the fixture
// stopped saying the wrong truck was on route, the badge read
// `EN ROUTE TO OFFLOAD` — the real label for `t-2` — and on a 412px phone at
// text scale 1.0 the plate rendered `JD 22 PL …`. At 360 × 1.6 the identity
// Row was squeezed to 41.3px and overflowed by 21, which is what the portal
// overflow sweep caught.
//
// The fix is `MlHeaderLayout`, the same MEASURED fit rule the two page headers
// use: one row while `identity + gap + badge` fits, otherwise the badge on its
// own row underneath. Not a width rule — the short-badge case below is the
// case that proves it, and it is also the case that must stay green under any
// sabotage of the long one.
//
// The assertion is on the RENDERED text, not on a rectangle: `didExceedMaxLines`
// is the fact that the plate was shortened. A geometry assertion would have
// been satisfied by the squeezed box that caused the fault.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/portal/screens/trucks_on_route_screen.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';
import '../../test_helpers/test_supabase.dart';

/// One truck, on route, with [tripStatus] in its badge. Declared here rather
/// than read from `kFleetStatus` so this test says what it is about and cannot
/// be quietly disarmed by a fixture edit.
List<FleetVehicleStatus> _oneTruck(String tripStatus) => [
      FleetVehicleStatus(
        vehicleId: 'veh-2',
        registration: 'JD 22 PL MP',
        isActive: true,
        onRoute: true,
        make: 'Scania',
        drivers: 'Thandi Mokoena',
        driverCount: 1,
        activeTripId: 't-2',
        tripStatus: tripStatus,
      ),
    ];

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    // The screen resolves its company through a provider that reads
    // Supabase.instance while building.
    await ensureTestSupabaseInitialized();
  });

  Future<void> pump(
    WidgetTester tester, {
    required double width,
    required String tripStatus,
  }) async {
    tester.view.physicalSize = Size(width, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...companyScopeOverrides(),
          ...portalCaptureOverrides(),
          // Last override wins, so this one decides what the card renders.
          fleetStatusProvider
              .overrideWith((ref, _) async => _oneTruck(tripStatus)),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: TrucksOnRouteScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The rendered paragraph behind [text] — the only place that knows whether
  /// the string was actually shortened.
  RenderParagraph paragraphFor(WidgetTester tester, String text) =>
      tester.renderObject<RenderParagraph>(find.text(text));

  testWidgets('a long status does not ellipsise the plate on a phone',
      (tester) async {
    await pump(tester, width: 412, tripStatus: 'en_route_to_offload');

    expect(find.text('JD 22 PL MP'), findsOneWidget);
    expect(
      paragraphFor(tester, 'JD 22 PL MP').didExceedMaxLines,
      isFalse,
      reason: 'the registration is the row\'s identity and was cut to make '
          'room for the status of the trip it is on',
    );
    // And the badge is whole too — the point is that neither is traded.
    expect(find.text('EN ROUTE TO OFFLOAD'), findsOneWidget);
    expect(
      paragraphFor(tester, 'EN ROUTE TO OFFLOAD').didExceedMaxLines,
      isFalse,
    );
  });

  testWidgets('the plate survives the same status at text scale 1.3',
      (tester) async {
    tester.view.physicalSize = const Size(412, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...companyScopeOverrides(),
          ...portalCaptureOverrides(),
          fleetStatusProvider
              .overrideWith((ref, _) async => _oneTruck('en_route_to_offload')),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: const Scaffold(body: TrucksOnRouteScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(paragraphFor(tester, 'JD 22 PL MP').didExceedMaxLines, isFalse);
  });

  // THE CASE THAT MUST STAY GREEN. A fit rule that stacked everything would
  // pass the two tests above and cost every short-badge card a line — which is
  // exactly the width-rule mistake `MlPageHeader` made on 43 goldens and had
  // reverted. `LOADING` beside a plate fits a phone, and must still share the
  // row.
  testWidgets('a short status still shares the row with the plate',
      (tester) async {
    await pump(tester, width: 412, tripStatus: 'loading');

    final plate = tester.getRect(find.text('JD 22 PL MP'));
    final badge = tester.getRect(find.text('LOADING'));
    expect(
      badge.left,
      greaterThan(plate.right),
      reason: 'a badge that fits beside the plate belongs beside it',
    );
    expect(
      (badge.center.dy - plate.center.dy).abs(),
      lessThan(4),
      reason: 'and on the same line as it',
    );
  });
}
