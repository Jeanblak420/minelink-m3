// The recon table is the screen this product exists to produce. Both of the
// faults pinned here were invisible to every sweep, because both are layouts
// that FIT.
//
//   1. **A word broken in half is not an overflow.** Squeezed into 1120px, the
//      fourteen columns left "DELIVERED" too little room, so Flutter broke
//      inside the word rather than between words: the header read "DELIVER /
//      ED", "VARIAN / CE", "PO / D", and a row read "Manganes / e". Nothing
//      overflowed. Nothing raised. Found by looking at
//      `screen-recon-tables-desktop-dark.png` on 2026-08-20.
//
//   2. **An ellipsised figure is not an overflow either.** The period-total
//      cards used a hand-rolled `cols = maxWidth > 700 ? n : (n/2).ceil()`
//      ladder, which chose three 120px columns on a 380px phone. An `MlStatCard`
//      spends 92px on its tone bar, icon well and padding before the first
//      character of text, so all five cards rendered as an icon and a single
//      letter — D, W, M, Y, T — with the tonnage gone. On the screen whose
//      entire purpose is the tonnage.
//
// So this measures words, not overflow: a header may wrap BETWEEN words and
// never inside one, and a stat card's figure must survive a phone.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/widgets/raw_recon_view.dart';

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
      anonKey: 'recon-legibility-test',
    );
  });

  Future<void> pumpRecon(WidgetTester tester, double width,
      {double textScale = 1.0}) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [...companyScopeOverrides(), ...portalCaptureOverrides()],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 2400),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const Scaffold(
            body: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: RawReconView(companyId: null),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// How many lines [text] is allowed to occupy: one, plus one for each place a
  /// line break can legitimately fall. Anything more means Flutter broke inside
  /// a word.
  int allowedLines(String text) =>
      1 + ' -/'.split('').fold(0, (n, c) => n + text.split(c).length - 1);

  // These are the header labels the table draws, uppercased by the widget.
  const headers = [
    'DATE',
    'TIME-IN',
    'WAYBILL',
    'TRANSPORTER',
    'TRUCK',
    'DESTINATION',
    'PRODUCT',
    'SOURCE',
    'CUSTOMER',
    'NET MASS',
    'DELIVERED',
    'VARIANCE',
    'POD',
    'TIME-OUT',
  ];

  // 1600 is the desktop render width; 1440 is a common laptop. Both were wide
  // enough for the OLD minimum, which is exactly why the broken words shipped:
  // the table only scrolled on a phone, so on every screen anyone actually
  // looked at it was being compressed instead.
  for (final width in const [500.0, 1440.0, 1600.0]) {
    testWidgets('no recon header breaks inside a word at ${width.toInt()}px',
        (tester) async {
      await pumpRecon(tester, width);

      // The one-line reference, measured from the same render: "DATE" is one
      // short word and always fits.
      final dateFinder = find.text('DATE');
      expect(dateFinder, findsOneWidget,
          reason: 'the recon table did not render — the fixture stopped '
              'reaching it, so this proves nothing.');
      final oneLine = tester.getRect(dateFinder).height;

      final broken = <String>[];
      for (final h in headers) {
        final f = find.text(h);
        if (f.evaluate().isEmpty) {
          broken.add('$h: not painted (renamed? then rename it here too)');
          continue;
        }
        final height = tester.getRect(f.first).height;
        final lines = (height / oneLine).round();
        if (lines > allowedLines(h)) {
          broken.add('$h: $lines lines, and it only has '
              '${allowedLines(h)} place(s) to break');
        }
      }

      expect(broken, isEmpty,
          reason: 'a header wrapped inside a word. The table is being '
              'compressed below the width its own columns need — raise '
              "_ExcelReconTable's minWidth so it scrolls instead. A broken "
              'word is not an overflow, so nothing else in this suite will '
              'ever tell you.\n  ${broken.join('\n  ')}');
    });
  }

  // 3. AND A FIGURE MUST NOT BREAK EITHER, AT ANY TEXT SIZE.
  //
  // The header fix of 2026-08-20 raised `minWidth` to a MEASURED 1480 — measured
  // at text scale 1.0, and then left as a fixed pixel figure under a type size
  // the reader controls. `MlDataTable._effectiveMinWidth` documents that exact
  // trap in as many words, having fallen into it once already.
  //
  // Found on Jean's own handset on 2026-08-23, which runs a raised font size:
  // the TIME-IN column read
  //
  //     12:3
  //     5
  //
  // Measured at the table's own minimum: 0 wrapped time cells at scale 1.0,
  // SIXTEEN at 1.3 and sixteen at 2.0. A wrapped cell is a cell that FITS, so
  // no sweep and no overflow capture could ever have seen it — the same reason
  // the broken header words shipped.
  //
  // 2.0 is included because the platform text size on Android goes past the
  // console's own 0.85–1.3 slider, and this table is read on a phone.
  for (final scale in const [1.0, 1.3, 2.0]) {
    testWidgets('no recon figure breaks in half at text scale $scale',
        (tester) async {
      // 500px: narrow enough that the scroll view sizes the table to exactly
      // its minimum, so the BOUNDARY is what gets measured.
      await pumpRecon(tester, 500, textScale: scale);

      final broken = <String>[];
      for (final e in find.byType(Text).evaluate()) {
        final data = (e.widget as Text).data ?? '';
        // A clock time and a tonnage: two values with no legal break point in
        // them at all, so more than one line can only be a break inside one.
        if (!RegExp(r'^\d\d:\d\d$').hasMatch(data) &&
            !RegExp(r'^\d+\.\d\d$').hasMatch(data)) {
          continue;
        }
        final p = e.renderObject as RenderParagraph;
        if (p.size.height > p.getMinIntrinsicHeight(double.infinity) * 1.6) {
          broken.add(data);
        }
      }

      expect(broken, isEmpty,
          reason: 'at text scale $scale these figures are drawn across two '
              'lines: $broken. There is no space or hyphen in any of them, so '
              'the break is INSIDE the value — "12:35" reads as "12:3" over '
              '"5" on the table this product exists to produce. The minimum '
              'width has to scale with the text, because the minimum is a '
              'statement ABOUT the text.');
    });
  }

  for (final width in const [360.0, 412.0]) {
    testWidgets('the period totals keep their figures at ${width.toInt()}px',
        (tester) async {
      await pumpRecon(tester, width);

      // All five periods are visible by default, which is the worst case and
      // the one that was broken.
      const expected = '103.22 t';
      final f = find.text(expected);
      expect(f, findsWidgets,
          reason: 'no period-total card is showing $expected. Either the '
              'fixture changed or the figure is being ellipsised away — which '
              'is what this test exists for.');

      final ellipsised = [
        for (final e in f.evaluate())
          if ((e.renderObject! as RenderParagraph).didExceedMaxLines) 1,
      ];
      expect(ellipsised, isEmpty,
          reason: 'a period-total card ellipsised its own tonnage at '
              '${width.toInt()}px. An MlStatCard needs ~92px before its first '
              'character; the grid handed it less. Use MlTileGrid with a '
              'minTileWidth rather than a column ladder — a ladder can always '
              'produce a tile narrower than its content.');
    });
  }
}
