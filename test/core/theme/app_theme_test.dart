import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_chrome.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_scheme.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// WCAG 2.1 relative-contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('AppTheme — the M3 rebuild', () {
    test('uses Plus Jakarta Sans as the app-wide sans family', () {
      final light = AppTheme.lightTheme;
      expect(light.textTheme.bodyMedium?.fontFamily, MlTokens.fontSans);
      expect(light.textTheme.titleLarge?.fontFamily, MlTokens.fontSans);
    });

    test('display slots are Fraunces and are NOT flattened to the sans', () {
      // The regression this pins: the shipping theme ended `_mlTextTheme` with
      // `.apply(fontFamily: MlTokens.fontSans)`, which overwrote every family
      // assignment in the theme it had just made. Twelve tonnage figures the
      // portal drew as "Fraunces" were rendering in the UI sans as a result,
      // and nothing said so. Families are now assigned per slot and never
      // applied over the finished theme.
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final t = theme.textTheme;
        expect(t.displayLarge?.fontFamily, MlTokens.fontSerif);
        expect(t.displayMedium?.fontFamily, MlTokens.fontSerif);
        expect(t.displaySmall?.fontFamily, MlTokens.fontSerif);
      }
    });

    test('display slots carry tabular figures', () {
      // Not cosmetic. A stat card counting 0 -> 128.4 re-measures every frame
      // with proportional digits, so the number visibly jitters as it climbs,
      // and a column of figures fails to line up.
      final t = AppTheme.darkTheme.textTheme;
      for (final style in [t.displayLarge, t.displayMedium, t.displaySmall]) {
        expect(
          style?.fontFeatures?.any((f) => f.feature == 'tnum'),
          isTrue,
          reason: 'display slots must be tabular',
        );
      }
    });

    test('the type scale is Material 3\'s, with tempered display steps', () {
      final t = AppTheme.lightTheme.textTheme;

      // M3 sizes, exactly, for the slots that carry the interface.
      expect(t.headlineSmall?.fontSize, 24);
      expect(t.titleLarge?.fontSize, 22);
      expect(t.titleMedium?.fontSize, 16);
      expect(t.bodyLarge?.fontSize, 16);
      expect(t.bodyMedium?.fontSize, 14);
      expect(t.bodySmall?.fontSize, 12);
      expect(t.labelLarge?.fontSize, 14);
      expect(t.labelMedium?.fontSize, 12);
      expect(t.labelSmall?.fontSize, 11);

      // Display is tempered one step down from M3's 57/45/36. This is a
      // logistics console whose "display" text is a tonnage in a stat card
      // beside five other stat cards; at 57px those stop fitting four-across
      // on a laptop, which is the layout the dashboards are built around.
      expect(t.displayLarge?.fontSize, 45);
      expect(t.displayMedium?.fontSize, 36);
      expect(t.displaySmall?.fontSize, 32);
    });

    test('light surfaces keep the slate palette', () {
      final light = AppTheme.lightTheme;
      expect(light.scaffoldBackgroundColor, MlTokens.slate50);
      expect(light.cardTheme.color, const Color(0xFFFFFFFF));
    });

    test('dark surfaces are unchanged from the design reference', () {
      // These three are what docs/design-reference/*-dark.png shows. The
      // redesign gave them M3 role names; it did not move them.
      final dark = AppTheme.darkTheme;
      expect(dark.scaffoldBackgroundColor, const Color(0xFF0A1424));
      expect(dark.cardTheme.color, const Color(0xFF111C30));
      expect(MlScheme.dark.surfaceContainerHigh, const Color(0xFF16243C));
    });

    test('a focused input is legible against the field it focuses', () {
      // Replaces an assertion that the focus ring is literally MlTokens.accent.
      // It no longer is in light, and that is the fix rather than a
      // regression: #22D3EE on the light field fill measures ~1.4:1, so the
      // ring marking the focused field was all but invisible to a sighted user
      // and entirely invisible to anyone with reduced contrast sensitivity.
      // The scheme's `primary` is the deep cyan in light and the bright one in
      // dark, so the ring is legible in both without anyone choosing per site.
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final decor = theme.inputDecorationTheme;
        final focused = decor.focusedBorder! as OutlineInputBorder;
        expect(focused.borderSide.color, theme.colorScheme.primary);
        expect(focused.borderSide.width, 2);
        expect(
          _contrast(focused.borderSide.color, decor.fillColor!),
          greaterThanOrEqualTo(3.0),
          reason: 'a focus ring is a non-text UI indicator: WCAG 1.4.11 '
              'requires 3:1 against what it sits on',
        );
      }
    });

    test('primary ink is legible on primary in BOTH themes', () {
      // The whole reason the light and dark primaries differ. White on
      // #22D3EE measures 1.9:1 and fails every threshold there is; the
      // shipping app worked around it with an `inkOnAccent` constant authors
      // had to remember. M3's role pairing removes the choice.
      for (final scheme in [MlScheme.light, MlScheme.dark]) {
        expect(
          _contrast(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
          reason: '${scheme.brightness} onPrimary on primary',
        );
        expect(
          _contrast(scheme.onSurface, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: '${scheme.brightness} onSurface on surface',
        );
        expect(
          _contrast(scheme.onSurfaceVariant, scheme.surface),
          greaterThanOrEqualTo(4.5),
          reason: '${scheme.brightness} onSurfaceVariant on surface',
        );
        expect(
          _contrast(scheme.onErrorContainer, scheme.errorContainer),
          greaterThanOrEqualTo(4.5),
          reason: '${scheme.brightness} onErrorContainer on errorContainer',
        );
      }
    });

    test('a chosen accent recomputes its own ink instead of inheriting', () {
      // The console used to do `copyWith(primary: accent)` and leave
      // `onPrimary` alone, so a pale accent gave white-on-pale buttons and a
      // dark one gave black-on-dark. Both extremes must stay legible.
      for (final accent in <Color>[
        const Color(0xFFFFF176), // very pale
        const Color(0xFF1A237E), // very dark
        MlTokens.accent,
      ]) {
        for (final base in [MlScheme.light, MlScheme.dark]) {
          final s = MlScheme.withAccent(base, accent);
          expect(
            _contrast(s.onPrimary, s.primary),
            greaterThanOrEqualTo(4.5),
            reason: 'accent $accent on ${base.brightness}',
          );
        }
      }
    });

    test('dialogs and bottom sheets share the M3 shape step', () {
      // They were 16 and 24 in the shipping app, for no stated reason. M3 puts
      // both on 28.
      final t = AppTheme.darkTheme;
      expect(t.dialogTheme.shape, MlShape.dialog);
      expect(
        (t.bottomSheetTheme.shape! as RoundedRectangleBorder).borderRadius,
        MlShape.radiusTopExtraLarge,
      );
    });

    test('chips are stadium-shaped, as M3 specifies', () {
      // The shipping app used an 8dp rectangle, which is what made its chips
      // read as very small buttons.
      expect(AppTheme.darkTheme.chipTheme.shape, isA<StadiumBorder>());
    });

    test('text selection follows the brand, not a stray seed', () {
      // The most visible symptom of the two-palette problem: the theme was
      // seeded from teal700, so the cursor and selection handles were teal on
      // a cyan interface. Nothing had restyled them because nobody had
      // noticed.
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        expect(theme.textSelectionTheme.cursorColor, theme.colorScheme.primary);
        expect(
          theme.textSelectionTheme.selectionHandleColor,
          theme.colorScheme.primary,
        );
      }
    });

    test('the brand chrome rides on the theme as an extension', () {
      for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
        final chrome = theme.extension<MlChrome>();
        expect(chrome, isNotNull);
        // The rail is navy in BOTH themes — that is the brand decision this
        // extension exists to express, and the reason it cannot be a surface
        // role. Assert it is dark either way.
        expect(
          chrome!.railBottom.computeLuminance(),
          lessThan(0.06),
          reason: '${theme.brightness} rail must stay navy',
        );
        expect(
          _contrast(chrome.railLabelSelected, chrome.railBottom),
          greaterThanOrEqualTo(4.5),
          reason: '${theme.brightness} selected rail label on the rail',
        );
        expect(
          _contrast(chrome.railLabel, chrome.railBottom),
          greaterThanOrEqualTo(4.5),
          reason: '${theme.brightness} resting rail label on the rail',
        );
      }
    });

    test('high contrast strengthens ink without moving the hues', () {
      final base = MlScheme.dark;
      final hc = MlScheme.highContrast(base);
      expect(
        _contrast(hc.onSurface, hc.surface),
        greaterThan(_contrast(base.onSurface, base.surface)),
      );
      // Status meaning must not shift: `error` is content, not chrome.
      expect(hc.error, base.error);
      expect(hc.primary, base.primary);
    });
  });
}
