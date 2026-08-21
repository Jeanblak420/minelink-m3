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
    // ── THE BOTTOM THREE RUNGS, RESPACED 2026-08-21 (second pass) ─────────
    //
    // They were raised once already, to 3.83:1 and 3.22:1, on the grounds
    // that this is "WCAG AA for large text". It is not the right bar: these
    // rungs write 9-13px labels — "Seats used", "of 5 on this company",
    // "PLANNED" — and AA asks **4.5:1** of anything under 24px. Measured on
    // the pixels rather than on the token pair, `inkLo` was 416 low-contrast
    // strings and `inkXlo` 59.
    //
    // Raising only the bottom two does not work, and the arithmetic is what
    // decides it rather than taste. On the lightest ground these are actually
    // measured against, reaching 4.5:1 needs `inkLo` at #8693AE and `inkXlo`
    // at #8893A9 — two colours no reader can tell apart, sitting on top of an
    // `inkMid` of #8896AE that is the SAME COLOUR AGAIN. Below the legibility
    // floor there was room for one rung and the ladder was asking for three.
    //
    // So `inkMid` moves up to open the space, and all three are respaced
    // across the range that is left. Five distinct steps, none of them under
    // 4.5:1 on any ground in the product (worst column, `#1C2C46`):
    //
    //             was            now      on #131F35   worst
    //     inkHi   #EAF2FF        —          14.62      12.44
    //     ink     #C7D2E4        —          10.80       9.19
    //     inkMid  #8896AE   -> #A7B3C6       7.77       6.61
    //     inkLo   #6B7A9C   -> #93A0B5       6.22       5.30
    //     inkXlo  #606E8C   -> #8695AC       5.42       4.61
    //
    // The hue is untouched — every value is the old one moved along its own
    // line toward white, so the set still reads as one slate family.
    inkMid: Color(0xFFA7B3C6),
    inkLo: Color(0xFF93A0B5),
    inkXlo: Color(0xFF8695AC),
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
    // Same respacing as the dark set, same reason, mirrored: the bottom three
    // were 4.97 / 3.67 / 3.12:1 against the page, which is 134 low-contrast
    // strings. Moved along their own line toward black instead of white.
    //
    //             was            now      on #FFFFFF   worst (#E2EAF1)
    //     inkMid  #5A697F   -> #455368       7.81        6.42
    //     inkLo   #6F7E94   -> #525F76       6.45        5.30
    //     inkXlo  #7C8AA0   -> #5C6980       5.54        4.56
    inkMid: Color(0xFF455368),
    inkLo: Color(0xFF525F76),
    inkXlo: Color(0xFF5C6980),
    // ── THE LIGHT HUE SET, DEEPENED 2026-08-21 ──────────────────────────
    //
    // These are used as INK far more than as a fill, and the light surface
    // they land on is not white: this is the "glass" treatment, a translucent
    // panel over a cyan wash, so a card's real ground composites to #DCEAEE,
    // #C2DBE6, #B9DFE8 - noticeably darker and more saturated than paper.
    // Against those, the paper-tuned values measured 2.55-3.10:1 and put the
    // leaderboard's own title, its tonnage and every chip on it under AA.
    //
    // Deepened until each clears 4.5:1 on the WORST glass ground it lands on
    // (worst column below is #C2DBE6 / #E5D9D2):
    //
    //           was        now      on white   worst
    //     accent #0891B2 -> #05637A    6.84      4.74
    //     accent2#0E7490 -> #0E5A80    7.52      5.22
    //     accent3#0D9488 -> #09665E    6.83      4.74
    //     good  #047C57 -> #036B4B    6.55      4.54
    //     warn  #B45309 -> #984608    6.53      4.53
    //     bad   #C82323 -> #B62020    6.53      4.53
    //
    // `accent` and `accent2` are two different HUES (cyan and sky), not two rungs
    // of one ladder, so `accent2` is pushed toward blue rather than simply
    // darkened - solving both to the same target had landed them on #05637A
    // and #0C637C, which is one colour twice and would have collapsed two
    // series in every chart.
    accent: Color(0xFF05637A),
    accent2: Color(0xFF0E5A80),
    accent3: Color(0xFF09665E),
    good: Color(0xFF036B4B),
    warn: Color(0xFF984608),
    bad: Color(0xFFB62020),
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
