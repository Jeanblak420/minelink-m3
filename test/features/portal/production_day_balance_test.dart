// A day that recorded no production has no balance to report.
//
// `production_loss_is_not_reported_from_nothing_test.dart` settled this for the
// two STAT TILES on 2026-08-22: a difference taken against an unknown is not a
// loss, so both `yieldPercent` and `lossTons` return null when nothing was
// mined, and the tiles read `—`.
//
// The table eight rows below them did not get the message. Photographed live as
// `ironhills.owner` on 2026-08-23, 30-day window — the same screen, top to
// bottom:
//
//     0.00 t Mined | 771.32 t Dispatched | — Yield | — Pit-to-port loss
//
//     DATE      MINED     DISPATCHED    DAY BALANCE
//     22 Aug    0.00 t      34.20 t      -34.20 t     <- amber
//     17 Aug    0.00 t     135.80 t     -135.80 t     <- amber
//     16 Aug    0.00 t      65.00 t      -65.00 t     <- amber
//     ...       every row, eight of them
//
// The header says the window cannot be measured. The table quotes a figure out
// of it anyway, and tones every one of them `warn`, so a mine that simply does
// not keep a production log reads as a mine losing tonnage every single day.
//
// The cell computed `d.minedTons - d.dispatchedTons` inline, which is
// `ProductionYield.lossTons` with the guard taken off. It now goes through the
// same class, so the row and the tile above it cannot disagree by construction.
//
// The FIXTURE already had this: `kProductionReport` has two days with
// `minedTons: 0`, one of them dispatching 34.2 t. So
// `screen-mine-production-desktop-dark.png` has been photographing a
// `-34.20 t` in amber every render, for weeks. A render proves a screen drew,
// not that what it drew adds up (CLAUDE.md §10.5).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/mine_production_screen.dart';

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
      anonKey: 'production-day-balance-test',
    );
  });

  Future<void> pumpProduction(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
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
        home: const Scaffold(body: MineProductionScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// Every string drawn on screen, in paint order. `find.text` cannot see a
  /// `TextSpan`, and it cannot answer "is this string absent" for a string that
  /// is built by interpolation — so read the paragraphs instead.
  List<String> painted(WidgetTester tester) => [
        for (final e in find.byType(Text).evaluate())
          (e.widget as Text).data ?? '',
      ]..removeWhere((s) => s.isEmpty);

  testWidgets('a day with nothing mined shows no balance, not a negative one',
      (tester) async {
    await pumpProduction(tester);

    final strings = painted(tester);

    // The fixture's day 4 back: mined 0, dispatched 34.2. The old cell drew
    // exactly this.
    expect(strings, isNot(contains('-34.20 t')),
        reason: 'the Day balance column is quoting a figure out of a day that '
            'recorded no production — `0.00 t` mined against `34.20 t` '
            'dispatched is not a 34.2 t loss, it is a day nobody logged. This '
            'is the same fault the two tiles above it were fixed for.');

    // And it says so, in the same vocabulary the tiles use. FOUR, not two:
    // the Yield and Pit-to-port tiles already draw a dash each, so a threshold
    // of two would pass even with the fix taken out — which is exactly what an
    // earlier draft of this line did.
    expect(strings.where((s) => s == '—').length, greaterThanOrEqualTo(4),
        reason: 'two of the fixture days mined nothing, so two Day balance '
            'cells must read the dash the tiles already use for that state — '
            'on top of the two the tiles themselves draw.');
  });

  testWidgets('a day that DID mine still reports its balance, with a sign',
      (tester) async {
    await pumpProduction(tester);

    final strings = painted(tester);

    // Day 13 back in the fixture: mined 90 + (13*7)%60 = 90 + 31 = 121,
    // dispatched 30 + (13*11)%45 = 30 + 8 = 38. Balance +83.00 t.
    expect(strings, contains('+83.00 t'),
        reason: 'a real measured day must keep its balance and its + sign. If '
            'this disappears, the fix has gone too far and is hiding figures '
            'that have a denominator behind them.');
  });

  testWidgets('no day is toned as a WARNING, because none of them lost tonnage',
      (tester) async {
    // The colour was half of what made the live screen wrong: eight amber
    // pills read as eight bad days. In this fixture every measured day mined
    // more than it dispatched, so a correct screen has NO amber balance at
    // all; the two unmeasured days are the only candidates, and they are the
    // ones the fix turns neutral.
    await pumpProduction(tester);

    final warn = MlTone.warn.colors(Brightness.dark).fg;
    final amber = <String>[];
    for (final e in find.byType(Text).evaluate()) {
      final w = e.widget as Text;
      final data = w.data ?? '';
      // The balance cell's own shape: a signed figure, or the dash.
      if (!RegExp(r'^([-+]\d+\.\d\d t|—)$').hasMatch(data)) continue;
      final colour = (e.renderObject as RenderParagraph).text.style?.color;
      if (colour == warn) amber.add(data);
    }
    expect(amber, isEmpty,
        reason: 'these Day balance cells are drawn in the WARNING colour: '
            '$amber. Every measured day in the fixture mined more than it '
            'dispatched, so the only way to get an amber balance is to take '
            'the difference against a day that recorded nothing — which is '
            'what made a mine with no production log look like a mine losing '
            'tonnage every day.');
  });
}
