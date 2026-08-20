// The margin ledger is the platform's own money, and it was eating it.
//
// Photographed for the first time on 2026-08-20, on a 1600px window: the
// "Margin earned" column rendered `R 141,306.00` as the single character `R`,
// and the totals row did the same. The three headers naming the platform's
// entire commercial model read "YOUR CUT / T…", "TRANSPORTE…" and
// "MARGIN EAR…".
//
// Neither is an overflow. An ellipsis is a layout that fits — it fits by
// throwing the number away — so no sweep, no golden and no guard had anything
// to say about it. `didExceedMaxLines` on the painted paragraph does.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/screens/margin_ledger_screen.dart';

import '../../fixtures/console_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';

void main() {
  setUpAll(() async {
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'margin-ledger-legibility',
    );
  });

  Future<void> pumpLedger(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [...companyScopeOverrides(), ...consoleCaptureOverrides()],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: MarginLedgerScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  List<bool> truncations(WidgetTester tester, String text) => [
        for (final e in find.text(text).evaluate())
          (e.renderObject! as RenderParagraph).didExceedMaxLines,
      ];

  // 1180 is the table's own declared minimum — below it the table scrolls and
  // is sized to exactly that, so it is the boundary worth checking. 1280 is a
  // laptop and 1600 is the render width; the fault was found at 1600, because
  // above the minimum the table renders inline and COMPRESSES.
  for (final width in const [900.0, 1280.0, 1600.0]) {
    testWidgets('no margin figure is ellipsised at ${width.toInt()}px',
        (tester) async {
      await pumpLedger(tester, width);

      // `kMarginLedger`: R110/t over 1,284.6 t, the widest figure in the
      // fixture, and the totals row that sums all three.
      for (final money in const ['R 141,306.00', 'R 152,844.80']) {
        final found = truncations(tester, money);
        expect(found, isNotEmpty,
            reason: '"$money" is not on the ledger at all. Either the fixture '
                'changed or the figure was ellipsised into something else — '
                'and the second is the fault this test exists for.');
        expect(found.any((t) => t), isFalse,
            reason: '"$money" is ellipsised at ${width.toInt()}px. This is the '
                "platform's own earnings on its own private ledger; a column "
                'that cannot hold the number should widen (MlColumn.minWidth) '
                'or the table should scroll, not swallow it.');
      }
    });

    testWidgets('no ledger header loses a word at ${width.toInt()}px',
        (tester) async {
      await pumpLedger(tester, width);

      for (final header in const [
        'DATE',
        'ROUTE',
        'MINE (SOURCE)',
        'TRANSPORTER · BUYER',
        'TONS MOVED',
        'AGREED / TON',
        'YOUR CUT / TON',
        'TRANSPORTER / TON',
        'MARGIN EARNED',
      ]) {
        final found = truncations(tester, header);
        expect(found, isNotEmpty,
            reason: '"$header" is not painted. If a column was renamed, rename '
                'it here — do not drop the case.');
        expect(found.any((t) => t), isFalse,
            reason: '"$header" is ellipsised at ${width.toInt()}px. Headers are '
                'allowed two lines; past that the column is too narrow for its '
                'widest single word.');
      }
    });
  }
}
