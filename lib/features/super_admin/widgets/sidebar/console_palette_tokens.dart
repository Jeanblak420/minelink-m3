import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ui_prefs.dart';

import 'minelink_sidebar_core.dart';
import 'minelink_sidebar_haul.dart';
import 'minelink_sidebar_weighbridge.dart';

/// MineLink-palette variants of the two design drops.
///
/// Each is the drop **exactly as it is** — same layout, same geometry, same
/// signatures (Haul's detached capsule and chain thread; Weighbridge's solid
/// active block and mono tally column) — with only the colours swapped for the
/// app's design tokens (`MlTokens` / `MlSemantic` / `MlTone`).
///
/// That's enforced structurally rather than by eye: every set starts from the
/// drop's own token object and `copyWith`s colours only, so widths, radii, row
/// heights and font families can never drift from the original.
///
/// Unlike the gold originals, these follow the accent the admin picked in
/// Settings → User Preferences, so the rail matches the rest of the console.
abstract final class MlPaletteSidebarTokens {
  /// Ink used on filled accent surfaces. Now [MlTokens.inkOnAccent] — the
  /// literal was duplicated here and in the chat palette table until S5-19
  /// named it once.
  static const _onAccent = MlTokens.inkOnAccent;

  // The semantic palettes and tones these rails re-skin themselves from.
  // Read live rather than copied as literals: until S5-19 this file held
  // fourteen hand-copied hex values, each with a comment naming the token it
  // had been copied from — which is a drift bug with a comment apologising for
  // it in advance.
  static final _dark = MlSemantic.from(Brightness.dark);
  static final _light = MlSemantic.from(Brightness.light);
  static final _warnDark = MlTone.warn.colors(Brightness.dark);
  static final _doneDark = MlTone.done.colors(Brightness.dark);

  /// Haul, in MineLink colours: the graphite panel becomes the app's navy
  /// sidebar chrome (dark) / slate app surface (light), gold becomes the
  /// console accent.
  static MlSidebarTokens haul({
    required bool dark,
    required ConsoleAccent accent,
  }) {
    final a = accent.color;
    if (dark) {
      return HaulTokens.dark.copyWith(
        // The portal/console rail chrome, per MlTokens' sidebar gradient top.
        surface: MlTokens.sidebarGradientTop,
        surfaceRaised: _dark.surfaceCard,
        surfaceHover: _dark.surfaceRaised,
        surfaceActive: a.withValues(alpha: 0.16),
        border: _dark.borderStrong,
        textPrimary: _dark.textStrong,
        textSecondary: _dark.textMuted,
        textMuted: _dark.textFaint,
        accent: a,
        accentSoft: a.withValues(alpha: 0.14),
        onAccent: _onAccent,
        badgeBg: a,
        badgeFg: _onAccent,
        // Sign-out reads in the app's logout orange (MlTone.warn), not red.
        danger: _warnDark.fg,
        dangerBg: _warnDark.bg,
        online: _doneDark.fg,
      );
    }
    return HaulTokens.light.copyWith(
      surface: _light.surfaceApp,
      surfaceRaised: _light.surfaceCard,
      surfaceHover: MlTokens.slate100,
      surfaceActive: a.withValues(alpha: 0.10),
      border: MlTokens.slate200,
      textPrimary: MlTokens.slate900,
      textSecondary: MlTokens.slate600,
      textMuted: MlTokens.slate400,
      accent: a,
      accentSoft: a.withValues(alpha: 0.12),
      onAccent: _onAccent,
      badgeBg: a,
      badgeFg: _onAccent,
      danger: MlTokens.orange700,
      dangerBg: MlTokens.orange50,
      online: MlTokens.green600,
    );
  }

  /// Weighbridge, in MineLink colours: the paper/ink manifest becomes the
  /// app's slate surfaces, the ink block becomes slate-900 (light) / the app's
  /// strong text colour (dark), and the tally column takes the console accent.
  static MlSidebarTokens weighbridge({
    required bool dark,
    required ConsoleAccent accent,
  }) {
    final a = accent.color;
    if (dark) {
      return WeighbridgeTokens.dark.copyWith(
        surface: _dark.surfaceApp,
        surfaceRaised: _dark.surfaceCard,
        surfaceHover: _dark.surfaceRaised,
        // Inverted stamp: the app's strong text colour as the paper block.
        surfaceActive: _dark.textStrong,
        onInk: _dark.surfaceApp, // …and the app surface as its ink
        border: _dark.borderCard,
        textPrimary: _dark.textStrong,
        textSecondary: _dark.textMuted,
        textMuted: _dark.textFaint,
        accent: a,
        accentSoft: a.withValues(alpha: 0.14),
        onAccent: _onAccent,
        badgeBg: a,
        badgeFg: _onAccent,
        danger: _warnDark.fg,
        dangerBg: _warnDark.bg,
        online: _doneDark.fg,
      );
    }
    return WeighbridgeTokens.light.copyWith(
      surface: _light.surfaceApp,
      surfaceRaised: _light.surfaceCard,
      surfaceHover: MlTokens.slate100,
      surfaceActive: MlTokens.slate900, // the ink block
      onInk: _light.surfaceCard,
      border: MlTokens.slate200,
      textPrimary: MlTokens.slate900,
      textSecondary: MlTokens.slate600,
      textMuted: MlTokens.slate400,
      accent: a,
      accentSoft: a.withValues(alpha: 0.12),
      onAccent: _onAccent,
      badgeBg: a,
      badgeFg: _onAccent,
      danger: MlTokens.orange700,
      dangerBg: MlTokens.orange50,
      online: MlTokens.green600,
    );
  }

  /// The palette for [skin], or null when that skin uses its own (the two gold
  /// originals, which pick their tokens from the theme brightness themselves).
  static MlSidebarTokens? forSkin(
    ConsoleSidebarSkin skin, {
    required bool dark,
    required ConsoleAccent accent,
  }) {
    if (!skin.usesAppPalette) return null;
    return skin.isWeighbridge
        ? weighbridge(dark: dark, accent: accent)
        : haul(dark: dark, accent: accent);
  }
}
