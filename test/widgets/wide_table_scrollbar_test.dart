// A table wider than its column must say so.
//
// A `SingleChildScrollView(scrollDirection: Axis.horizontal)` around a table is
// the right structure — a thirteen-column fleet register cannot be made to fit
// a laptop and should not be truncated to try. What it does not do is tell
// anyone: Flutter draws no scrollbar for a horizontal scroll view unless one is
// asked for, so a reader sees a last column cut off mid-word and no reason to
// think there is anything past it. On a desktop, with nothing to flick, that is
// simply a broken-looking table.
//
// Measured 2026-08-20: fifteen of the sixteen horizontal scroll views in `lib/`
// had no scrollbar. This pins the treatment on the shared component and on the
// screens that were converted to it, because "we added a scrollbar" is exactly
// the kind of claim that quietly stops being true.
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_wide_table.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import '../test_helpers/real_fonts.dart';
import '../test_helpers/render_pumps.dart';

void main() {
  setUpAll(loadRealFonts);
  _contrastTests();
  _paintTests();

  Future<void> pump(WidgetTester tester, Widget child, double width) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: SizedBox(width: width, child: child)),
    ));
    await tester.pump();
    // See `_ContrastProbe`: the thumb fades in from a post-frame callback, so
    // one pump never shows it.
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('MlWideTable', () {
    testWidgets('scrolls WITH a visible bar when the content is too wide',
        (tester) async {
      await pump(tester, const MlWideTable(child: SizedBox(width: 1200)), 400);

      final bar = tester.widget<Scrollbar>(find.byType(Scrollbar));
      expect(bar.thumbVisibility, isTrue,
          reason: 'a thumb that only appears while dragging is no use to '
              'somebody who does not know there is anything to drag');
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('owns a controller, or thumbVisibility asserts at runtime',
        (tester) async {
      // A horizontal SingleChildScrollView does NOT adopt the
      // PrimaryScrollController — that is vertical-only by default — so a
      // Scrollbar given neither a controller nor a primary scroll view throws
      // in debug, on the screen that scrolls. Any exception here is that.
      await pump(tester, const MlWideTable(child: SizedBox(width: 1200)), 400);
      expect(tester.takeException(), isNull);

      final bar = tester.widget<Scrollbar>(find.byType(Scrollbar));
      expect(bar.controller, isNotNull);
      final view =
          tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(view.controller, same(bar.controller),
          reason: 'the bar and the view must share one controller, or the bar '
              'has nothing to report');
    });

    testWidgets('draws NO bar when the content already fits', (tester) async {
      // A scrollbar over content that cannot scroll is a promise of more.
      await pump(
        tester,
        const MlWideTable(minWidth: 300, child: SizedBox(width: 300)),
        800,
      );
      expect(find.byType(Scrollbar), findsNothing);
      expect(find.byType(SingleChildScrollView), findsNothing);
    });

    testWidgets('a null minWidth lets the child size itself and still scrolls',
        (tester) async {
      // Material's DataTable measures its own columns, so it is handed no
      // minWidth — the scroll view takes whatever it turns out to be.
      await pump(tester, const MlWideTable(child: SizedBox(width: 900)), 400);
      expect(find.byType(Scrollbar), findsOneWidget);
      final view =
          tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      expect(view.child, isA<SizedBox>());
    });

    testWidgets('leaves room under the content for the bar', (tester) async {
      // Without it the thumb sits on the last row of the table.
      await pump(tester, const MlWideTable(child: SizedBox(width: 1200)), 400);
      final view =
          tester.widget<SingleChildScrollView>(find.byType(SingleChildScrollView));
      final padding = (view.padding as EdgeInsets?) ?? EdgeInsets.zero;
      expect(padding.bottom, greaterThan(0));
    });
  });
}


/// The thumb has to be LEGIBLE, and that is a measurement rather than an
/// opinion.
///
/// `Scrollbar` in this app is not decoration: on a wide table it is the only
/// thing saying there are columns past the right edge. Two plausible-looking
/// values were tried before this one and both were invisible —
///
///   Material's default   `onSurface` at 8%
///   the first attempt    `outline` at 55%  ->  composited **2.01:1**
///
/// — under WCAG's 3:1 for a non-text control. Neither could be told apart from
/// the other by reading the source, which is why the ratio is computed here
/// from the theme's own colours rather than trusted.
///
/// This asserts the COLOUR, not the painting. Painting is `_paintTests` below —
/// which had to be written because "the structure is right and the colour is
/// legible" was true for a whole session while the renders still showed a
/// truncated table with no bar on it at all.
void _contrastTests() {
  const kNonTextContrast = 3.0;

  double luminance(Color c) {
    double channel(double u) =>
        u <= 0.03928 ? u / 12.92 : math.pow((u + 0.055) / 1.055, 2.4) as double;
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  double contrast(Color a, Color b) {
    final x = luminance(a), y = luminance(b);
    return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
  }

  /// [over] composited under [c]'s alpha — what the eye actually receives.
  Color flatten(Color c, Color over) => Color.from(
        alpha: 1,
        red: c.r * c.a + over.r * (1 - c.a),
        green: c.g * c.a + over.g * (1 - c.a),
        blue: c.b * c.a + over.b * (1 - c.a),
      );

  group('the thumb is legible against the surface it sits on', () {
    for (final entry in {
      'dark': AppTheme.darkTheme,
      'light': AppTheme.lightTheme,
    }.entries) {
      test(entry.key, () {
        final theme = entry.value;
        final thumb = theme.scrollbarTheme.thumbColor!.resolve(<WidgetState>{});
        expect(thumb, isNotNull,
            reason: 'no scrollbar thumb colour is themed at all, so Material '
                'draws its default onSurface-at-8%');

        // A scrollbar sits over a card, which is the surface a wide table is
        // on — not the scaffold background.
        final surface = theme.cardTheme.color ?? theme.colorScheme.surface;
        final ratio = contrast(flatten(thumb!, surface), surface);

        expect(ratio, greaterThanOrEqualTo(kNonTextContrast),
            reason: 'the thumb measures ${ratio.toStringAsFixed(2)}:1 on the '
                '${entry.key} card. It is the only thing telling a reader a '
                'table has more columns, so it is a non-text control and owes '
                '3:1.');
      });
    }

    test('and it is chrome, not an accent', () {
      // A cyan bar under every table would read as a control rather than as
      // the edge of a scroll. The accent is reserved for the DRAGGED state,
      // where it is feedback for something the user is doing.
      final t = AppTheme.darkTheme.scrollbarTheme;
      final resting = t.thumbColor!.resolve(<WidgetState>{});
      final dragged = t.thumbColor!.resolve({WidgetState.dragged});
      expect(resting, isNot(AppTheme.darkTheme.colorScheme.primary));
      expect(dragged, AppTheme.darkTheme.colorScheme.primary);
    });

    test('the thumb grows on hover, because it is also a drag target', () {
      final t = AppTheme.darkTheme.scrollbarTheme;
      final resting = t.thickness!.resolve(<WidgetState>{})!;
      final hovered = t.thickness!.resolve({WidgetState.hovered})!;
      expect(hovered, greaterThan(resting));
    });
  });
}

/// The thumb has to be **on the picture**, and that is pixels, not structure.
///
/// Everything above this asserts that a `Scrollbar` is in the tree and that its
/// colour would be legible if drawn. Both were true, for a whole session, while
/// `docs/redesign/renders/screen-load-controller-phone-dark.png` showed a table
/// cut off mid-column with no bar anywhere on it — the exact fault `MlWideTable`
/// exists to end, in the picture of `MlWideTable` working.
///
/// The cause was the render harness's pump schedule, not the component: a screen
/// fed by a `FutureProvider` renders a spinner on frame one, so the table is not
/// built until frame two, its scroll metrics notify from *that* frame's
/// post-frame callback, and the 300ms fade has not started when frame three
/// paints. `shoot()`'s last pump carried no duration, so the clock never moved.
///
/// This drives the real schedule — [pumpForCapture], the same function the
/// render harness calls — over a table whose rows arrive from a future, and then
/// counts thumb-coloured pixels in the captured image. Shorten the schedule and
/// this fails.
void _paintTests() {
  testWidgets('the thumb is PAINTED when the rows arrive from a future',
      (tester) async {
    tester.view.physicalSize = const ui.Size(400, 300);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // A future that resolves after the first frame, exactly like every portal
    // provider on a real screen. A table built synchronously does not reproduce
    // this — that is why it went unnoticed.
    final rows = Future<List<String>>.delayed(
      const Duration(milliseconds: 1),
      () => const ['BX 09 LM NW'],
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: Card(
              child: FutureBuilder<List<String>>(
                future: rows,
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const SizedBox(
                        height: 60,
                        child: Center(child: CircularProgressIndicator()));
                  }
                  return MlWideTable(
                    minWidth: 900,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final r in snap.data!)
                          SizedBox(height: 60, child: Text(r)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ));

    await pumpForCapture(tester);

    final thumb = AppTheme.darkTheme.scrollbarTheme.thumbColor!
        .resolve(<WidgetState>{})!;
    final surface = AppTheme.darkTheme.cardTheme.color ??
        AppTheme.darkTheme.colorScheme.surface;
    // What the eye receives: the thumb's alpha composited onto the card.
    final expected = Color.from(
      alpha: 1,
      red: thumb.r * thumb.a + surface.r * (1 - thumb.a),
      green: thumb.g * thumb.a + surface.g * (1 - thumb.a),
      blue: thumb.b * thumb.a + surface.b * (1 - thumb.a),
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first);
    late Uint8List data;
    late int w, h;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      data = bytes!.buffer.asUint8List();
      w = image.width;
      h = image.height;
    });

    // The longest unbroken horizontal run of pixels near the thumb's composited
    // colour. A run is the right measure: text antialiasing scatters a handful
    // of similar pixels across a row, a thumb is a solid bar.
    var longest = 0;
    for (var y = 0; y < h; y++) {
      var run = 0;
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final near = (data[i] - (expected.r * 255)).abs() < 12 &&
            (data[i + 1] - (expected.g * 255)).abs() < 12 &&
            (data[i + 2] - (expected.b * 255)).abs() < 12;
        run = near ? run + 1 : 0;
        if (run > longest) longest = run;
      }
    }

    // The viewport is 400 of 900, so the thumb is roughly 4/9 of the track.
    expect(longest, greaterThan(100),
        reason: 'no bar of the thumb colour was painted. The Scrollbar is in '
            'the tree and its colour is legible — both are asserted above — so '
            'this is the capture schedule finishing before the fade does, and '
            'every render taken with it shows a truncated table with no '
            'affordance. Longest run found: $longest px.');
  });
}
