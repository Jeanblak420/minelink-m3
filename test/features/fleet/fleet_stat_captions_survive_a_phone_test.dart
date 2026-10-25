// The fleet stat grid never reached one column, so its captions broke inside
// a word.
//
// Transporter pass, 2026-08-23 (reviewer finding #8). The screen hand-rolled
// `final cols = w > 900 ? 4 : 2` — two columns all the way down to a phone. At
// 412px that leaves each card 183px, of which `MlStatCard` spends ~92 on its
// tone bar, icon well and padding, so the mono captions broke mid-token:
// `carrying_a_lo / ad`, `excludes_1_in / _maintenance`, `not_in_servic / e`.
//
// Nothing overflowed. A wrapped caption is a caption that fits, so no overflow
// sweep would ever have raised it; it was photographed on
// `screen-fleet-phone-dark` and read there.
//
// `MlTileGrid` is the shared component for this, and its own doc names the
// shape as duplicated across sixteen files with breakpoints that disagree
// screen to screen (980/620 here, 900/560 there) for tiles of the same size.
// Asking for a MINIMUM TILE WIDTH states the thing that is actually true and
// has no arbitrary breakpoint to fall out of step with.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/fleet/screens/fleet_management_screen.dart';

import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';
import '../../test_helpers/test_supabase.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    await ensureTestSupabaseInitialized();
  });

  Future<void> pump(WidgetTester tester, double width) async {
    tester.view.physicalSize = Size(width, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...companyScopeOverrides(),
          ...portalCaptureOverrides(),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(body: FleetManagementScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Every caption the four cards can carry, in plain English since
  // 2026-10-25. Each is short enough that it should never need a second line.
  const captions = [
    'All vehicles',
    'Carrying a load',
    'Excludes 1 in maintenance',
    'Not in service',
  ];

  // 380 and 412 are phones; 720 a small tablet, where two columns is right and
  // the captions must still survive.
  for (final width in const [380.0, 412.0, 720.0]) {
    testWidgets('no stat caption breaks at ${width.toInt()}px', (tester) async {
      await pump(tester, width);

      // COUNTED, not inferred from a height ratio.
      //
      // The first version of this divided each caption's height by the height
      // of `All vehicles` in the same render, on the assumption that the
      // shortest caption always fits. At 380px under the old two-column
      // ladder it does NOT — it wraps too — so the reference was two lines
      // tall and every caption measured as exactly "1". The test PASSED under
      // sabotage at that width and only bit at 412. A reference measured from
      // the thing under test is only a reference while the thing under test is
      // right.
      for (final caption in captions) {
        final f = find.text(caption);
        expect(f, findsOneWidget, reason: '"$caption" is not painted');
        // One selection box per painted line. (`computeLineMetrics` is not
        // on `RenderParagraph` in this Flutter.)
        final boxes = tester
            .renderObject<RenderParagraph>(f)
            .getBoxesForSelection(TextSelection(
              baseOffset: 0,
              extentOffset: caption.length,
            ));
        final lines = boxes.map((b) => b.top.round()).toSet().length;
        expect(
          lines,
          1,
          reason: '"$caption" is on $lines lines, and it has nowhere to break '
              '— every character of it is a word',
        );
      }
    });
  }

  // THE CASE THAT MUST STAY GREEN. One column everywhere would satisfy every
  // assertion above and waste the whole desktop. Four cards on a 1600px
  // console belong on one row.
  testWidgets('a desktop still gets all four cards on one row', (tester) async {
    await pump(tester, 1600);

    final tops = [
      for (final caption in captions) tester.getRect(find.text(caption)).top,
    ];
    for (final top in tops) {
      expect(
        (top - tops.first).abs(),
        lessThan(2),
        reason: 'the four cards are not on one row at 1600px',
      );
    }
  });
}
