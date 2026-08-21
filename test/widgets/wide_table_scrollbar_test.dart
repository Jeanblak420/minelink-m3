// A table that scrolls sideways has to SAY it scrolls sideways.
//
// `MlWideTable` exists for exactly that — its own header records that fifteen
// of the sixteen horizontal scroll views in `lib/` had no scrollbar, so a
// reader saw a last column cut off mid-word and no reason to think anything
// was past it. On a desktop, with no touch surface to flick, that is simply a
// broken-looking table.
//
// `find.byType(Scrollbar)` does not prove that. A `Scrollbar` is in the tree
// on every one of those screens; the question is whether a THUMB was painted,
// and `RawScrollbar` reveals its thumb through a fade driven by a post-frame
// callback that does not always line up with the scroll position attaching
// (measured on the console's company-link picker — the reasoning is in
// `company_link_builder.dart`).
//
// So this asks the painter. `ScrollbarPainter.hitTest` returns false both when
// no thumb rect was computed and when the fade opacity is still zero, which is
// exactly the pair of failures worth catching. Probing a line of points across
// the scroll view finds the thumb wherever it was drawn.
//
// Written 2026-08-21 after `screen-buyer-requests-phone-dark.png` showed the
// portal's Request-tracking table clipped mid-word at the card edge with no
// bar under it, while the console's own tracking table three renders away had
// one.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_requests_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_waybills_screen.dart';

import '../fixtures/portal_capture_fixtures.dart';
import '../fixtures/portal_tail_fixtures.dart';
import '../fixtures/screen_fixtures.dart';
import '../test_helpers/real_fonts.dart';
import '../test_helpers/render_pumps.dart';
import '../test_helpers/frozen_clock.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'wide-table-scrollbar',
    );
  });

  Future<void> pump(WidgetTester tester, Widget body, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(),
        ...portalCaptureOverrides(),
        ...portalTailOverrides(),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(body: body),
      ),
    ));
    // `pumpForCapture`, not a hand-rolled pump: the reveal takes three frames
    // on any screen whose data arrives from a `FutureProvider`, and that
    // schedule is written down once in `render_pumps.dart` so the render
    // harness and this test cannot drift. Both of those files already name
    // THIS file as the thing that proves the schedule is long enough — it had
    // never actually been written.
    await pumpForCapture(tester);
  }

  /// Every horizontally-scrolling viewport on screen, with how far it can
  /// scroll and the rectangle it occupies.
  List<({ScrollPosition position, Rect rect})> horizontalViewports(
      WidgetTester tester) {
    final out = <({ScrollPosition position, Rect rect})>[];
    // `tester.stateList`, not `Scrollable.of(element)`: `of` reads an
    // INHERITED widget, so handing it the Scrollable's own element finds the
    // scrollable ABOVE it — on a page that is itself a scroll view, that is
    // the page, and every horizontal table reports the page's vertical axis.
    // The first draft did that and measured nothing at all.
    for (final state in tester.stateList<ScrollableState>(
        find.byType(Scrollable, skipOffstage: false))) {
      final axis = state.widget.axisDirection;
      if (axis != AxisDirection.right && axis != AxisDirection.left) continue;
      if (!state.position.hasContentDimensions) continue;
      final box = state.context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      out.add((
        position: state.position,
        rect: box.localToGlobal(Offset.zero) & box.size,
      ));
    }
    return out;
  }

  /// How many scrollbar painters on screen actually PAINT something.
  ///
  /// Not `hitTest`: that returns false whenever `ignorePointer` is set, and
  /// Material's `Scrollbar` sets it on every touch platform — so a perfectly
  /// visible thumb answers "no" and the first draft of this measured zero on a
  /// screen whose render plainly has one.
  ///
  /// Not `find.byType(Scrollbar)` either: the widget is in the tree on every
  /// one of these screens; the question is whether anything was drawn.
  ///
  /// So run the painter over a recording canvas and count the marks. That is
  /// the same reasoning as `meter_fill_is_visible_test.dart` — a grep proves
  /// the argument is written, only a measurement proves the pixels are there.
  Future<int> paintedThumbs(WidgetTester tester) async {
    var found = 0;
    for (final element in find.byType(CustomPaint, skipOffstage: false)
        .evaluate()) {
      final painter = (element.widget as CustomPaint).foregroundPainter;
      if (painter is! ScrollbarPainter) continue;
      final box = element.renderObject as RenderBox?;
      if (box == null || !box.hasSize) continue;

      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), box.size);
      final picture = recorder.endRecording();
      final image = picture.toImageSync(
          box.size.width.ceil().clamp(1, 4096),
          box.size.height.ceil().clamp(1, 4096));
      final bytes = await tester
          .runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba));
      image.dispose();
      picture.dispose();
      if (bytes == null) continue;

      var opaque = 0;
      final data = bytes.buffer.asUint8List();
      for (var i = 3; i < data.length; i += 4) {
        if (data[i] > 8) opaque++;
      }
      if (opaque > 0) found++;
    }
    return found;
  }

  Future<void> expectEveryWideTableSaysSo(
      WidgetTester tester, String where) async {
    final viewports = horizontalViewports(tester)
        .where((v) => v.position.maxScrollExtent > 0)
        .toList();
    expect(viewports, isNotEmpty,
        reason: 'nothing on $where scrolls sideways at this width, so this '
            'test is measuring nothing — either the fixture stopped producing '
            'rows or the table stopped being wide.');
    final thumbs = await paintedThumbs(tester);
    expect(thumbs, greaterThanOrEqualTo(viewports.length),
        reason: '${viewports.length} table(s) on $where scroll sideways and '
            'only $thumbs of them paint a thumb. A horizontal scroll view '
            'with no visible bar reads as a table that has been cut off, not '
            'as one that can be scrolled — Flutter draws no bar unless one is '
            'asked for, and `thumbVisibility: true` still needs a controller '
            'the bar can attach to.');
  }

  // 412px: the width the renders are taken at, and the width the fault was
  // found at. A nine-column tracking table has no chance of fitting it, so
  // every one of these genuinely scrolls.
  testWidgets('the buyer\'s Requests screen shows a bar on its tracking table',
      (tester) async {
    await pump(tester, const BuyerRequestsScreen(), const Size(412, 2600));
    await expectEveryWideTableSaysSo(tester, "the buyer's Requests screen");
  });

  testWidgets('the buyer\'s Waybills screen shows a bar on every route table',
      (tester) async {
    await pump(tester, const BuyerWaybillsScreen(), const Size(412, 1500));
    await expectEveryWideTableSaysSo(tester, "the buyer's Waybills screen");
  });
}
