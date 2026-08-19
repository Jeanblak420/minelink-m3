// The accent moved at S5-5, and white text sat on it in four places. Nobody
// noticed because nothing measured it.
//
// This pins the pairing. If the accent is ever retuned again — and it will be,
// design systems move — this test fails BEFORE the product ships an unreadable
// primary button, rather than after somebody squints at a screenshot.
//
// Measured against WCAG 2.1 relative luminance, the same formula the standard
// defines. Not a vibe check.

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio, 1.0 (identical) … 21.0 (black on white).
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('accent legibility', () {
    test('the primary button label is readable on the accent', () {
      // 4.5:1 is the WCAG AA threshold for normal-size text. Button labels are
      // bold but not large, so the normal threshold is the honest one to hold.
      final ratio = _contrast(MlTokens.navy950, MlTokens.accent);
      expect(
        ratio,
        greaterThanOrEqualTo(4.5),
        reason: 'Primary button ink on the accent measures '
            '${ratio.toStringAsFixed(2)}:1, below the 4.5:1 WCAG AA floor. '
            'If the accent has just been retuned, the FOREGROUND needs to move '
            'with it — see MlButton primary and AppTheme.filledButtonTheme.',
      );
    });

    test('white on the accent is still the wrong choice, and stays refused',
        () {
      // The regression this file exists for. White measured 1.81:1 on #22D3EE
      // and 2.44:1 on the previous #00B5D8 — it was never right, on either.
      // Asserted as a FAILURE so that if somebody makes the accent dark enough
      // for white to work, this test tells them to revisit the pairing rather
      // than silently leaving dark ink on a dark button.
      final ratio = _contrast(const Color(0xFFFFFFFF), MlTokens.accent);
      expect(
        ratio,
        lessThan(4.5),
        reason: 'White now passes on the accent (${ratio.toStringAsFixed(2)}:1). '
            'The accent must have become much darker. Re-check the primary '
            'button foreground — dark ink may no longer be the right call.',
      );
    });

    test('the accent chip is readable in BOTH themes', () {
      // The pairing the product actually renders — MlTone.accent's fg on its
      // own well — not an invented button. My first version of this test
      // asserted white on accentHover, which is a pairing nothing draws; it
      // failed, and the test was wrong rather than the code. Assert what ships.
      for (final brightness in Brightness.values) {
        final tone = MlTone.accent.colors(brightness);
        // The dark well is translucent, so compose it over the canvas first —
        // measuring against a transparent colour measures nothing.
        final bg = Color.alphaBlend(
          tone.bg,
          MlSemantic.from(brightness).surfaceApp,
        );
        final ratio = _contrast(tone.fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(4.5),
          reason: '$brightness accent chip is ${ratio.toStringAsFixed(2)}:1 — '
              'chip and badge text is small, so the 4.5:1 normal-text floor '
              'applies, not the 3:1 large-text one.',
        );
      }
    });

    test('body text is readable on every app surface', () {
      // Cheap breadth: the pairings a user reads for hours.
      for (final (name, semantic) in <(String, MlSemantic)>[
        ('light', MlSemantic.from(Brightness.light)),
        ('dark', MlSemantic.from(Brightness.dark)),
      ]) {
        final onCard = _contrast(semantic.textBody, semantic.surfaceCard);
        expect(onCard, greaterThanOrEqualTo(4.5),
            reason: '$name: body text on a card is '
                '${onCard.toStringAsFixed(2)}:1');

        final strong = _contrast(semantic.textStrong, semantic.surfaceApp);
        expect(strong, greaterThanOrEqualTo(4.5),
            reason: '$name: strong text on the app surface is '
                '${strong.toStringAsFixed(2)}:1');
      }
    });
  });
}
