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
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_auth_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

void main() {
  _oneFaceEachTests();
  _mlTextTests();

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

/// The three faces must have ONE definition each.
///
/// `MlGlass.sans/mono/display` were their own string literals —
/// 'PlusJakartaSans', 'JetBrainsMono' and 'Fraunces' spelled out a second time
/// alongside `MlTokens`. 153 uses on one side, 519 on the other, and nothing
/// keeping them in step.
///
/// The failure mode is quiet, which is what makes it worth a test: a Flutter
/// `fontFamily` that does not resolve **does not throw** — it falls back. So
/// renaming an asset in `pubspec.yaml` would have fixed one half of the product
/// and silently changed the typeface of the other, with nothing red anywhere.
/// Dart source with `//` and `/* */` comments blanked out.
///
/// Blanked rather than removed, so the remaining text keeps its offsets and a
/// failure still points at a real place in the file.
String _withoutComments(String source) {
  final out = StringBuffer();
  var i = 0;
  while (i < source.length) {
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end;
      continue;
    }
    if (source.startsWith('/*', i)) {
      final end = source.indexOf('*/', i);
      i = end < 0 ? source.length : end + 2;
      continue;
    }
    out.write(source[i]);
    i++;
  }
  return out.toString();
}

void _oneFaceEachTests() {
  group('one definition per typeface', () {
    test('MlGlass names the same faces as MlTokens', () {
      expect(MlGlass.sans, MlTokens.fontSans);
      expect(MlGlass.mono, MlTokens.fontMono);
      expect(MlGlass.display, MlTokens.fontSerif);
    });

    // MlGlass was the only one this test knew about. There are four
    // declarations of the three faces in `lib/core/design/tokens/`, and the
    // two added here spell the families out as bare string literals — MlAuth
    // because it imports nothing but Flutter by design, MlOv because it is a
    // byte-for-byte port of an external drop. Both are legitimate reasons to
    // repeat a value and neither is a reason to leave it unpinned.
    test('MlAuth names the same faces as MlTokens', () {
      expect(MlAuth.sans, MlTokens.fontSans);
      expect(MlAuth.mono, MlTokens.fontMono);
      expect(MlAuth.serif, MlTokens.fontSerif);
    });

    test('MlOv names the same faces as MlTokens', () {
      expect(MlOv.sans, MlTokens.fontSans);
      expect(MlOv.mono, MlTokens.fontMono);
      expect(MlOv.serif, MlTokens.fontSerif);
    });

    test('there is no FOURTH face left in lib/', () {
      // `kConsoleSans` was `'Sora'` — a fourth typeface, alive at seven sites
      // in the console's own dashboard widgets while the rail beside them ran
      // Plus Jakarta Sans. `mlConsoleSans`, the rail's copy of it, had already
      // become dead code, so the two halves of one screen disagreed about what
      // the console's face even was.
      //
      // This reads the source rather than a constant, because the failure it
      // guards against is somebody adding a new name, not changing an old one.
      //
      // Comments are stripped first, and that is not a nicety: the FIRST run of
      // this test failed on the comment left behind where `mlConsoleSans` used
      // to be — the sentence explaining that Sora had been retired read, to a
      // regex, as Sora still being there. A check that cannot tell code from
      // prose about the code will eventually make someone delete the prose.
      final offenders = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final text = _withoutComments(entity.readAsStringSync());
        for (final match
            in RegExp(r"""fontFamily:\s*'([^']+)'""").allMatches(text)) {
          final family = match.group(1)!;
          if (family == MlTokens.fontSans ||
              family == MlTokens.fontMono ||
              family == MlTokens.fontSerif) {
            continue;
          }
          offenders.add('${entity.path}: $family');
        }
        for (final match
            in RegExp(r"""=\s*'(Sora|Inter|Roboto|Instrument Serif)'""")
                .allMatches(text)) {
          offenders.add('${entity.path}: ${match.group(1)}');
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'A fourth typeface in lib/. Three faces, three jobs '
            '(docs/design-reference.md §3). Every one of these renders '
            'beside text in one of the sanctioned faces:\n'
            '${offenders.join('\n')}',
      );
    });

    test('and those three names are the ones pubspec declares', () {
      // If this fails the app renders in a fallback face and nothing throws.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      for (final family in [
        MlTokens.fontSans,
        MlTokens.fontMono,
        MlTokens.fontSerif,
      ]) {
        expect(pubspec, contains('family: $family'),
            reason: '$family is used as a fontFamily but pubspec.yaml declares '
                'no such family. Flutter falls back silently, so this is '
                'invisible at runtime.');
      }
    });
  });
}

/// `MlText` — the scale as a screen reaches for it.
///
/// The reason it exists is that a `TextStyle` written from scratch carries only
/// what is written into it: `height` and `letterSpacing` come from whatever
/// `DefaultTextStyle` is in scope, which inside a `Scaffold` is `bodyMedium`.
/// So a hand-written 15px w800 conversation title was drawn with **body**
/// metrics — line height 1.43 where a title wants 1.27, tracking +0.25 where a
/// bold title wants -0.1. Nearly right, at ~500 sites.
///
/// These tests are about the two claims the class makes that a caller relies on
/// and cannot check: that every slot is non-null, and that an editorial rung
/// sits in the same line box as the sans title of its own size.
void _mlTextTests() {
  group('MlText', () {
    late MlText type;

    setUp(() {
      // Built from the shipped theme rather than a hand-made one, so this
      // cannot pass against a scale the app does not actually render.
      type = MlText.forTheme(AppTheme.darkTheme.textTheme);
    });

    test('every slot is non-null', () {
      // The whole point of the class: `TextTheme`'s fields are `TextStyle?`,
      // this app never leaves one null, and deciding that once here is what
      // keeps ~500 call sites from each ending in a `!` nobody can verify.
      final slots = <String, TextStyle>{
        'displayLarge': type.displayLarge,
        'displayMedium': type.displayMedium,
        'displaySmall': type.displaySmall,
        'headlineLarge': type.headlineLarge,
        'headlineMedium': type.headlineMedium,
        'headlineSmall': type.headlineSmall,
        'titleLarge': type.titleLarge,
        'titleMedium': type.titleMedium,
        'titleSmall': type.titleSmall,
        'bodyLarge': type.bodyLarge,
        'bodyMedium': type.bodyMedium,
        'bodySmall': type.bodySmall,
        'labelLarge': type.labelLarge,
        'labelMedium': type.labelMedium,
        'labelSmall': type.labelSmall,
        'editorialLarge': type.editorialLarge,
        'editorialMedium': type.editorialMedium,
        'editorialSmall': type.editorialSmall,
        'overline': type.overline,
      };
      slots.forEach((name, style) {
        expect(style.fontSize, isNotNull, reason: '$name has no size');
        expect(style.height, isNotNull,
            reason: '$name states no line height, which is the one thing '
                'MlText exists to guarantee — it would inherit whatever '
                'DefaultTextStyle happened to be in scope, exactly as the '
                'hand-written literals did.');
        expect(style.fontFamily, isNotNull, reason: '$name names no face');
      });
    });

    test('an editorial rung shares the line box of its sans twin', () {
      // A serif title and a sans title on the same row must sit on the same
      // baseline; that is the whole reason the rungs were pitched at 24/20/16
      // rather than at whatever the twenty existing sites happened to use.
      expect(type.editorialLarge.fontSize, type.headlineSmall.fontSize);
      expect(type.editorialLarge.height, type.headlineSmall.height);
      expect(type.editorialSmall.fontSize, type.titleMedium.fontSize);
      expect(type.editorialSmall.height, type.titleMedium.height);
      // editorialMedium has no sans twin at 20 and interpolates between them.
      expect(type.editorialMedium.fontSize, 20);
      expect(type.editorialMedium.height! * 20, 26);
    });

    test('the editorial rungs are the serif, and are NOT tabular', () {
      for (final style in [
        type.editorialLarge,
        type.editorialMedium,
        type.editorialSmall,
      ]) {
        expect(style.fontFamily, MlTokens.fontSerif);
        // `MlType.figure` is tabular because a numeral that re-measures every
        // frame visibly jitters. A title is words; tabular spacing in running
        // words looks typed rather than set.
        expect(style.fontFeatures ?? const [], isEmpty);
      }
      expect(type.figure(color: const Color(0xFF000000)).fontFeatures,
          contains(const FontFeature.tabularFigures()));
    });

    test('the rungs only ask for weights Fraunces actually has', () {
      // 500, 500-italic and 600 are registered. Asking for w400 or w700 renders
      // one of those three anyway, silently — so the scale must not ask.
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final fraunces = pubspec.split('family: ${MlTokens.fontSerif}').last;
      final registered = RegExp(r'weight:\s*(\d+)')
          .allMatches(fraunces.split('- family:').first)
          .map((m) => int.parse(m.group(1)!))
          .toSet();
      for (final style in [
        type.editorialLarge,
        type.editorialMedium,
        type.editorialSmall,
      ]) {
        expect(registered, contains(style.fontWeight!.value),
            reason: 'the scale asks for w${style.fontWeight!.value} in '
                '${MlTokens.fontSerif}, which pubspec does not register');
      }
    });

    test('copyWith keeps the metrics the slot decided', () {
      // The idiom every converted site uses. If `copyWith(color:)` dropped the
      // height, the migration would have moved the fault rather than fixed it.
      final styled = type.titleSmall.copyWith(
        color: const Color(0xFFFF0000),
        fontWeight: FontWeight.w700,
      );
      expect(styled.height, type.titleSmall.height);
      expect(styled.letterSpacing, type.titleSmall.letterSpacing);
      expect(styled.fontFamily, type.titleSmall.fontFamily);
      expect(styled.fontSize, type.titleSmall.fontSize);
    });
  });
}
