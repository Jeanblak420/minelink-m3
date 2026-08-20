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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_wide_table.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import '../test_helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);
  _contrastTests();

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
/// This asserts the COLOUR, not the painting. That the thumb paints at all is
/// covered above, and separately by the render harness: `shoot()` had to learn
/// to pump twice, because `RawScrollbar` fades in from a post-frame callback
/// and until 2026-08-20 no scrollbar had ever appeared in any render.
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
