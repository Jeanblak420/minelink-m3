// MineLink design tokens — the "Glass" surface palette.
//
// S5-2 (P5-03/P5-04/P5-05): extracted VERBATIM from
// `features/super_admin/widgets/insights_v2/minelink_screens_core.dart`
// 2026-08-13. Not a rewrite — the class body was carved out of that file
// rather than retyped, so the extraction cannot have changed a single value.
//
// It lives in core/design now because the Transporters Overview is no longer
// the only surface that wants it: S5-20/S5-21 migrate 54 portal screens onto
// the same vocabulary, and a token family that lives inside one feature's
// widget file is one that gets hand-copied instead of imported. That is how
// this codebase ended up with four accents and three sparklines.
//
// Zero package dependencies: Flutter SDK only.

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter/material.dart';

// ===========================================================================
// SECTION 2 — Glass tokens (Transporters Overview V3)
// ===========================================================================

/// The V3 "Glass" palette. This surface is dark-native: the whole treatment is
/// translucent panels floating over a deep gradient with a cyan wash. A light
/// variant is provided so the screen doesn't break inside a light app, but the
/// design is at its best on [dark].
@immutable
class MlGlass {
  const MlGlass({
    required this.isDark,
    required this.bg0,
    required this.bg1,
    required this.bg2,
    required this.panel,
    required this.panel2,
    required this.line,
    required this.line2,
    required this.lineStrong,
    required this.inkHi,
    required this.ink,
    required this.inkMid,
    required this.inkLo,
    required this.inkXlo,
    required this.accent,
    required this.accent2,
    required this.accent3,
    required this.good,
    required this.warn,
    required this.bad,
    required this.violet,
    required this.glassTop,
    required this.glassBottom,
    required this.glassBase,
  });

  final bool isDark;

  final Color bg0;
  final Color bg1;
  final Color bg2;
  final Color panel;
  final Color panel2;

  final Color line;
  final Color line2;
  final Color lineStrong;

  final Color inkHi;
  final Color ink;
  final Color inkMid;
  final Color inkLo;
  final Color inkXlo;

  final Color accent;
  final Color accent2;
  final Color accent3;
  final Color good;
  final Color warn;
  final Color bad;
  final Color violet;

  /// The three layers that make up a `.glass` panel: a top-to-bottom white
  /// wash over a translucent base.
  final Color glassTop;
  final Color glassBottom;
  final Color glassBase;

  // ---- The three faces, named once ----
  //
  // These were their own string literals — 'PlusJakartaSans', 'JetBrainsMono'
  // and 'Fraunces' spelled out here as well as in [MlTokens]. Two names for
  // one font, 153 uses on this side and 519 on the other, and nothing keeping
  // them in step: renaming an asset in `pubspec.yaml` would have fixed one
  // half of the product and silently broken the other, because a Flutter
  // `fontFamily` that does not resolve does not throw — it falls back.
  //
  // Aliases now. `MlTokens` is the raw scale and this is a surface palette, so
  // the raw scale is where a face name belongs.
  static const String sans = MlTokens.fontSans;
  static const String mono = MlTokens.fontMono;

  /// The flagship numeral face.
  static const String display = MlTokens.fontSerif;

  /// What draws a character the display face does not have — see
  /// [MlTokens.fontSerifFallback]. Named here so a site reaching for
  /// [display] does not have to reach into a second token file for the
  /// other half of the same decision.
  static const List<String> displayFallback = MlTokens.fontSerifFallback;

  // MlGlass used to carry four radii of its own — rSm 6, r 10, rLg 14, rXl 20,
  // a FOURTH set of corner values beside MlShape, MlTokens.r* and the literals
  // scattered through the screens. They are deleted rather than aliased: a
  // grep found ZERO uses. Aliasing them would have preserved a fourth name for
  // the shape scale that nothing needed, which is how a token file grows.
  // MlShape is the scale; there is no second opinion to keep in step.

  static const MlGlass dark = MlGlass(
    isDark: true,
    bg0: Color(0xFF060B15),
    bg1: Color(0xFF0A1220),
    bg2: Color(0xFF0F1A2E),
    panel: Color(0xFF0E1728),
    panel2: Color(0xFF131F35),
    // `line` was 0x0F white — 1.16:1 against the panel it draws on, which is
    // below the 1.25 floor `test/design/token_contrast_test.dart` sets for a
    // hairline being visible AT ALL. 0x18 is 1.30:1: still the quietest line
    // in the set, and now a line.
    line: Color(0x18FFFFFF),
    line2: Color(0x17FFFFFF),
    lineStrong: Color(0x24FFFFFF),
    inkHi: Color(0xFFEAF2FF),
    ink: Color(0xFFC7D2E4),
    inkMid: Color(0xFF8896AE),
    // The bottom two rungs were raised on 2026-08-21. Against the lightest
    // panel they measured 2.94:1 and **1.86:1**, and `inkXlo` is not
    // decoration — it writes "3 more — narrow the search to see them" and the
    // "—" that stands for a month with no actuals. They are 3.83:1 and 3.22:1
    // now, which is WCAG AA for large text, and the ladder still reads as five
    // distinct steps (14.6 / 10.8 / 5.5 / 3.8 / 3.2).
    inkLo: Color(0xFF6B7A9C),
    inkXlo: Color(0xFF606E8C),
    accent: Color(0xFF22D3EE),
    accent2: Color(0xFF7DD3FC),
    accent3: Color(0xFF5EEAD4),
    good: Color(0xFF34D399),
    warn: Color(0xFFF59E0B),
    bad: Color(0xFFF87171),
    violet: Color(0xFFA78BFA),
    glassTop: Color(0x0AFFFFFF),
    glassBottom: Color(0x03FFFFFF),
    glassBase: Color(0xBF0F1A2E),
  );

  /// Frosted-light counterpart. Same structure, inverted ground.
  static const MlGlass light = MlGlass(
    isDark: false,
    bg0: Color(0xFFEEF2F8),
    bg1: Color(0xFFF4F7FB),
    bg2: Color(0xFFFFFFFF),
    panel: Color(0xFFFFFFFF),
    panel2: Color(0xFFF3F6FA),
    // Same fix as the dark set, and the light side was further out: 1.17:1 for
    // the hairline, and an ink ladder whose bottom three rungs measured
    // 4.24 / 2.28 / **1.64**:1 against the page. This variant is documented as
    // "provided so the screen doesn't break inside a light app", and that is
    // exactly how it went unmeasured — the console has two light renders out
    // of 204.
    line: Color(0x1F0F172A),
    line2: Color(0x260F172A),
    lineStrong: Color(0x330F172A),
    inkHi: Color(0xFF0B1526),
    ink: Color(0xFF33415A),
    inkMid: Color(0xFF5A697F),
    inkLo: Color(0xFF6F7E94),
    inkXlo: Color(0xFF7C8AA0),
    accent: Color(0xFF0891B2),
    accent2: Color(0xFF0E7490),
    accent3: Color(0xFF0D9488),
    good: Color(0xFF059669),
    warn: Color(0xFFB45309),
    bad: Color(0xFFDC2626),
    violet: Color(0xFF7C3AED),
    glassTop: Color(0xCCFFFFFF),
    glassBottom: Color(0x99FFFFFF),
    glassBase: Color(0xE6FFFFFF),
  );

  static MlGlass of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Portal surfaces that are painted as a **gradient** rather than a fill.
///
/// `MlSemantic` names flat surfaces; a card whose fill is two stops has no
/// slot there, and the three that exist were each written out inline. They are
/// gradients on purpose — the portal's card and map canvas are large areas,
/// and a flat navy at that size reads as a hole rather than a surface.
///
/// Named at S5-19 (`ml_card.dart`, `ml_map_canvas.dart`).
abstract final class MlPortalSurfaces {
  const MlPortalSurfaces._();

  /// The portal card, dark: a lifted navy falling to the card surface.
  static const cardDarkTop = Color(0xFF122136);
  static const cardDarkBottom = Color(0xFF0E1B2E);

  /// The portal card, light: paper falling to the faintest cyan wash, which is
  /// what keeps a white card from disappearing into a white page.
  static const cardLightTop = Color(0xFFFFFFFF);
  static const cardLightBottom = Color(0xFFF2FBFD);

  /// The map canvas — the ground a route or a truck position is drawn on,
  /// before any tiles load. Deliberately a shade off the card either side of
  /// it, so an empty map reads as "no tiles yet" rather than as a blank card.
  static const mapDarkTop = Color(0xFF0D1930);
  static const mapDarkBottom = Color(0xFF101E36);
  static const mapLightTop = Color(0xFFEEF2F7);
  static const mapLightBottom = Color(0xFFF1F5F9);

  /// The map canvas's grid: a minor rule and a major one, in each theme.
  static const mapGridDark = Color(0x1494A3B8);
  static const mapGridDarkMajor = Color(0x2194A3B8);
  static const mapGridLight = Color(0x80CBD5E1);
  static const mapGridLightMajor = Color(0xFFE2E8F0);
}
