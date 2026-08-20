// The mine floor's stat labels have to be READABLE, on the phone they are used
// on.
//
// Security's gate screen and the Load Controller's weighbridge are the two
// screens in this product used outdoors, one-handed, standing next to a truck.
// Both were photographed for the first time on 2026-08-20, and the gate's three
// KPI chips came out reading "Incoming Tod…" and "Departed Tod…" on a 412px
// phone — a guard cannot tell "Today" from "Total" on the count they act on.
//
// A truncation is invisible to an overflow sweep: `maxLines: 1` +
// `TextOverflow.ellipsis` is a layout that FITS. It fits by throwing the words
// away. So this measures the thing a sweep cannot see — `didExceedMaxLines` on
// the painted paragraph — at the two widths and the text scale a real user can
// reach.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/load_controller_screen.dart';
import 'package:flutter_application_1/features/portal/screens/security_checkin_screen.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';

void main() {
  setUpAll(() async {
    // Without the real fonts every glyph is one em wide and this measures a
    // font nothing ships in — CLAUDE.md §7.
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'mine-floor-label-test',
    );
  });

  Future<void> pumpGate(WidgetTester tester,
      {required double width, double textScale = 1.0}) async {
    tester.view.physicalSize = Size(width, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.security, orgType: OrgType.mineSupplier),
        ...portalCaptureOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 2200),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const Scaffold(body: SecurityCheckinScreen()),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Every laid-out paragraph carrying [text], and whether it lost words.
  List<bool> truncations(WidgetTester tester, String text) => [
        for (final e in find.text(text).evaluate())
          (e.renderObject! as RenderParagraph).didExceedMaxLines,
      ];

  // 360 is the narrowest phone this product supports; 412 is the render width.
  for (final width in const [360.0, 412.0]) {
    for (final scale in const [1.0, 1.3]) {
      testWidgets('gate KPI labels are not truncated at ${width.toInt()}px '
          'x $scale', (tester) async {
        await pumpGate(tester, width: width, textScale: scale);

        for (final label in const ['Incoming', 'At Mine', 'Departed Today']) {
          final found = truncations(tester, label);
          expect(found, isNotEmpty,
              reason: '"$label" is not on the gate screen at all. If a chip '
                  'was renamed, rename it here too — do not delete the case, '
                  'because the case is the only thing that noticed the last '
                  'two were unreadable.');
          expect(found.any((t) => t), isFalse,
              reason: '"$label" is ellipsised at ${width.toInt()}px x $scale. '
                  'A guard reads these three counts before deciding whether a '
                  'truck may come in, and a label that stops at "Departed '
                  'Tod…" does not tell them which day it means.');
        }
      });
    }
  }

  testWidgets('the weighbridge heading keeps its words on a phone',
      (tester) async {
    // `MlSectionTitle` capped its title at one line, and Fraunces at the
    // editorial-medium rung is 20px — so on a 412px phone the weighbridge's
    // "Trucks at Mine — Ready for Loading" read "Trucks at Mine — Ready for
    // Lo…". A heading is the thing that says what the list under it is;
    // truncating it is where ellipsis costs the most.
    //
    // `MlSectionTitle` is used at ~32 sites, so this heading is standing in for
    // all of them. It is the longest one on the mine floor, which is what makes
    // it the one that catches a regression first.
    tester.view.physicalSize = const Size(412, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(
            role: UserRole.controllerWB, orgType: OrgType.mineSupplier),
        ...portalCaptureOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: LoadControllerScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    const heading = 'Trucks at Mine — Ready for Loading';
    final found = truncations(tester, heading);
    expect(found, isNotEmpty,
        reason: 'the weighbridge heading is not on screen — the fixture stopped '
            'getting the screen past its gate, so this proves nothing.');
    expect(found.any((t) => t), isFalse,
        reason: 'the section heading lost words at 412px. A one-line cap in '
            'MlSectionTitle ellipsises headings across the whole portal on a '
            'phone, because 20px Fraunces does not fit a real heading in 338px.');
  });

  testWidgets('the Incoming chip does not claim to be scoped to today',
      (tester) async {
    // `MineTrip.isInbound` is `scheduled || en_route_to_load` — no date filter
    // whatsoever — while `departedToday` really does compare SAST calendar
    // days. The two chips sat 10px apart disagreeing about what "Today" meant.
    // The count is right for a guard (a truck dispatched yesterday still
    // arrives today); the label was wrong.
    await pumpGate(tester, width: 412);
    expect(find.text('Incoming Today'), findsNothing,
        reason: 'this chip counts every inbound trip regardless of date, so '
            'calling it "Today" is a claim the number does not make. Either '
            'the label goes back to being unqualified, or the count starts '
            'filtering by MlTime.today() — but not neither.');
    expect(find.text('Incoming'), findsOneWidget);
  });
}
