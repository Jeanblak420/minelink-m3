// ============================================================================
// Transporters overview — design tokens
// ----------------------------------------------------------------------------
// A direct port of the 2026-08-09 "Replacing old views and screens" drop
// (`flutter_transporters_overview/lib/transporters_overview/theme/
// overview_tokens.dart`). Every value in [MlOv.dark] is byte-for-byte what the
// drop shipped, and the drop is explicit that they must not be rounded or
// re-derived — the reference render depends on them exactly. If you are about
// to "improve" one, read the drop's README §4 first.
//
// TWO DEVIATIONS from the drop, both deliberate:
//
//  1. The class is named `MlOv`, not `MlTokens`. `MlTokens` is already the
//     app-wide token class (`lib/core/design/tokens/ml_tokens.dart`) and CLAUDE.md §1
//     makes it law; a second class of the same name in the same tree is a trap
//     waiting for the first file that imports both.
//
//  2. The drop is dark-only. The super-admin console is not: every screen is
//     rendered under `UiPrefs.darkMode`, which each admin sets for
//     themselves (`super_admin_shell_layout.dart`). A screen that ignored that
//     toggle would be a visible fault, so this carries a [light] counterpart.
//     Its values are lifted from `MlGlass.light` — the light palette this
//     surface already shipped with — rather than invented here.
// ============================================================================

import 'package:flutter/material.dart';

/// The colour slots a view-model may ask for by name.
///
/// The models stay `Color`-free on purpose: a tone survives the light/dark
/// toggle, a baked-in `Color(0x...)` does not.
enum OvTone {
  accent,
  sky,
  teal,
  good,
  warn,
  bad,
  violet,
  pink,
  slate,
  slateDark,
  ink,

  /// The faintest ink on the surface. What a cell with nothing to report is
  /// painted in — an em dash must not carry the weight of a real figure, and it
  /// must never be mistaken for a bad one.
  muted,
}

@immutable
class MlOv {
  const MlOv({
    required this.isDark,
    required this.canvas,
    required this.inkHi,
    required this.ink,
    required this.inkMid,
    required this.inkLo,
    required this.inkXlo,
    required this.acc,
    required this.acc2,
    required this.acc3,
    required this.good,
    required this.warn,
    required this.bad,
    required this.violet,
    required this.pink,
    required this.slate500,
    required this.slate700,
    required this.glassBase,
    required this.accentBase,
    required this.accentCardGround,
    required this.markerFill,
    required this.railDotFill,
    required this.avatarInner,
    required this.calloutFill,
    required this.trophyInk,
    required this.inkOnAccent,
    required this.inkOnAccentMuted,
    required this.cardShadow,
    required this.accentCardShadow,
  });

  final bool isDark;

  /// Page background behind the body.
  final Color canvas;

  final Color inkHi;
  final Color ink;
  final Color inkMid;
  final Color inkLo;
  final Color inkXlo;

  final Color acc; // cyan
  final Color acc2; // sky
  final Color acc3; // teal
  final Color good;
  final Color warn;
  final Color bad;
  final Color violet;
  final Color pink;
  final Color slate500;
  final Color slate700;

  /// Fill of a normal glass card.
  final Color glassBase;

  /// Fill of the one accent card (the leaderboard).
  final Color accentBase;

  /// The OPAQUE ground the leaderboard's winner card is painted on.
  ///
  /// Distinct from [accentBase], which is translucent by design so the canvas
  /// shows through a glass panel. The winner card cannot afford that: its
  /// parent draws a cyan glow at 60% with a 48px blur and a -22 spread, so
  /// the glow's blurred rect covers the card's own interior and came straight
  /// through it - the body composited to a flat mid teal (#1D8FA4) on which
  /// nothing was legible, white included at 3.81:1.
  ///
  /// So this card gets a ground of its own and the glow stays outside, where
  /// a glow belongs.
  final Color accentCardGround;

  /// Solid fills that sit *under* translucent art, so they cannot be an
  /// overlay: the hollow chart marker, the rail chart's end dot, the inside of
  /// a transporter avatar ring, and the callout chip.
  final Color markerFill;
  final Color railDotFill;
  final Color avatarInner;
  final Color calloutFill;

  /// The glyph punched out of the teal→cyan trophy chip and rank-1 badge.
  final Color trophyInk;

  /// Ink for text drawn ON an accent surface — the winner's podium card, whose
  /// ground is an accent gradient rather than the canvas.
  ///
  /// It exists because the podium painted `acc2` and `inkMid` on that
  /// gradient. On the dark canvas that is a light cyan on a dark teal and it
  /// reads; in light mode it is a mid teal on a mid teal, and "RANK 01",
  /// "4,382.6 t" and "65.4% of network · 128 trips" all measured **2.2:1** —
  /// the three lines the card exists to say. Found 2026-08-21 by rendering the
  /// leaderboard in light for the first time.
  ///
  /// A token audit cannot find this one: both colours are legible on the
  /// surfaces the palette knows about. Only a gradient the widget builds
  /// itself puts them together.
  final Color inkOnAccent;

  /// The quieter half of [inkOnAccent] — the share line under the meter.
  final Color inkOnAccentMuted;

  final List<BoxShadow> cardShadow;
  final List<BoxShadow> accentCardShadow;

  // ------------------------------------------------------------------ dark
  /// Exactly the drop's values. Do not adjust.
  static const MlOv dark = MlOv(
    isDark: true,
    canvas: Color(0xFF0A1120),
    inkHi: Color(0xFFEAF2FF),
    ink: Color(0xFFC7D2E4),
    // Respaced 2026-08-21 (second pass) in lockstep with `MlGlass.dark` —
    // see the table there for the reasoning and the measured ratios. The two
    // sets have always carried an identical ink ladder, and
    // `test/design/ink_ladder_test.dart` now fails if they drift apart, which
    // is cheaper than the comment that used to ask for it.
    //
    // The first pass stopped at AA-for-LARGE-text (3.0). These rungs write
    // 9-13px labels, so the bar is 4.5, and reaching it needed the middle
    // rung to move as well: below the floor there was room for one step and
    // the ladder wanted three.
    inkMid: Color(0xFFA7B3C6),
    inkLo: Color(0xFF93A0B5),
    inkXlo: Color(0xFF8695AC),
    acc: Color(0xFF22D3EE),
    acc2: Color(0xFF7DD3FC),
    acc3: Color(0xFF5EEAD4),
    good: Color(0xFF34D399),
    warn: Color(0xFFF59E0B),
    bad: Color(0xFFF87171),
    violet: Color(0xFFA78BFA),
    pink: Color(0xFFF472B6),
    slate500: Color(0xFF64748B),
    slate700: Color(0xFF334155),
    glassBase: Color(0xBF0F1A2E),
    accentBase: Color(0xE60F1A2E),
    accentCardGround: Color(0xFF0F1A2E),
    markerFill: Color(0xFF0C1930),
    railDotFill: Color(0xFF0F1A2E),
    avatarInner: Color(0xFF0E1728),
    calloutFill: Color(0xEB060B15),
    trophyInk: Color(0xFF062A33),
    // Dark: the podium's ground is a dark teal panel, so the accent inks the
    // rest of the console uses are already the right ones.
    inkOnAccent: Color(0xFF7DD3FC),
    inkOnAccentMuted: Color(0xFF8896AE),
    cardShadow: [
      BoxShadow(
        color: Color(0xCC000000),
        blurRadius: 32,
        spreadRadius: -20,
        offset: Offset(0, 12),
      ),
    ],
    accentCardShadow: [
      BoxShadow(color: Color(0x8C22D3EE), blurRadius: 44, spreadRadius: -22),
      BoxShadow(
        color: Color(0xE6000000),
        blurRadius: 40,
        spreadRadius: -24,
        offset: Offset(0, 18),
      ),
    ],
  );

  // ----------------------------------------------------------------- light
  /// Frosted-light counterpart, taken from `MlGlass.light`.
  static const MlOv light = MlOv(
    isDark: false,
    canvas: Color(0xFFEEF2F8),
    inkHi: Color(0xFF0B1526),
    ink: Color(0xFF33415A),
    // Same values as `MlGlass.light`, respaced with it — the pairing is
    // pinned by `test/design/ink_ladder_test.dart` rather than by this note.
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
    //     acc   #0891B2 -> #05637A    6.84      4.74
    //     acc2  #0E7490 -> #0E5A80    7.52      5.22
    //     acc3  #0D9488 -> #09665E    6.83      4.74
    //     good  #047C57 -> #036B4B    6.55      4.54
    //     warn  #B45309 -> #984608    6.53      4.53
    //     bad   #C82323 -> #B62020    6.53      4.53
    //
    // `acc` and `acc2` are two different HUES (cyan and sky), not two rungs
    // of one ladder, so `acc2` is pushed toward blue rather than simply
    // darkened - solving both to the same target had landed them on #05637A
    // and #0C637C, which is one colour twice and would have collapsed two
    // series in every chart.
    acc: Color(0xFF05637A),
    acc2: Color(0xFF0E5A80),
    acc3: Color(0xFF09665E),
    good: Color(0xFF036B4B),
    warn: Color(0xFF984608),
    bad: Color(0xFFB62020),
    violet: Color(0xFF7C3AED),
    pink: Color(0xFFDB2777),
    slate500: Color(0xFF64748B),
    slate700: Color(0xFF334155),
    glassBase: Color(0xE6FFFFFF),
    accentBase: Color(0xF2FFFFFF),
    accentCardGround: Color(0xFFFFFFFF),
    markerFill: Color(0xFFFFFFFF),
    railDotFill: Color(0xFFFFFFFF),
    avatarInner: Color(0xFFF3F6FA),
    calloutFill: Color(0xF7FFFFFF),
    trophyInk: Color(0xFFFFFFFF),
    // Light: the podium's ground composites to a mid teal (#57B2C8 measured
    // off the render), which needs DARK ink. 5.6:1 and 5.0:1.
    inkOnAccent: Color(0xFF06333D),
    inkOnAccentMuted: Color(0xFF0B3A46),
    cardShadow: [
      BoxShadow(
        color: Color(0x1A0F172A),
        blurRadius: 32,
        spreadRadius: -20,
        offset: Offset(0, 12),
      ),
    ],
    accentCardShadow: [
      BoxShadow(color: Color(0x330891B2), blurRadius: 44, spreadRadius: -22),
      BoxShadow(
        color: Color(0x1F0F172A),
        blurRadius: 40,
        spreadRadius: -24,
        offset: Offset(0, 18),
      ),
    ],
  );

  static MlOv of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  // ------------------------------------------------------------- overlays
  /// The hairlines and washes the design expresses as `rgba(255,255,255,a)`.
  ///
  /// On dark this reproduces the drop exactly — `overlay(0.06)` is `0x0FFFFFFF`
  /// to the byte. On light the same alpha is laid in ink instead, because white
  /// on white is nothing at all.
  Color overlay(double alpha) =>
      (isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A))
          .withValues(alpha: alpha);

  /// `rgba(255,255,255,.06)` — card hairline, tile border.
  Color get line => overlay(0.06);

  /// `rgba(255,255,255,.09)` — divider, stronger tile border.
  Color get line2 => overlay(0.09);

  /// `rgba(255,255,255,.14)` — the strongest hairline on the surface.
  Color get lineS => overlay(0.14);

  /// The card's top-to-bottom sheen: white 4% → white 1%.
  LinearGradient get glassSheen => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [overlay(0.04), overlay(0.01)],
      );

  /// The cyan bloom anchored above every card's top edge:
  /// `radial-gradient(400px 200px at 50% -20%, rgba(34,211,238,.12), transparent 60%)`
  RadialGradient get cardBloom => RadialGradient(
        center: const Alignment(0, -1.4),
        radius: 0.95,
        colors: [acc.withValues(alpha: 0.12), acc.withValues(alpha: 0)],
        stops: const [0, 0.6],
      );

  /// Page-level ambient wash behind the whole body.
  RadialGradient get ambientLeft => RadialGradient(
        center: const Alignment(-0.6, -1),
        radius: 0.9,
        colors: [acc.withValues(alpha: 0.08), acc.withValues(alpha: 0)],
        stops: const [0, 0.6],
      );

  RadialGradient get ambientRight => RadialGradient(
        center: const Alignment(1, -0.2),
        radius: 0.9,
        colors: [acc3.withValues(alpha: 0.05), acc3.withValues(alpha: 0)],
        stops: const [0, 0.6],
      );

  Color tone(OvTone t) {
    switch (t) {
      case OvTone.accent:
        return acc;
      case OvTone.sky:
        return acc2;
      case OvTone.teal:
        return acc3;
      case OvTone.good:
        return good;
      case OvTone.warn:
        return warn;
      case OvTone.bad:
        return bad;
      case OvTone.violet:
        return violet;
      case OvTone.pink:
        return pink;
      case OvTone.slate:
        return slate500;
      case OvTone.slateDark:
        return slate700;
      case OvTone.ink:
        return inkHi;
      case OvTone.muted:
        return inkXlo;
    }
  }

  /// Donut slice order from the drop: cyan · violet · pink · slate · dark slate.
  List<Color> get donutPalette => [acc, violet, pink, slate500, slate700];

  // ------------------------------------------------------------------ radii
  static const double rCard = 20;
  static const double rRow = 13;
  static const double rTile = 12;
  static const double rChip = 10;
  static const double rWell = 9;
  static const double rPill = 999;

  // ----------------------------------------------------------------- layout
  static const double mainBasis = 720;
  static const double mainMin = 560;
  static const double asideBasis = 300;
  static const double asideMin = 290;
  static const double columnGap = 18;

  // ------------------------------------------------------------------- type
  static const String sans = 'PlusJakartaSans';
  static const String mono = 'JetBrainsMono';
  static const String serif = 'Fraunces';

  /// What draws a character Fraunces does not have.
  ///
  /// The reasoning and the seven characters are on
  /// `MlTokens.fontSerifFallback`; spelled out here because this file is a
  /// byte-for-byte port that imports nothing but Flutter, and pinned against
  /// that constant by `one_type_scale_test.dart`.
  static const List<String> serifFallback = <String>[sans];

  TextStyle s({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? style,
  }) =>
      TextStyle(
        fontFamily: sans,
        fontSize: size,
        fontWeight: weight,
        color: color ?? ink,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: style,
      );

  TextStyle m({
    double size = 12,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? letterSpacing,
    double? height,
  }) =>
      TextStyle(
        fontFamily: mono,
        fontSize: size,
        fontWeight: weight,
        color: color ?? inkHi,
        letterSpacing: letterSpacing,
        height: height,
        // Tabular figures keep a column of tonnages from shuffling sideways as
        // the numbers change under realtime.
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Fraunces. The drop asks for w400 on the flagship numeral; only Medium and
  /// SemiBold are bundled (`pubspec.yaml`), so w500 is the display cut here.
  TextStyle f({
    double size = 17,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? letterSpacing,
    double? height,
    FontStyle? style,
  }) =>
      TextStyle(
        fontFamily: serif,
        fontFamilyFallback: serifFallback,
        fontSize: size,
        fontWeight: weight,
        color: color ?? inkHi,
        letterSpacing: letterSpacing,
        height: height,
        fontStyle: style,
      );

  /// The repeated 11px / 0.16em uppercase card eyebrow.
  TextStyle get eyebrow =>
      s(size: 11, weight: FontWeight.w600, color: inkMid, letterSpacing: 1.76);

  /// The repeated 10px / 0.12em uppercase metric label.
  TextStyle get metricLabel =>
      s(size: 10, weight: FontWeight.w600, color: inkMid, letterSpacing: 1.2);
}
