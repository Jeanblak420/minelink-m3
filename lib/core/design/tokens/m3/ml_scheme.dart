import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// **The** MineLink colour scheme. One `ColorScheme` per brightness, and every
/// other colour in the app is derived from it.
///
/// ## Why this file exists
///
/// The shipping app had two colour systems running side by side and disagreeing:
///
/// - a Material `ColorScheme` seeded from `MlTokens.teal700` (`#0F6E8C`), and
/// - twelve hand-authored token files whose accent was `#22D3EE`.
///
/// Nothing reconciled them. `Theme.of(context).colorScheme.primary` and
/// `MlTokens.accent` were different colours, so every Material widget the app
/// did not explicitly restyle — a `Switch`, a `Slider`, a text-field cursor, a
/// selection handle, a `CircularProgressIndicator` — came out teal on a cyan
/// interface. The fix was always to restyle one more widget, which is why the
/// token files kept multiplying.
///
/// Here the `ColorScheme` **is** the design system. `MlSemantic` reads from it.
/// `MlTone` reads from it. The component themes read from it. There is one
/// place a colour is decided, so an unstyled Material widget is now correct by
/// default rather than by having been caught.
///
/// ## Why the roles are pinned rather than seeded
///
/// `ColorScheme.fromSeed(seedColor: MlTokens.accent)` produces a *usable*
/// scheme, but not this brand's: the tonal-palette algorithm desaturates a
/// bright cyan seed considerably, and the reference renders
/// (`docs/design-reference/`) are the specification. So the scheme is written
/// out explicitly. Every value below is either a `MlTokens` constant or a tone
/// derived from one, and the derived ones carry the measurement that justifies
/// them.
///
/// ## The contrast problem this structurally solves
///
/// `#22D3EE` is a *light* colour — white text on it measures **1.9:1**, which
/// fails every threshold there is. The shipping app worked around this with a
/// separate `inkOnAccent` (`#04222B`, 11.3:1) that authors had to remember to
/// reach for; where they forgot, they got `Colors.white` and an illegible chip.
///
/// M3 removes the choice. In **dark** the accent is `primary` and its ink is
/// `onPrimary`, which is that same near-black. In **light** `primary` is
/// `cyan700` (`#0A7791` — 4.9:1 against white) and the bright `#22D3EE` lives
/// on as `inversePrimary` and in the navy chrome, where it sits on dark and is
/// legible. Nobody has to remember anything; the role name carries it.
abstract final class MlScheme {
  const MlScheme._();

  /// Light. The workspace: near-white surfaces, slate ink, deep-cyan primary.
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,

    // ---- primary: deep cyan, so white ink on it is legible (4.9:1) ----
    primary: MlTokens.cyan700,
    onPrimary: MlTokens.inkOnFill,
    primaryContainer: MlTokens.cyan100,
    onPrimaryContainer: MlTokens.inkOnAccent,

    // ---- secondary: the navy chrome hue, usable as content colour ----
    secondary: MlTokens.navy700,
    onSecondary: MlTokens.inkOnFill,
    secondaryContainer: Color(0xFFDCE6F2),
    onSecondaryContainer: MlTokens.navy800,

    // ---- tertiary: violet. The buyer org hue, and the scheme's third hue.
    // Without a real tertiary, M3 components that reach for one (a selected
    // date, a secondary FAB) fall back to primary and the interface goes
    // monochrome cyan.
    tertiary: MlTokens.violet700,
    onTertiary: MlTokens.inkOnFill,
    tertiaryContainer: MlTokens.violet50,
    onTertiaryContainer: Color(0xFF2E1065),

    error: MlTokens.red600,
    onError: MlTokens.inkOnFill,
    errorContainer: MlTokens.red50,
    onErrorContainer: Color(0xFF7F1D1D),

    // ---- surfaces ----
    // `surface` is the app canvas; the container ladder rises *toward* the
    // viewer, so a card (`surfaceContainerLowest`, pure white) sits above the
    // canvas rather than below it. This is inverted from the dark scheme, which
    // is correct: in light, elevation means lighter.
    surface: MlTokens.slate50,
    onSurface: MlTokens.slate900,
    onSurfaceVariant: MlTokens.slate600,
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFFCFDFE),
    surfaceContainer: MlTokens.slate100,
    surfaceContainerHigh: Color(0xFFEBF0F6),
    surfaceContainerHighest: MlTokens.slate200,
    surfaceDim: Color(0xFFDCE2EA),
    surfaceBright: Color(0xFFFFFFFF),

    outline: MlTokens.slate400,
    // `slate300`, not `#E7EDF3`.
    //
    // Every card border, every table divider and every hairline in the product
    // is this one value, and against a white card `#E7EDF3` measures
    // **1.18:1** — below the 1.25 floor `test/design/token_contrast_test.dart`
    // sets for "visible at all", and well under the 1.5:1 a hairline needs to
    // read as an edge. In light mode the cards had no edges; what looked like
    // a clean flat design was a border nobody could see.
    //
    // slate300 measures 1.49:1 on a white card and 1.42:1 on the page. Still
    // quiet — it is a hairline, not a rule — but present. Found 2026-08-21 by
    // measuring the token pairs rather than by photographing more screens:
    // light mode had nine renders out of 204 and this was in every one of
    // them.
    outlineVariant: MlTokens.slate300,

    shadow: MlTokens.overlayDark,
    scrim: MlTokens.overlayDark,

    inverseSurface: MlTokens.slate900,
    onInverseSurface: MlTokens.slate50,
    // The bright brand cyan. On the dark inverse surface it is legible, which
    // is the only place light-mode M3 puts it.
    inversePrimary: MlTokens.cyan400,

    surfaceTint: MlTokens.cyan700,
  );

  /// Dark. The default theme mode, and the one the design reference captures.
  ///
  /// The surface ladder here reproduces the shipping app's dark surfaces
  /// **exactly** — `#0A1424` canvas, `#111C30` card, `#16243C` raised — because
  /// those are what `docs/design-reference/*-dark.png` shows and they were
  /// tuned against those renders. What changes is that they now have M3 role
  /// names, so a Material widget can find them without being told.
  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,

    // The brand accent, unmodified, as primary — and its ink is the measured
    // 11.3:1 near-black rather than white.
    primary: MlTokens.cyan400,
    onPrimary: MlTokens.inkOnAccent,
    primaryContainer: MlTokens.cyan700,
    // `cyan50`, not `cyan100`. This pair fills the console's extended FAB -
    // "Generate Token" - and cyan100 on cyan700 is 4.37:1, a hair under. 4.83
    // at cyan50, and it is still the palest cyan in the ramp rather than a
    // white that would lose the tint.
    onPrimaryContainer: MlTokens.cyan50,

    secondary: MlTokens.sidebarActiveBlue,
    onSecondary: Color(0xFF062040),
    secondaryContainer: Color(0xFF123253),
    onSecondaryContainer: Color(0xFFCFE4FA),

    tertiary: MlTokens.violet400,
    onTertiary: Color(0xFF2E1065),
    tertiaryContainer: Color(0xFF4C2889),
    onTertiaryContainer: MlTokens.violet50,

    // `red600` goes muddy on navy — the token file records this. `#F0715A` is
    // the pair the console already used for dark error text.
    error: Color(0xFFF0715A),
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: MlTokens.red50,

    surface: Color(0xFF0A1424),
    onSurface: Color(0xFFEEF3FA),
    onSurfaceVariant: MlTokens.slate400,
    surfaceContainerLowest: MlTokens.navy900,
    surfaceContainerLow: Color(0xFF0D1829),
    surfaceContainer: Color(0xFF111C30),
    surfaceContainerHigh: Color(0xFF16243C),
    surfaceContainerHighest: Color(0xFF1C2C46),
    surfaceDim: Color(0xFF070F1C),
    surfaceBright: Color(0xFF26324A),

    outline: Color(0xFF5D6D8C),
    outlineVariant: Color(0xFF2A3A55),

    shadow: MlTokens.overlayDark,
    scrim: MlTokens.overlayDark,

    inverseSurface: Color(0xFFEEF3FA),
    onInverseSurface: Color(0xFF0A1424),
    inversePrimary: MlTokens.cyan700,

    surfaceTint: MlTokens.cyan400,
  );

  static ColorScheme of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The scheme with a different accent applied — the per-admin accent choice
  /// in Settings → User Preferences.
  ///
  /// Only `primary` and `surfaceTint` move. `onPrimary` is **recomputed from
  /// the new accent's luminance** rather than carried over, which is the bug
  /// this method exists to prevent: the shipping console did
  /// `copyWith(primary: accent, secondary: accent)` and left `onPrimary`
  /// alone, so picking a pale accent produced white-on-pale buttons and
  /// picking a dark one produced black-on-dark.
  static ColorScheme withAccent(ColorScheme base, Color accent) {
    // 4.5:1 against white needs roughly L* < 0.18 in relative luminance terms;
    // 0.45 is the standard crossover point used for on-colour selection and is
    // what Material's own contrast curve lands on.
    final ink = accent.computeLuminance() > 0.45
        ? MlTokens.inkOnAccent
        : MlTokens.inkOnFill;
    return base.copyWith(
      primary: accent,
      onPrimary: ink,
      surfaceTint: accent,
    );
  }

  /// The scheme strengthened for the high-contrast preference.
  ///
  /// Raises ink and border contrast only. It deliberately does **not** touch
  /// the status hues: `MlTone` carries lifecycle meaning, and shifting those
  /// would change what a colour means rather than how clearly it reads.
  static ColorScheme highContrast(ColorScheme base) => base.copyWith(
        onSurface: base.brightness == Brightness.dark
            ? MlTokens.inkOnFill
            : MlTokens.slate950,
        onSurfaceVariant: base.brightness == Brightness.dark
            ? MlTokens.slate200
            : MlTokens.slate800,
        outline: base.brightness == Brightness.dark
            ? MlTokens.slate300
            : MlTokens.slate600,
        outlineVariant: base.brightness == Brightness.dark
            ? MlTokens.slate500
            : MlTokens.slate400,
      );
}
