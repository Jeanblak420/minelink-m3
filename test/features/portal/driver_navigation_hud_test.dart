// The screen a driver looks at while moving.
//
// It had never been rendered anywhere — not in a test, not in a golden, not in
// a browser — and the first attempt to photograph it turned up four faults, one
// of them a crash. All four are pinned here.
//
//   1. **The camera was driven before the map existed.** `MapController` throws
//      "You need to have the FlutterMap widget rendered at least once" and the
//      follow camera called it from an animation tick with no guard. It is a
//      race, not a hypothetical: the position stream is subscribed BEFORE the
//      `setState` that stops rendering the spinner, so a warm GPS fix arrives,
//      starts the glide and ticks it, all before the map's first frame.
//
//   2. **The HUD broke every word.** Five readouts, three 48px icon buttons and
//      an End button in one `Row` left ~30px per readout at 412px, so the panel
//      a driver GLANCES at read "Dista / nce" and "on / tim / e".
//
//   3. **The banner said "In 0 m".** `_stepIx` stayed at 0 from the moment a
//      route landed until the next fix, so the departure step was announced
//      with a distance measured to the start of the route.
//
//   4. **The destination bar said the same place twice**, the first copy
//      truncated: "Offloading at  Iron Hills Mining — collection po…".
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    installFakePathProvider();
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'driver-nav-hud',
    );
  });

  Future<void> pumpNav(
    WidgetTester tester, {
    double width = 412,
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = Size(width, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    FakeGeolocatorPlatform.install(
      latitude: kNavTruck.latitude,
      longitude: kNavTruck.longitude,
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(role: UserRole.driver),
        ...portalCaptureOverrides(),
        ...navigationOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 915),
            textScaler: TextScaler.linear(textScale),
          ),
          // `t-3` is `loading`, so this is the LOAD leg and the destination is
          // the mine's collection point — which is what the fixture geography
          // describes.
          child: const DriverNavigationScreen(tripId: 't-3'),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Every laid-out paragraph carrying [text], and whether it lost words.
  List<bool> truncations(WidgetTester tester, String text) => [
        for (final e in find.text(text).evaluate())
          (e.renderObject! as RenderParagraph).didExceedMaxLines,
      ];

  testWidgets('starting navigation does not throw', (tester) async {
    await pumpNav(tester);
    expect(tester.takeException(), isNull,
        reason: 'the follow camera is driving MapController before FlutterMap '
            'has been laid out. On a handset with a warm GPS fix that is the '
            'normal case, not the edge one, and the exception escapes an '
            'AnimationController listener at the moment navigation starts.');
  });

  for (final width in const [360.0, 412.0]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('the HUD keeps its words at ${width.toInt()}px x $scale',
          (tester) async {
        await pumpNav(tester, width: width, textScale: scale);

        // "ETA" is one short word and always fits, so its height is the
        // one-line reference for this width and scale.
        final oneLine = tester.getRect(find.text('ETA').first).height;

        for (final label in const [
          'ETA',
          'Time left',
          'Distance',
          'vs plan',
          'km/h',
        ]) {
          final f = find.text(label);
          expect(f, findsWidgets,
              reason: '"$label" is not in the HUD. If a readout was renamed, '
                  'rename it here — do not drop the case.');

          // A label may wrap BETWEEN its words and never inside one. Measured
          // by height rather than by `didExceedMaxLines`, because the old
          // single-row layout DID fit "Dista / nce" inside two lines — it just
          // put the break in the middle of the word.
          final words = label.split(RegExp(r'[ /]')).length;
          final lines = (tester.getRect(f.first).height / oneLine).round();
          expect(lines, lessThanOrEqualTo(words),
              reason: '"$label" takes $lines lines at ${width.toInt()}px x '
                  '$scale and only has $words place(s) to break, so the break '
                  'is inside a word. This is the panel a driver glances at '
                  'while moving; "Dista / nce" names nothing.');
        }
      });
    }
  }

  testWidgets('the banner announces the NEXT manoeuvre, with a real distance',
      (tester) async {
    await pumpNav(tester);

    // `kNavRoute` step 1 is the R555 turn. The truck is at the route start and
    // has not moved, so the very first banner must already be counting down to
    // that turn rather than to the departure it is standing on.
    expect(find.textContaining('Turn left onto R555'), findsWidgets,
        reason: 'the banner is not on the next manoeuvre. `_stepIx` is parked '
            'at 0 until a second GPS fix arrives, and with a 3 m distance '
            'filter a stationary truck may wait a long time for one.');
    expect(find.textContaining('In 0 m'), findsNothing,
        reason: 'the banner is measuring the distance to a manoeuvre the truck '
            'is already standing on. Seed the progress when the route lands.');
  });

  testWidgets('the destination is named once, in full', (tester) async {
    await pumpNav(tester);

    const place = 'Iron Hills Mining — collection point';
    final found = truncations(tester, place);
    expect(found.length, 1,
        reason: 'the destination bar is printing the place ${found.length} '
            'time(s). Twice means the detail line is falling back to the same '
            'label as the headline; none means the fixture stopped reaching '
            'the screen.');
    expect(found.first, isFalse,
        reason: 'the destination is truncated. It is the only field on this '
            'screen that says where the truck is going, and a 13-character '
            '"Offloading at" prefix on the same line is what used to eat it.');
    // The leg is a label of its own now, not a prefix.
    expect(find.text('LOADING AT'), findsOneWidget);
  });
}
