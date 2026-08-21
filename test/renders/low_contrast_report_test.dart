// The instrument that measures every other render has to be measured too.
//
// `low_contrast_report.dart` decides what ~1,800 findings mean, and it has
// been wrong four times now: once taking the ink from the raster, once letting
// a paragraph scrolled out of view report against whatever was painted where
// it would have been, and twice in the pair this file pins - a paragraph that
// is COVERED doing the same, and a TRANSLUCENT ink never being excluded from
// its own ground.
//
// Every test below builds a scene whose right answer is known by
// construction, so a regression shows up as a wrong number rather than as a
// plausible-looking finding on a screen nobody re-checks.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';

import '../test_helpers/real_fonts.dart';
import 'low_contrast_report.dart';

/// The app's UI face, named explicitly on every string below.
///
/// `loadRealFonts()` alone is not enough: it REGISTERS the families, but a
/// `TextStyle` that names no family still resolves to the test fallback, whose
/// glyphs are solid one-em boxes. In that font "Seats used" at 14px fills its
/// own paragraph box edge to edge, so the box contains no ground to measure
/// and the report correctly declines to guess - which reads exactly like the
/// report being broken. CLAUDE.md §7 and §10.5, arrived at the hard way again.
const String _face = 'PlusJakartaSans';

Future<List<LowContrastHit>> _run(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(400, 400),
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: SizedBox.fromSize(size: size, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return reportLowContrast(tester, key, 'unit', size);
}

Widget _text(Color color, {String text = 'Seats used', double size = 14}) =>
    Text(
      text,
      style: TextStyle(color: color, fontSize: size, fontFamily: _face),
    );

/// Text of [color] on a [ground] fill, filling the scene.
Widget _slab({
  required Color ground,
  required Color color,
  String text = 'Seats used',
}) =>
    ColoredBox(
      color: ground,
      child: Center(child: _text(color, text: text)),
    );

// The real pair the whole §4.2 effort turns on: `onSurfaceVariant` at 62%
// alpha on the M3 card surface. It paints #627084 and measures 3.38:1.
const _cardSurface = Color(0xFF111C30);
const _brightSurface = Color(0xFF1C2C46);
const _onSurfaceVariant = Color(0xFF94A3B8);
const _faintOnCard = Color(0xFF627084);

void main() {
  setUpAll(() async {
    await loadRealFonts();
  });

  // ── The report must find what is genuinely faint ───────────────────────
  //
  // Without this, every "reports nothing" expectation below would be
  // satisfied by an instrument that reports nothing at all - which is exactly
  // the failure the rest of the file exists to prevent.
  group('it finds what is really there', () {
    testWidgets('reports a genuinely faint string', (tester) async {
      final hits = await _run(
        tester,
        _slab(ground: _cardSurface, color: _faintOnCard),
      );

      expect(hits, hasLength(1));
      expect(hits.single.text, 'Seats used');
      expect(hits.single.ratio, closeTo(3.38, 0.05));
      expect(hits.single.inkHex, '#627084');
      expect(hits.single.groundHex, '#111C30');
      expect(hits.single.required, 4.5);
    });

    testWidgets('stays quiet on a string that passes', (tester) async {
      final hits = await _run(
        tester,
        _slab(ground: _cardSurface, color: const Color(0xFFEAF2FF)),
      );
      expect(hits, isEmpty);
    });

    testWidgets('asks 3.0 of large text and 4.5 of body text', (tester) async {
      // #627084 is 3.38:1 - under the body bar, over the large-text one. The
      // same colour must therefore be a finding at 14px and not at 28px, and
      // if the size rule ever collapses, exactly one of these fails.
      final body = await _run(
        tester,
        ColoredBox(
          color: _cardSurface,
          child: Center(child: _text(_faintOnCard)),
        ),
      );
      final large = await _run(
        tester,
        ColoredBox(
          color: _cardSurface,
          child: Center(child: _text(_faintOnCard, size: 28)),
        ),
      );

      expect(body, hasLength(1), reason: '3.38:1 at 14px is under AA');
      expect(body.single.required, 4.5);
      expect(large, isEmpty, reason: '3.38:1 at 28px is large text, AA is 3.0');
    });
  });

  // ── A TRANSLUCENT ink is the app's actual faint mechanism ──────────────
  //
  // `textFaint` is `onSurfaceVariant.withValues(alpha: 0.62)`, and it accounts
  // for 657 of the findings on its own. It reaches the raster as a colour that
  // depends on what it landed on, so an exclusion that matches the DECLARED
  // colour excludes nothing: #94A3B8 at 62% paints #627084, fifty units away
  // in every channel. Where the glyphs also filled their box the mode then
  // became the TEXT, and the report measured the ink against itself.
  group('a translucent ink', () {
    testWidgets('reads the same as the opaque colour it paints',
        (tester) async {
      final translucent = await _run(
        tester,
        _slab(
          ground: _cardSurface,
          color: _onSurfaceVariant.withValues(alpha: 0.62),
        ),
      );
      final opaque = await _run(
        tester,
        _slab(ground: _cardSurface, color: _faintOnCard),
      );

      expect(translucent, hasLength(1),
          reason: 'a 62%-alpha slate on the card surface IS 3.38:1 and must '
              'be reported, not swallowed');
      expect(translucent.single.inkHex, opaque.single.inkHex);
      expect(translucent.single.groundHex, '#111C30');
      expect(translucent.single.ratio, closeTo(opaque.single.ratio, 0.001),
          reason: 'the declared colour differs, the painted pixels do not');
    });

    testWidgets('is composited onto the ground it actually sits on',
        (tester) async {
      // The same ink at the same alpha on two grounds. If the report used the
      // declared colour, both would read identically.
      Future<LowContrastHit> on(Color ground) async {
        final hits = await _run(
          tester,
          _slab(
            ground: ground,
            color: _onSurfaceVariant.withValues(alpha: 0.62),
          ),
        );
        expect(hits, hasLength(1), reason: 'expected one finding on $ground');
        return hits.single;
      }

      final onCard = await on(_cardSurface);
      final onBright = await on(_brightSurface);

      expect(onCard.ratio, closeTo(3.38, 0.05));
      expect(onBright.ratio, closeTo(3.03, 0.05));
      expect(onCard.ratio, greaterThan(onBright.ratio),
          reason: 'a lighter ground must read as WORSE for a faint slate');
      expect(onCard.inkHex, isNot(onBright.inkHex),
          reason: 'the same declared colour paints two different colours');
    });

    testWidgets('never measures the ink against itself', (tester) async {
      // The self-eating measurement, in the shape that produced it: a tight
      // box where the glyphs are most of the pixels. Whatever it reports, the
      // ground must not BE the ink.
      final hits = await _run(
        tester,
        ColoredBox(
          color: _cardSurface,
          child: Center(
            child: SizedBox(
              width: 60,
              height: 22,
              child: ColoredBox(
                color: _cardSurface,
                child: Center(
                  child: _text(
                    _onSurfaceVariant.withValues(alpha: 0.62),
                    text: '+103%',
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      for (final h in hits) {
        expect(h.groundHex, isNot(h.inkHex),
            reason: 'ground and ink identical means the box was measured '
                'against its own text');
        expect(h.ratio, greaterThan(1.05),
            reason: 'a ratio at 1:1 is a measurement failure, not a finding');
      }
    });
  });

  // ── A paragraph the raster never shows is not a finding ────────────────
  group('a paragraph that is clipped away', () {
    testWidgets('scrolled out of a viewport is not reported', (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      // What is painted in the window is DELIBERATELY a different scene from
      // the one the scrolled-away string would sit on: near-black ink on the
      // brand cyan, which is the exact pairing that fools the distance rule.
      // If the window simply repeated the card surface, the string's own box
      // would contain no ink pixels and it would be rejected for that reason
      // instead - leaving the clip rule untested and the test green with the
      // clip rule removed. Measured: that is what the first version did.
      // Getting this scene wrong is easy, and a wrong one passes for the wrong
      // reason. Two earlier versions did:
      //
      //   * scrolled 3,000px away, so the OFF-IMAGE guard rejected it first;
      //   * scrolled onto flat sheet colour, so the "no ink pixels" guard did.
      //
      // Both left the clip rule untested, and removing it left the test green.
      // So the clipped string is laid out ON the image and exactly on top of a
      // string that IS visible and IS faint - same ink, same ground. Every
      // other guard now says "measure this", and only the clip rule knows the
      // pixels belong to the other paragraph.
      final hits = await _run(
        tester,
        Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: _cardSurface)),
            // Visible, genuinely faint, at y = 200.
            Positioned(
              left: 0,
              top: 200,
              width: 400,
              child: Center(child: _text(_faintOnCard, text: 'Loads moved')),
            ),
            // A 60px window whose second child is laid out at y = 200 too, and
            // clipped away.
            Positioned(
              left: 0,
              top: 0,
              width: 400,
              height: 60,
              child: ListView(
                controller: controller,
                children: [
                  const SizedBox(height: 200),
                  Center(child: _text(_faintOnCard)),
                ],
              ),
            ),
          ],
        ),
      );

      expect(hits.map((h) => h.text), contains('Loads moved'),
          reason: 'the VISIBLE faint string must still be found, or this '
              'scene proves nothing');
      expect(hits.where((h) => h.text == 'Seats used'), isEmpty,
          reason: 'it is laid out at y=200 and clipped away by a 60px '
              'viewport; the pixels there belong to "Loads moved"');
    });

    testWidgets('is measured over its VISIBLE part only', (tester) async {
      // The bottom half of the text runs past the clip. Whatever the report
      // makes of it, it must not sample below the clip - that is where a
      // different widget is painted.
      final hits = await _run(
        tester,
        Stack(
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0xFF060F20))),
            Positioned(
              left: 0,
              top: 0,
              width: 400,
              height: 200,
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  maxHeight: 400,
                  child: ColoredBox(
                    color: _cardSurface,
                    child: SizedBox(
                      width: 400,
                      height: 400,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 190),
                        child: _text(_faintOnCard),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );

      for (final h in hits) {
        expect(h.rect.bottom, lessThanOrEqualTo(200.0),
            reason: 'the report sampled past the clip at y=200');
      }
    });
  });

  // ── A paragraph that is COVERED is not a finding either ────────────────
  //
  // The pair the clip test cannot catch: nothing is clipped, something opaque
  // is simply painted on top. This is the real scene reduced - the driver HUD
  // under the hazard sheet's `Report hazard` button, which produced four
  // findings at 1.42:1 and one at 1.20:1 for text that is not on the screen.
  group('a paragraph something opaque is painted over', () {
    // The covering ink has to fall INSIDE the covered paragraph's box, or the
    // scene proves nothing: a box holding nothing but flat sheet colour is
    // rejected for having no ink pixels at all, whatever the distance rule
    // says. The first version of this test put the HUD label at x=100 and the
    // sheet's label at x=150-250, so they never overlapped and disabling the
    // distance rule left the test green. Both are centred now, which is also
    // what the real screen does - the sheet's button sits over the HUD.
    Widget covered({required Color sheet, required Color sheetInk}) => Stack(
          alignment: Alignment.center,
          children: [
            // The HUD label, laid out and then buried.
            _text(_onSurfaceVariant, text: 'Time left', size: 11),
            Positioned.fill(
              child: ColoredBox(
                color: sheet,
                child: Center(
                  child: _text(sheetInk, text: 'Report hazard', size: 16),
                ),
              ),
            ),
          ],
        );

    testWidgets('is not reported', (tester) async {
      final hits = await _run(
        tester,
        covered(sheet: const Color(0xFF22D3EE), sheetInk: const Color(0xFF020617)),
      );

      expect(hits.where((h) => h.text == 'Time left'), isEmpty,
          reason: 'the covering label is 98% of the way from the cyan ground '
              'to the slate ink, so "closer to ink than to ground" passes it. '
              'Only its DISTANCE from that line rejects it.');
    });

    testWidgets('while the thing painted OVER it still is, when it is faint',
        (tester) async {
      // The other direction, so the exclusion above cannot be satisfied by an
      // instrument that has gone blind to covered scenes generally.
      final hits = await _run(
        tester,
        covered(sheet: _cardSurface, sheetInk: _faintOnCard),
      );

      expect(hits.map((h) => h.text), contains('Report hazard'));
      expect(hits.where((h) => h.text == 'Time left'), isEmpty);
    });
  });

  // ── A page a MODAL has been opened over is not a finding ───────────────
  //
  // A scrim dims the ink and the ground together, which compresses the ratio
  // between them: the chat composer's `Send` is a 10.43:1 pairing that
  // measures 2.53:1 once a dialog is over it. Neither other guard reaches
  // this - nothing is clipped, and the scrim moves ink and ground along
  // nearly the same line so the distance rule passes them.
  group('a page with a dialog open over it', () {
    testWidgets('is not reported, and the DIALOG still is', (tester) async {
      final key = GlobalKey();
      const size = Size(400, 400);
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The boundary wraps the whole APP, not the Scaffold: a dialog renders
      // in the Navigator's Overlay, which is above the Scaffold, so a
      // boundary inside the page captures a raster the dialog is not in - and
      // then the report samples the page's pixels for the dialog's text and
      // reports nothing. Measured: that is what the first version did.
      await tester.pumpWidget(RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          // The app's real theme, not stock Material's - the
          // `test-renders-under-the-app-theme` guard, and it is right even
          // here: this test names its own colours and font family, but a
          // bare MaterialApp would still hand the Dialog stock Material's
          // surface tint, which is part of the ground being measured.
          theme: AppTheme.build(Brightness.dark),
          home: Scaffold(
            backgroundColor: _cardSurface,
            // A pairing that is comfortably legible unscrimmed - so if it is
            // reported, it is ONLY because the scrim dimmed it.
            body: Center(
              child: ColoredBox(
                color: const Color(0xFF22D3EE),
                child: _text(const Color(0xFF020617), text: 'Send'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final before = await reportLowContrast(tester, key, 'unit', size);
      expect(before.where((h) => h.text == 'Send'), isEmpty,
          reason: 'unscrimmed, navy on the accent is 10.4:1');

      // Now open a dialog over it.
      final ctx = tester.element(find.byType(Scaffold));
      unawaited(showDialog<void>(
        context: ctx,
        builder: (_) => Dialog(
          backgroundColor: _cardSurface,
          child: SizedBox(
            width: 200,
            height: 120,
            child: Center(child: _text(_faintOnCard, text: 'Group name')),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final after = await reportLowContrast(tester, key, 'unit', size);
      expect(after.where((h) => h.text == 'Send'), isEmpty,
          reason: 'the scrim crushed it to ~2.5:1, but it is inert behind a '
              'barrier and WCAG 1.4.3 is about text a reader is meant to read');
      expect(after.map((h) => h.text), contains('Group name'),
          reason: 'the DIALOG is the current route and must still be measured '
              '- otherwise this guard has gone blind to modal screens, which '
              'is a large part of the product');
    });
  });

  // ── An icon is not a string ────────────────────────────────────────────
  testWidgets('a private-use glyph is not measured as text', (tester) async {
    final hits = await _run(
      tester,
      ColoredBox(
        color: _cardSurface,
        child: const Center(
          child: Icon(Icons.lock_outline_rounded, size: 12, color: _faintOnCard),
        ),
      ),
    );
    expect(hits, isEmpty);
  });

  // ── The ratchet ────────────────────────────────────────────────────────
  test('the ratchet fails a render that got fainter', () {
    // A render with no baseline entry is allowed nothing, which is what makes
    // a NEW render start clean rather than start forgiven.
    expect(() => expectNoNewLowContrast('a-render-with-no-baseline', 1),
        throwsA(isA<TestFailure>()));
    expectNoNewLowContrast('a-render-with-no-baseline', 0);
  });
}
