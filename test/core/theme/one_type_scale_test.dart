// There must be ONE type scale.
//
// MineLink had two, neither derived from the other:
//
//   MlTokens.fs*      34 / 26 / 22 / 18 / 16 / 15 / 13 / 12 / 11
//   MlTypeScale       45 / 36 / 32 / 28 / 24 / 22 / 16 / 14 / 12 / 11
//
// so `MlTokens.fsBodySm` (13) and `textTheme.bodyMedium` (14) both meant
// "small body text", 1px apart, and both appeared on the same screens. That is
// the same fault Phase 1 fixed for colour — `colorScheme.primary` and
// `MlTokens.accent` being different colours that both meant "the accent" — and
// it has exactly the same effect: the interface stops looking like one thing.
//
// The theme won, because it is what Material widgets resolve without being
// told, and because it was already the more used of the two (158 sites against
// 96). `MlTokens.fs*` are now aliases of their slots.
//
// This file is what stops them drifting apart again. It is deliberately an
// EQUALITY test rather than a "close enough" one: a 1px difference is exactly
// what the old state was, and a test that tolerated 1px would have passed
// throughout it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

void main() {
  final scale = MlTypeScale.textTheme(const Color(0xFF000000));

  group('every MlTokens size is a slot in the theme', () {
    final pairs = <String, (double, TextStyle?)>{
      'fsDisplay → headlineLarge': (MlTokens.fsDisplay, scale.headlineLarge),
      'fsH1 → headlineSmall': (MlTokens.fsH1, scale.headlineSmall),
      'fsH2 → titleLarge': (MlTokens.fsH2, scale.titleLarge),
      'fsH3 → titleMedium': (MlTokens.fsH3, scale.titleMedium),
      'fsTitle → titleMedium': (MlTokens.fsTitle, scale.titleMedium),
      'fsBody → bodyLarge': (MlTokens.fsBody, scale.bodyLarge),
      'fsBodySm → bodyMedium': (MlTokens.fsBodySm, scale.bodyMedium),
      'fsLabel → bodySmall': (MlTokens.fsLabel, scale.bodySmall),
      'fsMicro → labelSmall': (MlTokens.fsMicro, scale.labelSmall),
    };

    pairs.forEach((name, pair) {
      test(name, () {
        final (token, slot) = pair;
        expect(slot, isNotNull, reason: '$name: the slot does not exist');
        expect(
          token,
          slot!.fontSize,
          reason: '$name — the token says $token and the theme slot says '
              '${slot.fontSize}. Two type scales is how a product stops '
              'looking like one product. Move the token, or move the slot, but '
              'do not let them disagree.',
        );
      });
    });
  });

  test('the scale has no half-point sizes', () {
    // A half-point belongs to neither scale and is always somebody nudging a
    // number until one string fitted one box. `no-half-point-font-size` guards
    // lib/; this guards the scale itself, which that guard exempts.
    final sizes = <double?>[
      scale.displayLarge?.fontSize,
      scale.displayMedium?.fontSize,
      scale.displaySmall?.fontSize,
      scale.headlineLarge?.fontSize,
      scale.headlineMedium?.fontSize,
      scale.headlineSmall?.fontSize,
      scale.titleLarge?.fontSize,
      scale.titleMedium?.fontSize,
      scale.titleSmall?.fontSize,
      scale.bodyLarge?.fontSize,
      scale.bodyMedium?.fontSize,
      scale.bodySmall?.fontSize,
      scale.labelLarge?.fontSize,
      scale.labelMedium?.fontSize,
      scale.labelSmall?.fontSize,
      MlTokens.fsDisplay,
      MlTokens.fsH1,
      MlTokens.fsH2,
      MlTokens.fsH3,
      MlTokens.fsTitle,
      MlTokens.fsBody,
      MlTokens.fsBodySm,
      MlTokens.fsLabel,
      MlTokens.fsMicro,
    ];
    for (final s in sizes) {
      expect(s, isNotNull);
      expect(s! % 1, 0,
          reason: '$s is a half-point size; the scale has no such step');
    }
  });

  test('the shipped theme carries this scale, not Material defaults', () {
    // The tokens could agree with MlTypeScale while ThemeData shipped
    // something else entirely — which is precisely how the two colour systems
    // stayed apart for so long.
    for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
      expect(theme.textTheme.bodyMedium?.fontSize, MlTokens.fsBodySm);
      expect(theme.textTheme.titleMedium?.fontSize, MlTokens.fsTitle);
      expect(theme.textTheme.labelSmall?.fontSize, MlTokens.fsMicro);
      // And in the app's own faces, not Material's.
      expect(theme.textTheme.bodyMedium?.fontFamily, MlTokens.fontSans);
      expect(theme.textTheme.displayLarge?.fontFamily, MlTokens.fontSerif);
    }
  });
}
