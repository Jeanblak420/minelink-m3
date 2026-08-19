import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// The **control-room palette** — the fixed deep-navy surface the super-admin
/// console's full-bleed analytics screens are painted on.
///
/// It deliberately opts out of `MlSemantic`'s light/dark pair. The console
/// chrome is permanently dark navy (`super_admin_shell_layout.dart`), so a
/// screen that followed the theme would sit as a light rectangle inside a dark
/// shell. That is a real decision, not an oversight.
///
/// ## It is [MlGlass.dark], and that was not obvious
///
/// Almost every member below forwards to the existing glass palette. That is
/// the finding, not an implementation detail: `super_admin_org_insights_screen`
/// and `super_admin_company_mirror_screen` each carried a **private
/// `_CrPalette` class of the same name**, transcribed by hand from two
/// different mocks, and between them they restated twenty-three values that
/// `MlGlass.dark` already held — under a doc comment claiming the palette was
/// "shared". It was not shared; it was forked twice from a third copy nobody
/// linked back to.
///
/// The two forks did not agree with each other either:
///
/// | key | org-insights | company-mirror | `MlGlass.dark` |
/// |---|---|---|---|
/// | `pageBg` | `#060B15` | `#0A101D` | `#060B15` |
/// | `surfaceCard` | `#0E1728` | `#0D1526` | `#0E1728` |
/// | `textStrong` | `#EAF2FF` | `#F1F5F9` | `#EAF2FF` |
/// | `textMuted` | `#8896AE` | `#7E8CA6` | `#8896AE` |
/// | `blue` | `#38BDF8` | `#60A5FA` | — |
/// | `green` | `#34D399` | `#22C55E` | `#34D399` |
///
/// The org-insights fork is the one that matches the glass palette on every
/// shared key, which settles which of the two was right without needing a
/// preference: it is not a third opinion, it is the one that never diverged.
/// So the shared keys forward to [MlGlass.dark] and cannot drift again, and
/// only the genuinely-extra ones — the pre-composited glass base, the two tile
/// washes, the accent glow, coral, pink, and the mirror's blue-washed panel —
/// are declared here.
///
/// Visible consequence, recorded so it is not read as a regression: the
/// company-mirror screen's navy is now a half-step deeper, its accent blue a
/// half-step brighter and its cards 2px rounder. It matches the org-insights
/// screen it sits beside, and both match the console's other glass surfaces.
class MlControlRoom {
  const MlControlRoom._();

  static const MlGlass _g = MlGlass.dark;

  // NOTE: the forwarded members below are `final`, not `const` — Dart cannot
  // const-evaluate a field read off a const instance. `test/core/
  // control_room_palette_test.dart` pins each one to its MlGlass source so
  // the forward cannot be quietly replaced by a literal that then drifts.

  // ── Base surfaces (the handoff's `--bg-*`) ─────────────────────────────
  static final Color pageBg = _g.bg0; // --bg-0
  static final Color bgRaised = _g.bg1; // --bg-1
  static final Color bgPanelWash = _g.bg2; // --bg-2

  /// One step above `--bg-2`. The only base surface the glass palette has no
  /// slot for — the mock uses it for a panel raised *inside* another panel.
  static const Color bgElevated = Color(0xFF142238); // --bg-3

  // ── V3 "Glass" panel stack ─────────────────────────────────────────────
  // Design: `background: linear-gradient(#ffffff0a, #ffffff03), #0F1A2EBF`
  // over `backdrop-filter: blur(16px)`. Flutter cannot blur what is behind an
  // opaque page, so the translucent base is pre-composited onto [pageBg] and
  // the white sheen is kept as the gradient — same result on this fixed navy.
  /// `MlGlass.dark.glassBase` (#0F1A2E at 75%) pre-composited on [pageBg].
  ///
  /// Composited rather than written out. It *was* written out — as `#0D1628`,
  /// which is the correct blend rounded to the nearest 8-bit channel — and the
  /// test pinning it to its source caught the rounding as a 1/255 drift. That
  /// is a small error and an exact demonstration of the failure mode: a
  /// transcribed value is right on the day it is transcribed.
  static final Color glassBase = Color.alphaBlend(_g.glassBase, _g.bg0);
  static final Color glassSheenTop = _g.glassTop; // rgba(255,255,255,.04)
  static final Color glassSheenBottom = _g.glassBottom; // rgba(255,255,255,.01)

  /// Between `line` (.06) and `line2` (.09): the glass card's own edge, which
  /// the mock draws at .08 to read against the sheen sitting just inside it.
  static const Color glassBorder = Color(0x14FFFFFF);
  static final Color glassHighlight = _g.line; // inset top 1px

  // ── Panels and tiles ───────────────────────────────────────────────────
  static final Color surfaceCard = _g.panel; // --panel
  static final Color surfaceCardDeep = _g.panel2; // --panel-2

  /// Blue-washed panel — the monthly-progress card in the mirror's mock.
  static const Color surfaceTintedCard = Color(0xFF0E1B33);

  /// `.mini` and `.alert` — white washes at .03 and .02, below the .06 the
  /// glass palette's `line` starts at, because they are fills not rules.
  static const Color surfaceTile = Color(0x08FFFFFF);
  static const Color surfaceTileAlt = Color(0x05FFFFFF);

  static final Color tileBorder = _g.line; // --line
  static final Color borderCard = _g.line2; // --line-2
  static final Color borderStrong = _g.lineStrong; // --line-strong

  /// Border of a blue-washed panel — the tinted counterpart to [borderCard].
  static const Color borderTinted = Color(0x3D60A5FA);

  /// [cyan] at 18% — the bloom behind a selected/active glass panel.
  static const Color accentGlow = Color(0x2E22D3EE);

  /// Scrim behind a floating overlay on this surface (dropdown, map legend).
  static const Color scrim = Color(0x66000000);

  /// A panel floated over live content (the map card) — opaque enough to read
  /// against a moving map, translucent enough to show it is on top of one.
  static const Color surfaceCardFloating = Color(0xE60D1526);

  // ── Type ramp ──────────────────────────────────────────────────────────
  static final Color textStrong = _g.inkHi;
  static final Color textBody = _g.ink;
  static final Color textMuted = _g.inkMid;
  static final Color textDim = _g.inkLo;
  static final Color textFaint = _g.inkXlo;

  // ── Data hues ──────────────────────────────────────────────────────────
  static final Color green = _g.good;
  static final Color amber = _g.warn;
  static final Color red = _g.bad;
  static final Color cyan = _g.accent;
  static final Color cyanText = _g.accent2;
  static final Color teal = _g.accent3;
  static final Color violet = _g.violet;

  /// Two series hues with no glass-palette slot: the mock's legend runs
  /// cyan → violet → pink, and the mirror plots trips in sky blue.
  static const Color blue = Color(0xFF38BDF8);
  static const Color blueDeep = Color(0xFF2563EB);
  static const Color pink = Color(0xFFF472B6);
  static const Color coral = Color(0xFFFF7A5C); // --coral

  // ── Geometry ───────────────────────────────────────────────────────────
  static const double rCard = 20; // design: border-radius 20px
  static const double rTile = 14;

  /// One step below [pageBg] — an inset well on the darkest surface there is.
  static const Color surfaceSunken = Color(0xFF080D18);

  /// This palette expressed as an [MlSemantic], for the screens the console
  /// pushes that are **shared with the portal** and therefore take their
  /// palette as an argument rather than reading the theme.
  ///
  /// The Employee Register is the one that made this necessary: the console
  /// opens the same screen every company opens for itself, and the console's
  /// chrome does not follow the user's light/dark toggle, so the screen cannot
  /// either. It was previously a fourth hand-written copy of these values in
  /// `company_employee_register_screen.dart` — the same fork the company
  /// mirror carried, which is how the lineage of the divergence was traced.
  ///
  /// `borderAccent` is worth one note: the old copy used `#00B5D8` at 42%,
  /// which is the *pre-S5-5* accent. It now follows the current one.
  static final MlSemantic semantic = MlSemantic.custom(
    surfaceApp: pageBg,
    surfaceCard: surfaceCard,
    // Translucent white over the card — the tile fill the console uses
    // throughout, and the slot the register reads for it in dark.
    surfaceRaised: surfaceTile,
    surfaceSunken: surfaceSunken,
    textStrong: textStrong,
    textBody: textBody,
    textMuted: textMuted,
    textFaint: textDim,
    borderSubtle: tileBorder,
    borderCard: borderCard,
    borderStrong: borderStrong,
    borderAccent: MlTokens.accent.withValues(alpha: 0.42),
    divider: borderCard,
  );

  /// Ramp for the rail's utilisation donut — the design legend runs
  /// cyan → violet → pink, then a dim slate for the long tail.
  static final List<Color> donutRamp = [
    cyan,
    violet,
    pink,
    teal,
    blue,
    const Color(0xFF44536B),
  ];

  /// Ramp for the hero fleet-distribution donut. Mock legend runs
  /// cyan → violet → pink, with the long tail dropping to muted slate.
  static final List<Color> fleetRamp = [
    cyan,
    violet,
    pink,
    const Color(0xFF64748B),
    const Color(0xFF4A5A73),
    const Color(0xFF3A4759),
  ];
}
