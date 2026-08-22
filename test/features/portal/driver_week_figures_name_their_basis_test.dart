// Two "this week" tonnages on one driver's screen, one scroll apart.
//
// Photographed on the emulator as `roadhaul.driver`, 2026-08-23, with a load
// recorded at 01:00 and still on the road:
//
//     stat card   170.5 t   "Tons this week"
//     chart       136.3 t   "Tons delivered"  /  "This week"
//
// Both are right and they measure different things: the card sums every load
// weighed this week, the chart sums only the ones that have been DELIVERED.
// Only one of the two labels said so, and a driver is paid on the delivered
// figure.
//
// So the card names its basis now. The label is longer than the one it
// replaces, and `_MiniStat`'s label has no `maxLines`, so it wraps rather than
// truncating — which on a Row of two `Expanded` cards means the pair can end up
// different heights. That is what this measures: the words have to be right AND
// the row has to survive them, at the width and the text scale a driver's phone
// can actually reach.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/driver_app_screen.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    // Without the real fonts every glyph is one em wide, so a wrap measured
    // here would be a wrap in a font nothing ships — CLAUDE.md §7.
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'driver-week-figures-test',
    );
  });

  Future<void> pumpDriver(WidgetTester tester,
      {required double width, double textScale = 1.0}) async {
    tester.view.physicalSize = Size(width, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.driver, orgType: OrgType.transporter),
        ...portalCaptureOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 2600),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const Scaffold(body: DriverAppScreen()),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the week tonnage card says WHICH tons it counts',
      (tester) async {
    await pumpDriver(tester, width: 412);

    expect(find.text('Tons loaded this week'), findsOneWidget,
        reason: 'the card read a bare "Tons this week" beside a chart headed '
            '"Tons delivered / This week" showing a different figure. A driver '
            'is paid on the delivered one and nothing said which was which.');

    // And the chart keeps naming its own basis, so the two are now distinct
    // sentences rather than the same one twice.
    expect(find.text('Tons delivered'), findsOneWidget);
  });

  testWidgets('the hero card survives a LONG status on a narrow phone',
      (tester) async {
    // The portal overflow sweep pumps this screen with no trip data, so its
    // pill reads `NO ACTIVE TRIP` — fourteen characters. With a real trip on
    // it the pill reads `EN ROUTE TO OFFLOAD`, five characters longer, and at
    // 360 px x 1.3 the unflexed pair overflowed by 44 px and Flutter painted
    // the yellow-and-black stripe across the driver's hero card.
    //
    // `pumpDriver` uses the capture fixtures, so the trip IS there. Any
    // RenderFlex overflow fails the test by itself — this case exists to say
    // what it is guarding, and that the sweep could not.
    await pumpDriver(tester, width: 360, textScale: 1.3);

    expect(find.text('CURRENT TRIP'), findsOneWidget);
    // The pill is whole, not ellipsised into meaninglessness.
    final pill = find.byWidgetPredicate((w) =>
        w is Text && (w.data ?? '').contains('ROUTE TO'));
    expect(pill, findsWidgets,
        reason: 'the live status must survive at 360px x 1.3 — the driver '
            'reads it to know what the app will let them do next.');
  });

  // 360 is the narrowest phone this product supports; a driver can push the
  // platform text scale to 1.3.
  for (final width in const [360.0, 412.0]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('the stat pair stays level at ${width.toInt()}px x $scale',
          (tester) async {
        await pumpDriver(tester, width: width, textScale: scale);

        Rect cardOf(String label) {
          final text = find.text(label);
          expect(text, findsOneWidget, reason: '"$label" is not on screen');
          return tester.getRect(
            find.ancestor(of: text, matching: find.byType(MlCard)).first,
          );
        }

        final loads = cardOf('Loads this week');
        final tons = cardOf('Tons loaded this week');

        expect(tons.height, closeTo(loads.height, 1.0),
            reason: 'the two cards in the top row are ${loads.height} and '
                '${tons.height} tall. `_MiniStat`\'s label wraps instead of '
                'truncating, so a longer label grows one card and the pair '
                'sits crooked — pick a shorter label rather than shipping '
                'that.');
        expect(tons.top, closeTo(loads.top, 1.0),
            reason: 'the cards no longer share a top edge');
      });
    }
  }
}
