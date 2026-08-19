import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// The Material 3 **type scale**, cast in MineLink's three faces.
///
/// M3 has fifteen slots — display / headline / title / body / label, each in
/// large / medium / small. The shipping app had nine sizes of its own
/// (`fsDisplay … fsMicro`) and then `.apply(fontFamily: fontSans)` over the
/// whole `TextTheme`, which quietly overwrote every family assignment in it.
/// That is why twelve tonnage figures the portal drew in "Fraunces" were
/// actually rendering in the UI sans: the theme reset them on the way out.
///
/// This file assigns families **per slot** and never applies a family over the
/// finished theme, so a display numeral is genuinely a display numeral.
///
/// ## Which face does which job
///
/// From `docs/design-reference.md` §3 — three faces, three jobs:
///
/// - **Fraunces** (`fontSerif`) — `display*`. Headline figures and section
///   titles. Always tabular, because these are almost always numbers and a
///   proportional-digit figure counting up visibly jitters as it climbs.
/// - **Plus Jakarta Sans** (`fontSans`) — `headline*`, `title*`, `body*`,
///   `label*`. Everything the interface says in words.
/// - **JetBrains Mono** (`fontMono`) — never a theme slot. A plate, a waybill
///   number or a reference is asked for explicitly through `MlType.code`,
///   because it is a machine identifier rather than a size of text.
///
/// ## Sizes: M3's, with the display steps tempered
///
/// The headline / title / body / label slots use M3's specified sizes exactly.
/// They land close to what the app already used — `titleMedium` 16 matches the
/// old `fsTitle`, `labelMedium` 12 matches `fsLabel` — so dense screens are
/// unaffected.
///
/// The **display** steps are tempered one step down from M3's 57 / 45 / 36 to
/// 45 / 36 / 32. M3's display sizes are drawn for marketing surfaces and a
/// phone's hero area; this is a logistics console whose "display" text is a
/// tonnage sitting in a stat card next to five other stat cards. At 57px those
/// cards stop fitting four-across on a laptop, which is the layout the whole
/// dashboard is built around. The *scale* is M3's; the top three steps are
/// pitched for the surface they actually appear on.
abstract final class MlTypeScale {
  const MlTypeScale._();

  /// Tabular figures. On by default for display slots — see the class doc.
  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Builds the full M3 text theme in [color]'s ink.
  ///
  /// [color] is the scheme's `onSurface`; the variant slots are toned down by
  /// the component themes rather than here, so this stays one decision.
  static TextTheme textTheme(Color color) => TextTheme(
        // ---- display: Fraunces, tabular. Figures and section titles. ----
        displayLarge: TextStyle(
          fontFamily: MlTokens.fontSerif,
          fontSize: 45,
          height: 52 / 45,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.5,
          fontFeatures: _tabular,
          color: color,
        ),
        displayMedium: TextStyle(
          fontFamily: MlTokens.fontSerif,
          fontSize: 36,
          height: 44 / 36,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
          fontFeatures: _tabular,
          color: color,
        ),
        displaySmall: TextStyle(
          fontFamily: MlTokens.fontSerif,
          fontSize: 32,
          height: 40 / 32,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.2,
          fontFeatures: _tabular,
          color: color,
        ),

        // ---- headline: Plus Jakarta Sans, bold. Page and section titles. ----
        headlineLarge: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 32,
          height: 40 / 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.4,
          color: color,
        ),
        headlineMedium: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 28,
          height: 36 / 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: color,
        ),
        headlineSmall: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 24,
          height: 32 / 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: color,
        ),

        // ---- title: semibold. Card headers, dialog titles, app bar. ----
        titleLarge: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 22,
          height: 28 / 22,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
          color: color,
        ),
        titleMedium: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: color,
        ),
        titleSmall: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: color,
        ),

        // ---- body: regular. Prose, table cells, field values. ----
        bodyLarge: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 16,
          height: 24 / 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          color: color,
        ),
        bodyMedium: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          color: color,
        ),
        bodySmall: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          color: color,
        ),

        // ---- label: semibold, tracked. Buttons, chips, nav, overlines. ----
        labelLarge: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 14,
          height: 20 / 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: color,
        ),
        labelMedium: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 12,
          height: 16 / 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: color,
        ),
        labelSmall: TextStyle(
          fontFamily: MlTokens.fontSans,
          fontSize: 11,
          height: 16 / 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: color,
        ),
      );

  /// An **overline** — the small tracked uppercase label above a stat, a
  /// section, or a table group. Not an M3 slot (M3 dropped `overline` in the
  /// 2021 scale) but the console uses it constantly, so it is named here
  /// rather than re-specified with an inline `copyWith` at every site.
  static TextStyle overline(Color color) => TextStyle(
        fontFamily: MlTokens.fontSans,
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: color,
      );
}
