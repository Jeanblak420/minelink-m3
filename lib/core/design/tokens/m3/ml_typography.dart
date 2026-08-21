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
          fontFamilyFallback: MlTokens.fontSerifFallback,
          fontSize: 45,
          height: 52 / 45,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.5,
          fontFeatures: _tabular,
          color: color,
        ),
        displayMedium: TextStyle(
          fontFamily: MlTokens.fontSerif,
          fontFamilyFallback: MlTokens.fontSerifFallback,
          fontSize: 36,
          height: 44 / 36,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.3,
          fontFeatures: _tabular,
          color: color,
        ),
        displaySmall: TextStyle(
          fontFamily: MlTokens.fontSerif,
          fontFamilyFallback: MlTokens.fontSerifFallback,
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

  /// The **editorial** rungs — Fraunces at title size, not at hero size.
  ///
  /// `docs/design-reference.md` §3 gives the serif two jobs: *"section titles,
  /// **and** every large numeral"*. Only the second was on the scale. The
  /// `display` slots are 45 / 36 / 32, which is the numeral; a Fraunces
  /// *section title* is 16–26 across 20 sites in this tree and had no rung at
  /// all, so every one of them was hand-written and picked up `bodyMedium`'s
  /// line box on the way past.
  ///
  /// Three steps, at **24 / 20 / 16**, chosen so that the sizes actually in use
  /// (16, 18, 19, 20, 21, 22, 24, 26) each move by at most 2px.
  ///
  /// **Each rung shares the line box of the sans title slot at its own size**,
  /// so a serif title and a sans title on the same row sit on the same
  /// baseline: `editorialLarge` takes `headlineSmall`'s 32/24, `editorialSmall`
  /// takes `titleMedium`'s 24/16, and `editorialMedium` — which has no sans
  /// twin at 20 — interpolates.
  ///
  /// Weight is w500, the same as the display slots, because Fraunces Medium is
  /// the face's own regular here. A title wanting more says so:
  /// `context.mlText.editorialLarge.copyWith(fontWeight: FontWeight.w600)`.
  /// Only 500, 500-italic and 600 are registered (`pubspec.yaml`) — asking for
  /// w400 or w700 silently renders one of those three.
  ///
  /// Deliberately **not** tabular. `MlType.figure` is tabular because a numeral
  /// that re-measures every frame visibly jitters; a title is words, and
  /// tabular spacing in running words looks typed rather than set.
  static TextStyle editorial(double size, double height, double tracking,
          Color color) =>
      TextStyle(
        fontFamily: MlTokens.fontSerif,
        fontFamilyFallback: MlTokens.fontSerifFallback,
        fontSize: size,
        height: height,
        fontWeight: FontWeight.w500,
        letterSpacing: tracking,
        color: color,
      );
}

/// The type scale as a screen reaches for it: `context.mlText.titleSmall`.
///
/// ## Why this exists rather than `TextStyle(fontFamily: …, fontSize: …)`
///
/// A `TextStyle` built from scratch carries **only** what is written into it.
/// Everything else — `height`, `letterSpacing` — is inherited from whatever
/// `DefaultTextStyle` happens to be in scope, and inside a `Scaffold` that is
/// `bodyMedium`. So a hand-written 15px w800 conversation title was drawn with
/// **body** metrics: line height 1.43 where a title wants 1.27, and
/// letterSpacing +0.25 where a bold title wants −0.1. It looked *nearly* right,
/// which is why ~500 sites accumulated across the product and why line spacing
/// visibly differs between two cards on the same screen.
///
/// Reaching a slot fixes both, because the slot states them.
///
/// ## Why the slots are non-null here
///
/// `TextTheme`'s fields are `TextStyle?`. In this app they are never null —
/// `MlTypeScale.textTheme` fills all fifteen — but the type system does not know
/// that, so every call site would end in `!`. Five hundred `!`s is five hundred
/// places a reader has to decide whether the bang is safe. It is decided once,
/// here.
///
/// ## Choosing a slot
///
/// | you are drawing | slot |
/// |---|---|
/// | a tonnage, a headline figure | [figure] (Fraunces, tabular) |
/// | a plate, a waybill number, a reference | [code] (JetBrains Mono) |
/// | a section title **in the serif** | `editorialLarge` / `Medium` / `Small` |
/// | a page title | `headlineSmall` / `headlineMedium` |
/// | a card or dialog title | `titleMedium` (16) / `titleSmall` (14) |
/// | a list-row title | `titleSmall` |
/// | prose, a table cell, a field value | `bodyMedium` (14) / `bodySmall` (12) |
/// | a button, chip, tab or nav label | `labelLarge` (14) / `labelMedium` (12) |
/// | a tracked uppercase caption above a group | [overline] |
///
/// Weight and colour are the two things a site legitimately varies, and both
/// go through `copyWith` so the slot's metrics survive:
///
/// ```dart
/// style: context.mlText.titleSmall.copyWith(
///   color: pal.headerText,
///   fontWeight: FontWeight.w700,
/// ),
/// ```
final class MlText {
  const MlText._(this._t);

  /// The active scale above [context].
  factory MlText.of(BuildContext context) =>
      MlText._(Theme.of(context).textTheme);

  /// The scale of a [TextTheme] held directly.
  ///
  /// Prefer [of] wherever there is a `BuildContext`. This exists for the same
  /// reason `MlSemantic.from(Brightness)` does — the handful of places with no
  /// context at all: a document rendered off-screen, and the tests that assert
  /// on the styles themselves rather than on what they measure.
  const MlText.forTheme(TextTheme theme) : _t = theme;

  final TextTheme _t;

  // ---- display: Fraunces, tabular ----
  TextStyle get displayLarge => _t.displayLarge!;
  TextStyle get displayMedium => _t.displayMedium!;
  TextStyle get displaySmall => _t.displaySmall!;

  // ---- headline: Plus Jakarta Sans, bold ----
  TextStyle get headlineLarge => _t.headlineLarge!;
  TextStyle get headlineMedium => _t.headlineMedium!;
  TextStyle get headlineSmall => _t.headlineSmall!;

  // ---- title: semibold ----
  TextStyle get titleLarge => _t.titleLarge!;
  TextStyle get titleMedium => _t.titleMedium!;
  TextStyle get titleSmall => _t.titleSmall!;

  // ---- body: regular ----
  TextStyle get bodyLarge => _t.bodyLarge!;
  TextStyle get bodyMedium => _t.bodyMedium!;
  TextStyle get bodySmall => _t.bodySmall!;

  // ---- label: semibold, tracked ----
  TextStyle get labelLarge => _t.labelLarge!;
  TextStyle get labelMedium => _t.labelMedium!;
  TextStyle get labelSmall => _t.labelSmall!;

  // ---- editorial: Fraunces at title size. See [MlTypeScale.editorial]. ----
  TextStyle get editorialLarge =>
      MlTypeScale.editorial(24, 32 / 24, -0.2, _ink);
  TextStyle get editorialMedium =>
      MlTypeScale.editorial(20, 26 / 20, -0.15, _ink);
  TextStyle get editorialSmall =>
      MlTypeScale.editorial(16, 24 / 16, -0.1, _ink);

  /// The tracked uppercase caption. See [MlTypeScale.overline].
  ///
  /// A getter rather than a method so it reads like every other slot; colour
  /// goes through `copyWith` as it does everywhere else.
  TextStyle get overline => MlTypeScale.overline(_ink);

  /// The theme's own ink, for the slots this class synthesises rather than
  /// reads. `onSurface` is what `MlTypeScale.textTheme` was built with.
  Color get _ink => _t.bodyMedium?.color ?? const Color(0xFF0F172A);

  /// A **display numeral** — see [MlType.figure].
  TextStyle figure({Color? color, double? size, double? height}) =>
      MlType.figure(
        color: color ?? _ink,
        size: size ?? MlTokens.fsH2,
        height: height,
      );

  /// A **machine identifier** — see [MlType.code].
  TextStyle code({
    Color? color,
    double size = MlTokens.fsBody,
    FontWeight weight = FontWeight.w600,
    double? letterSpacing,
  }) =>
      MlType.code(
        color: color ?? _ink,
        size: size,
        weight: weight,
        letterSpacing: letterSpacing,
      );
}

/// `context.mlText` — the type scale, without writing `Theme.of(context)`.
extension MlTextOnContext on BuildContext {
  /// The active [MlText] scale. See that class for how to choose a slot.
  MlText get mlText => MlText.of(this);
}
