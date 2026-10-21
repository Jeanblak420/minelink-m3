// The driver's map should behave like Google Maps' and Waze's (jean,
// 2026-10-21): follow the truck, let the driver look around, and come back on
// Re-centre.
//
// What was wrong before, each pinned below:
//
//   1. **The truck sat in the middle of the screen.** Half the map was road
//      already driven, and the top of the other half was under the banner.
//   2. **The zoom buttons did nothing that lasted.** They moved the camera, and
//      the next GPS fix put the speed zoom straight back.
//   3. **Any touch stopped following** — a pinch to zoom included.
//   4. **The only way back was a small icon** at the edge of the screen; there
//      was no "Re-centre" for a driver to find.
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/driver_navigation_screen.dart';

import '../../fixtures/nav_fixtures.dart';
import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/fake_geolocator.dart';
import '../../test_helpers/fake_path_provider.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

const _w = 412.0, _h = 915.0;
final _puck = find.byKey(const ValueKey('nav-puck'));
final _recenter = find.byKey(const ValueKey('nav-recenter'));

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    installFakePathProvider();
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'driver-nav-follow',
    );
  });

  late FakeGeolocatorPlatform gps;

  Future<void> pumpNav(WidgetTester tester, {double speedMps = 0}) async {
    tester.view.physicalSize = const Size(_w, _h);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    gps = FakeGeolocatorPlatform.install(
      latitude: kNavTruck.latitude,
      longitude: kNavTruck.longitude,
      speedMps: speedMps,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(role: UserRole.driver),
        ...portalCaptureOverrides(),
        ...navigationOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const MediaQuery(
          data: MediaQueryData(size: Size(_w, _h)),
          child: DriverNavigationScreen(tripId: 't-3'),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
  }

  MapCamera camera(WidgetTester tester) =>
      tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!.camera;

  /// Where following puts the truck: centred across, [_lookAhead] down.
  const followY = _h * (0.5 + 0.22);

  testWidgets('following puts the truck low on the screen, road ahead above',
      (tester) async {
    await pumpNav(tester);
    final c = tester.getCenter(_puck);
    expect(c.dx, closeTo(_w / 2, 2));
    expect(c.dy, closeTo(followY, 3),
        reason: 'the truck is at y=${c.dy.toStringAsFixed(0)}. Centred on the '
            'screen, half the map is road already driven and the top of the '
            'rest is under the instruction banner.');
    expect(_recenter, findsNothing);
  });

  testWidgets('dragging the map looks around and offers Re-centre',
      (tester) async {
    await pumpNav(tester);
    final before = tester.getCenter(_puck);
    await tester.dragFrom(const Offset(_w / 2, 400), const Offset(0, 220));
    await settle(tester);

    expect(_recenter, findsOneWidget,
        reason: 'the driver has dragged the map away and there is no labelled '
            'way back.');
    expect((tester.getCenter(_puck) - before).distance, greaterThan(50),
        reason: 'the map did not stay where the driver dragged it — the follow '
            'camera snapped it back.');

    // A new GPS fix must not yank it back while he is looking.
    final looked = tester.getCenter(_puck);
    gps.emit();
    await settle(tester);
    expect((tester.getCenter(_puck) - looked).distance, lessThan(2));
    expect(_recenter, findsOneWidget);
  });

  testWidgets('Re-centre glides back to the truck and resumes following',
      (tester) async {
    await pumpNav(tester);
    await tester.dragFrom(const Offset(_w / 2, 400), const Offset(140, 220));
    await settle(tester);
    final away = tester.getCenter(_puck);

    await tester.tap(_recenter);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final mid = tester.getCenter(_puck);
    expect((mid - away).distance, greaterThan(5),
        reason: 'Re-centre has not started moving the camera');
    expect((mid - const Offset(_w / 2, followY)).distance, greaterThan(5),
        reason: 'Re-centre JUMPED. Google Maps and Waze glide back so the '
            'driver keeps his bearings.');

    await settle(tester);
    final back = tester.getCenter(_puck);
    expect(back.dx, closeTo(_w / 2, 2));
    expect(back.dy, closeTo(followY, 3));
    expect(_recenter, findsNothing);

    // And it is FOLLOWING again, not just parked on the truck once.
    gps.emit();
    await settle(tester);
    expect(tester.getCenter(_puck).dy, closeTo(followY, 3));
  });

  testWidgets('the zoom buttons keep following, and the zoom lasts past the '
      'next fix', (tester) async {
    await pumpNav(tester);
    final z0 = camera(tester).zoom;

    await tester.tap(find.byIcon(Icons.add_rounded));
    await settle(tester);
    expect(camera(tester).zoom, closeTo(z0 + 1, 0.01));
    expect(_recenter, findsNothing,
        reason: 'zooming is not looking around; following must continue');
    expect(tester.getCenter(_puck).dy, closeTo(followY, 3));

    gps.emit();
    await settle(tester);
    expect(camera(tester).zoom, closeTo(z0 + 1, 0.01),
        reason: 'the next GPS fix undid the driver\'s zoom — the follow camera '
            'reapplied its speed zoom over it.');
  });

  testWidgets('a pinch zooms without stopping following', (tester) async {
    await pumpNav(tester);
    final z0 = camera(tester).zoom;

    final a = await tester.startGesture(const Offset(_w / 2 - 30, 450));
    final b = await tester.startGesture(const Offset(_w / 2 + 30, 450));
    for (var i = 1; i <= 10; i++) {
      await a.moveTo(Offset(_w / 2 - 30 - i * 12.0, 450));
      await b.moveTo(Offset(_w / 2 + 30 + i * 12.0, 450));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await settle(tester);

    expect(camera(tester).zoom, greaterThan(z0 + 0.3),
        reason: 'the pinch did not zoom at all');
    expect(_recenter, findsNothing,
        reason: 'a pinch stopped following. In Google Maps and Waze, zooming '
            'keeps the truck in view.');
    final c = tester.getCenter(_puck);
    expect(c.dx, closeTo(_w / 2, 3));
    expect(c.dy, closeTo(followY, 4));
  });

  testWidgets('the compass follows north-up; Re-centre returns heading-up',
      (tester) async {
    // Moving (18 km/h): heading is ignored when stationary, rightly.
    await pumpNav(tester, speedMps: 5);
    // The fake truck heads 42°, so a heading-up camera is rotated.
    expect(camera(tester).rotation, closeTo(-42, 1));

    await tester.tap(find.byTooltip('Point the map north'));
    await settle(tester);
    expect(camera(tester).rotation, closeTo(0, 0.5));
    expect(_recenter, findsNothing);
    gps.emit();
    await settle(tester);
    expect(camera(tester).rotation, closeTo(0, 0.5),
        reason: 'the next fix turned the map back to the heading');

    await tester.dragFrom(const Offset(_w / 2, 400), const Offset(0, 200));
    await settle(tester);
    await tester.tap(_recenter);
    await settle(tester);
    expect(camera(tester).rotation, closeTo(-42, 1));
    expect(tester.getCenter(_puck).dy, closeTo(followY, 3));
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
