// The ink ladders, as arithmetic rather than as a note asking to be kept.
//
// Two things kept going wrong and neither was visible in a render:
//
//   1. A quiet rung was set to a value that reads at AA for LARGE text and
//      then used for 9-13px labels, where the bar is 4.5:1. That happened
//      twice to the same tokens, and the second time the fix had to move
//      `inkMid` as well, because below the floor there was room for one step
//      and the ladder wanted three.
//   2. `MlGlass` and `MlOverviewTokens` carry the SAME ladder, deliberately,
//      and a fix to one that missed the other would split them silently. The
//      old comment asked a reader to remember; this asks the machine.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/design/tokens/ml_auth_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_chrome.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_scheme.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color ink, Color ground) {
  final a = _lum(ink), b = _lum(ground);
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

/// Every dark ground a quiet rung is measured on, brightest last.
///
/// Taken from the LOW CONTRAST report rather than from the token file: the
/// ladder is used on surfaces beyond `MlGlass`'s own panels, and the brightest
/// one is what decides whether a value is legible.
const _darkGrounds = <Color>[
  Color(0xFF060B15), // MlGlass bg0 / page
  Color(0xFF0A1220),
  Color(0xFF0A1424), // scheme.surface
  Color(0xFF0E1728), // MlGlass panel
  Color(0xFF0F1A2E),
  Color(0xFF111C30), // scheme.surfaceContainer - the card
  Color(0xFF131F35), // MlGlass panel2
  Color(0xFF16243C), // surfaceContainerHigh
  Color(0xFF182A3C),
  Color(0xFF1C2C46), // surfaceContainerHighest - the worst case
];

const _lightGrounds = <Color>[
  Color(0xFFFFFFFF), // panel
  Color(0xFFFAFDFE),
  Color(0xFFF8FAFC),
  Color(0xFFF3F6FA),
  Color(0xFFF1F5F9),
  Color(0xFFEEF2F8), // bg0
  Color(0xFFE4EBF1),
  Color(0xFFE2EAF1), // the worst case
];

/// WCAG AA for text below 24px, which is every one of these rungs.
const _bodyAA = 4.5;

void main() {
  group('every rung that writes text is legible on every ground it lands on',
      () {
    void checkLadder(String name, Map<String, Color> rungs, List<Color> grounds) {
      for (final entry in rungs.entries) {
        test('$name.${entry.key}', () {
          for (final ground in grounds) {
            final r = contrast(entry.value, ground);
            expect(
              r,
              greaterThanOrEqualTo(_bodyAA),
              reason: '$name.${entry.key} '
                  '(#${entry.value.toARGB32().toRadixString(16).substring(2).toUpperCase()}) '
                  'is ${r.toStringAsFixed(2)}:1 on '
                  '#${ground.toARGB32().toRadixString(16).substring(2).toUpperCase()}. '
                  'These rungs write 9-13px labels, so the bar is 4.5:1, not '
                  'the 3.0 that AA allows large text. Use '
                  '`py -3 tool/contrast_calc.py solve-tint <ink> <ground> 4.6` '
                  'to derive a value rather than nudging one.',
            );
          }
        });
      }
    }

    checkLadder('MlGlass.dark', {
      'inkHi': MlGlass.dark.inkHi,
      'ink': MlGlass.dark.ink,
      'inkMid': MlGlass.dark.inkMid,
      'inkLo': MlGlass.dark.inkLo,
      'inkXlo': MlGlass.dark.inkXlo,
    }, _darkGrounds);

    checkLadder('MlGlass.light', {
      'inkHi': MlGlass.light.inkHi,
      'ink': MlGlass.light.ink,
      'inkMid': MlGlass.light.inkMid,
      'inkLo': MlGlass.light.inkLo,
      'inkXlo': MlGlass.light.inkXlo,
    }, _lightGrounds);

    // The sign-in screen. It has NO light variant by design, which is exactly
    // why it goes unmeasured - a light-mode sweep never opens it - and it is
    // the first surface every user of this product sees. The field well
    // (#12374A) is the ground the first pass missed: it is lighter than the
    // card, and the label over every input sits on it.
    checkLadder('MlAuth', {
      'inkHi': MlAuth.inkHi,
      'ink': MlAuth.ink,
      'inkMid': MlAuth.inkMid,
      'inkLo': MlAuth.inkLo,
      'inkXlo': MlAuth.inkXlo,
    }, const [
      Color(0xFF020408), // the page
      Color(0xFF0A121F), // the card
      Color(0xFF0B1220),
      Color(0xFF12374A), // the field well - the worst case
    ]);

    test('MlSemantic.textFaint, both brightnesses', () {
      for (final (brightness, grounds) in [
        (Brightness.dark, _darkGrounds),
        (Brightness.light, _lightGrounds),
      ]) {
        final s = MlSemantic.fromScheme(MlScheme.of(brightness));
        for (final ground in grounds) {
          final r = contrast(s.textFaint, ground);
          expect(r, greaterThanOrEqualTo(_bodyAA),
              reason: 'textFaint in $brightness is ${r.toStringAsFixed(2)}:1 '
                  'on #${ground.toARGB32().toRadixString(16).substring(2).toUpperCase()}. '
                  'It used to be onSurfaceVariant at 62% alpha, which was 916 '
                  'of the 1,798 low-contrast strings; it must stay its own '
                  'colour, not go back to being an alpha.');
        }
      }
    });

    // BOTH chrome variants, because the light one is not the dark one
    // inverted — the console's rail stays navy in light mode — and the two
    // section-label values differ, so a search for the dark hex does not find
    // the light line. That is how the first pass fixed one and left 17
    // strings behind in the other.
    for (final (name, chrome) in [
      ('dark', MlChrome.dark),
      ('light', MlChrome.light),
    ]) {
      test('MlChrome.$name.railSectionLabel on the rail it is painted on', () {
        // The rail is a gradient; its TOP stop is the lighter end and so the
        // harder one for text sitting on it.
        for (final ground in [chrome.railTop, chrome.railBottom]) {
          final r = contrast(chrome.railSectionLabel, ground);
          expect(r, greaterThanOrEqualTo(_bodyAA),
              reason: 'the console rail section headings are 11px, and this '
                  'is ${r.toStringAsFixed(2)}:1');
        }
      });

      test('MlChrome.$name.railLabel and railIcon', () {
        for (final ground in [chrome.railTop, chrome.railBottom]) {
          expect(contrast(chrome.railLabel, ground),
              greaterThanOrEqualTo(_bodyAA),
              reason: 'a rail destination label must be readable');
          expect(contrast(chrome.railIcon, ground), greaterThanOrEqualTo(3.0),
              reason: 'an icon is a graphic, so the bar is 3:1');
        }
      });
    }
  });

  // A tone's whole job is to be legible on its OWN tint. `MlTone` hands out
  // the pair from one call, so the two halves cannot disagree - unless a
  // value drifts, which is what this catches. `error` was the one that had:
  // #DC2626 on #FEE2E2 is 3.95:1, and it writes EXPIRED / DECLINED / FAILED.
  group('every MlTone reads on its own well', () {
    for (final tone in MlTone.values) {
      for (final brightness in Brightness.values) {
        test('$tone in $brightness', () {
          final c = tone.colors(brightness);
          // `bg` is often translucent, so composite it onto the surface it
          // would sit on before measuring - a 20%-alpha red on navy is not
          // the red the token names.
          final surface = MlScheme.of(brightness).surfaceContainer;
          final well = Color.alphaBlend(c.bg, surface);
          final r = contrast(c.fg, well);
          expect(r, greaterThanOrEqualTo(_bodyAA),
              reason: '$tone in $brightness is ${r.toStringAsFixed(2)}:1 - a '
                  'status badge is 11-12px, so the bar is 4.5. Both halves '
                  'come from one call, so fix the TOKEN, not the call site.');
        });
      }
    }
  });

  group('the ladder still reads as distinct steps', () {
    void checkOrdered(String name, List<Color> rungs, Color ground) {
      test(name, () {
        for (var i = 0; i + 1 < rungs.length; i++) {
          final a = contrast(rungs[i], ground);
          final b = contrast(rungs[i + 1], ground);
          expect(a, greaterThan(b),
              reason: '$name rung $i must read stronger than rung ${i + 1}; '
                  'a ladder whose rungs are out of order, or equal, is not a '
                  'hierarchy. Raising a low rung to reach 4.5 without moving '
                  'the one above it is how they collapse.');
          // Distinct enough to be seen, not just distinct enough to compare.
          expect(a / b, greaterThan(1.06),
              reason: '$name rungs $i and ${i + 1} are '
                  '${a.toStringAsFixed(2)} and ${b.toStringAsFixed(2)} - too '
                  'close to tell apart.');
        }
      });
    }

    checkOrdered(
      'MlGlass.dark',
      [
        MlGlass.dark.inkHi,
        MlGlass.dark.ink,
        MlGlass.dark.inkMid,
        MlGlass.dark.inkLo,
        MlGlass.dark.inkXlo,
      ],
      const Color(0xFF0E1728),
    );

    checkOrdered(
      'MlGlass.light',
      [
        MlGlass.light.inkHi,
        MlGlass.light.ink,
        MlGlass.light.inkMid,
        MlGlass.light.inkLo,
        MlGlass.light.inkXlo,
      ],
      const Color(0xFFFFFFFF),
    );
  });

  // `MlOverviewTokens` carries the same ladder on purpose. Fixing one and
  // missing the other is the exact mistake the old comment was written to
  // prevent, and a comment cannot fail a build.
  group('MlOverviewTokens carries the same ladder as MlGlass', () {
    test('dark', () {
      expect(MlOv.dark.inkHi, MlGlass.dark.inkHi);
      expect(MlOv.dark.ink, MlGlass.dark.ink);
      expect(MlOv.dark.inkMid, MlGlass.dark.inkMid);
      expect(MlOv.dark.inkLo, MlGlass.dark.inkLo);
      expect(MlOv.dark.inkXlo, MlGlass.dark.inkXlo);
    });

    test('light', () {
      expect(MlOv.light.inkHi, MlGlass.light.inkHi);
      expect(MlOv.light.ink, MlGlass.light.ink);
      expect(MlOv.light.inkMid, MlGlass.light.inkMid);
      expect(MlOv.light.inkLo, MlGlass.light.inkLo);
      expect(MlOv.light.inkXlo, MlGlass.light.inkXlo);
    });
  });
}
