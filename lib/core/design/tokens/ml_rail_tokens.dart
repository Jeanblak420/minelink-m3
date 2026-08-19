// MineLink design tokens — the console nav rail.
//
// S5-2 (P5-05): extracted VERBATIM from
// `features/super_admin/widgets/super_admin_shell_layout.dart` 2026-08-13,
// where it was the PRIVATE class `MlRailTokens` — 20 colour slots that no other
// surface could reach precisely because it was private.
//
// Renamed `MlRailTokens` -> `MlRailTokens` and made public, which is the whole point:
// S5-10 extracts `WorkspaceShell` from that same file so the portal and the
// console share one shell, and a shared shell cannot depend on a private
// token class in the file it is being lifted out of.
//
// Values are unchanged. `mlRailAccent` and `mlConsoleSans` came across with it —
// they are rail tokens too, and both are still referenced by the shell, which
// now imports them from here.

import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_sidebar_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

const mlRailAccent = Color(0xFF2563EB);

/// Placeholder + icon ink inside the console's rail search field, in both
/// themes. It reads against the light rail's `#EDF1F7` well and the dark
/// rail's `#080F1C` one, which is why it is a single mid slate rather than
/// either theme's `inkFaint`. Was the private `_searchInk` in
/// `super_admin_shell_layout.dart`, repeated at 7 sites (S5-19).
const mlRailSearchInk = Color(0xFF657795);

/// The dark rail's accent lifted one step — a hovered rail control, the
/// gradient partner to [MlRailTokens.accent] on navy.
const mlRailAccentLift = Color(0xFF8FD0FF);

/// The console canvas the rail and cards sit on. Deliberately NOT
/// `MlSemantic.surfaceApp`: the design puts the console one step darker than
/// the portal in dark mode (#070C17 against #0A1424) and one step *cooler*
/// than it in light (#E0E7F0 against slate-50), so white cards read as raised
/// rather than as part of the page. Two literals in
/// `super_admin_shell_layout.dart` before S5-19.
const mlConsoleCanvasDark = Color(0xFF070C17);
const mlConsoleCanvasLight = Color(0xFFE0E7F0);

/// High-contrast overrides for the console's `ColorScheme`, applied when an
/// admin turns on High Contrast in Settings → User Preferences. They exist as
/// tokens because a preference that strengthens contrast has to state what it
/// strengthens *to*; picking values inline made the feature unauditable.
const mlConsoleHcOnSurfaceVariantDark = Color(0xFFD5DEEA);
const mlConsoleHcOnSurfaceVariantLight = Color(0xFF26324A);
const mlConsoleHcOutlineDark = Color(0x5994A3B8);
const mlConsoleHcOutlineLight = Color(0xFF8CA0BA);

/// Depth cast by the light rail onto the canvas beside it. The dark rail casts
/// none — it is darker than the canvas, so a shadow would read as a smudge.
const mlRailLightShadow = Color(0x2E0F172A);

/// The three washes painted onto the console canvas behind everything else:
/// a cyan bloom, a blue counter-bloom, and the dot grid. All three are
/// deliberately faint — at 8%, 5.5% and 4% they are texture, not colour, and
/// the moment any of them reads as a hue the canvas stops being a background.
const mlCanvasBloomCyan = Color(0x1400B5D8);
const mlCanvasBloomBlue = Color(0x0E2563EB);
const mlCanvasDot = Color(0x0B0F172A);

/// Shadow under a rail flyout. Black at 54% rather than the slate-tinted
/// `MlTokens.shadowLg`: a flyout can open over either canvas, and a tinted
/// shadow reads as a halo on the dark one.
const mlRailFlyoutShadow = Color(0x8A000000);

/// Console UI sans — the design drop sets `--font-sans: 'Sora'` for the whole
/// Super-Admin console (chrome + screens).
const mlConsoleSans = 'Sora';

/// Sidebar theme tokens — the nav rail flips with the console theme (design
/// `--sb-*` variables): light = white rail, slate ink, blue accent; dark = the
/// original navy gradient with the ice-blue accent.
class MlRailTokens {
  final bool dark;
  final List<Color> bg;
  final Color border;
  final Color solid;
  final Color inkStrong;
  final Color ink;
  final Color inkMuted;
  final Color inkFaint;
  final Color accent;
  final Color tileSelBg;
  final Color tileSelBgSub;
  final Color tileSelBd;
  final Color hover;
  final Color searchBg;
  final Color searchBd;
  final Color div;
  final Color btnBd;
  final Color btnBg;
  final Color cbtnFg;
  final Color flyoutBg;

  const MlRailTokens._({
    required this.dark,
    required this.bg,
    required this.border,
    required this.solid,
    required this.inkStrong,
    required this.ink,
    required this.inkMuted,
    required this.inkFaint,
    required this.accent,
    required this.tileSelBg,
    required this.tileSelBgSub,
    required this.tileSelBd,
    required this.hover,
    required this.searchBg,
    required this.searchBd,
    required this.div,
    required this.btnBd,
    required this.btnBg,
    required this.cbtnFg,
    required this.flyoutBg,
  });

  static const _light = MlRailTokens._(
    dark: false,
    bg: [Color(0xFFFFFFFF), Color(0xFFEEF2F8)],
    border: Color(0xFFCDD8E6),
    solid: Color(0xFFFFFFFF),
    inkStrong: Color(0xFF0F172A),
    ink: Color(0xFF36445C),
    inkMuted: Color(0xFF5B6B84),
    inkFaint: Color(0xFF8A99B0),
    accent: Color(0xFF2563EB),
    tileSelBg: Color(0x172563EB),
    tileSelBgSub: Color(0x0F2563EB),
    tileSelBd: Color(0x612563EB),
    hover: Color(0x0E0F172A),
    searchBg: Color(0xFFEDF1F7),
    searchBd: Color(0x210F172A),
    div: Color(0x1A0F172A),
    btnBd: Color(0x290F172A),
    btnBg: Color(0x0A0F172A),
    cbtnFg: Color(0xFF2563EB),
    flyoutBg: Color(0xFFFFFFFF),
  );

  static const _dark = MlRailTokens._(
    dark: true,
    bg: [Color(0xFF0C1C34), Color(0xFF050B18)],
    border: Color(0x1494A3B8),
    solid: Color(0xFF0B192E),
    inkStrong: Color(0xFFEAF2FF),
    ink: Color(0xD1E2E8F0),
    inkMuted: Color(0xA8E2E8F0),
    inkFaint: Color(0x8CE2E8F0),
    accent: Color(0xFF6AB8FF),
    tileSelBg: Color(0x1A6AB8FF),
    tileSelBgSub: Color(0x126AB8FF),
    tileSelBd: Color(0x666AB8FF),
    hover: Color(0x1A94A3B8),
    searchBg: Color(0xFF080F1C),
    searchBd: Color(0x1F8CB4F0),
    div: Color(0x1C94A3B8),
    btnBd: Color(0x3394A3B8),
    btnBg: Color(0x0F94A3B8),
    cbtnFg: Color(0xFF9FC4EE),
    flyoutBg: Color(0xFF0D1A2E),
  );

  /// Projects this rail palette onto the [MlSidebarTokens] contract.
  ///
  /// Added at S5-19 for one reason: `user_preferences_screen.dart` drew a
  /// 104px **thumbnail** of this very rail from 32 hand-copied literals, under
  /// a comment reading *"kept in sync by eye — it's a thumbnail, not chrome"*.
  /// A swatch whose job is to show the user what the rail looks like is the
  /// one place a by-eye copy is least defensible: when it drifts, it does not
  /// look wrong, it looks like a different option.
  ///
  /// Where the rail states a translucent value over its own surface (`ink`,
  /// `inkFaint`, `hover`, `border`) it is composited here rather than
  /// approximated, so the thumbnail resolves to the same pixels the rail does.
  MlSidebarTokens asSidebarTokens({double radius = 12}) => MlSidebarTokens(
        isDarkSurface: dark,
        surface: solid,
        surfaceRaised: flyoutBg,
        surfaceHover: Color.alphaBlend(hover, solid),
        surfaceActive: tileSelBg,
        border: Color.alphaBlend(border, solid),
        textPrimary: inkStrong,
        textSecondary: Color.alphaBlend(ink, solid),
        textMuted: Color.alphaBlend(inkFaint, solid),
        accent: accent,
        accentSoft: tileSelBgSub,
        onAccent: dark ? MlTokens.inkOnAccent : MlTokens.inkOnFill,
        badgeBg: MlTokens.accent,
        badgeFg: MlTokens.inkOnAccent,
        danger: MlTokens.orange500,
        dangerBg: MlTokens.orange500.withValues(alpha: dark ? 0.10 : 0.08),
        online: dark ? MlTokens.green500 : MlTokens.green600,
        radius: radius,
      );

  static MlRailTokens of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  /// The navy rail, regardless of theme.
  ///
  /// The CONSOLE rail flips with the theme — white in light, navy in dark. The
  /// PORTAL rail is navy in both, and always has been. Exposing the dark set
  /// explicitly lets `portal_scaffold` drop its 35 hand-copied literals
  /// (S5-18) WITHOUT silently changing how it looks: every value it was using
  /// was the dark one anyway.
  ///
  /// **Client ruling 2026-08-14: the portal rail stays navy in both themes.**
  /// It is deliberately NOT `.of(context)`. Raised as a visible design
  /// decision rather than smuggled in behind a token cleanup, and settled.
  static const MlRailTokens navy = _dark;

  /// The white rail, regardless of theme — the counterpart to [navy], exposed
  /// for the same reason: a preview that must render *both* options at once
  /// cannot use [of], which only ever returns the active one.
  static const MlRailTokens light = _light;
}

/// The portal's nav-rail gradient (shell.jsx `linear-gradient(168deg,…)`).
///
/// Moved here from `PortalColors.sidebarGradient` at S5-8: the portal rail and
/// the console rail are the same surface in two shells, and S5-10 merges those
/// shells. A rail gradient living in a feature's colour file is one that gets
/// hand-copied rather than shared.
const LinearGradient mlPortalRailGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [MlTokens.sidebarGradientTop, MlTokens.sidebarGradientBottom],
);

/// Inks that belong to the **portal** rail specifically.
///
/// The portal rail is navy in both themes (client ruling 2026-08-14, recorded
/// on [MlRailTokens.navy]), so it carries a cool blue-grey ink ramp of its own
/// rather than the console's slate one — `#94B2D6` against the console's
/// `#E2E8F0`. That is a real difference, not a copy that drifted: the console
/// rail has to read on white as well, and a blue-tinted ink does not.
///
/// The translucent members state their alpha rather than composing it with
/// `withValues`, so the call sites stay `const` — a `TextStyle` in a rail that
/// rebuilds on every hover is worth keeping constant. Named at S5-19, where
/// they were 11 anonymous literals in `portal_scaffold.dart`.
abstract final class MlPortalRail {
  const MlPortalRail._();

  /// The rail's cool secondary ink, and its two translucent steps.
  static const ink = Color(0xFF94B2D6);
  static const ink70 = Color(0xB394B2D6);
  static const ink55 = Color(0x8C94B2D6);

  /// Type inside the rail's search field. Lighter than [ink] because it sits
  /// on the sunken `searchBg` well rather than on the rail itself.
  static const inkSearch = Color(0xFFC8D5EC);

  /// A footer icon button's glyph, and the same glyph when disabled.
  static const inkIcon = Color(0xB3E2E8F0);
  static const inkDisabled = Color(0x78E2E8F0);

  /// Ink on the accent-filled mono chip in the rail footer. Near-black navy
  /// for the same reason as [MlTokens.inkOnAccent]; one step cooler to match
  /// the portal's blue ramp.
  static const inkOnAccentChip = Color(0xFF04121F);

  /// The collapse button's edge — [MlTokens.sidebarActiveBlue] at 22%, the
  /// visible partner to `MlRailTokens.navy.tileSelBgSub` behind it.
  static const collapseBorder = Color(0x386AB8FF);

  /// Logout button wash and edge — [MlTokens.orange500] at 8% and 28%.
  static const logoutWash = Color(0x14F97316);
  static const logoutBorder = Color(0x47F97316);
}
