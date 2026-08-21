import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// The **navy chrome** — the navigation rail, the drawer, and the workspace
/// canvas they frame.
///
/// ## Why this is a `ThemeExtension` and not a `ColorScheme` role
///
/// MineLink's rail is navy in *both* themes. That is a deliberate brand
/// decision and it is the single thing that makes a MineLink screenshot
/// recognisable at a glance. But it means the rail cannot be expressed as a
/// surface role: `surfaceContainer` is near-white in light and near-black in
/// dark — that is what those roles *mean* — so anything painted with one
/// inverts between themes. The shipping app's answer was five more token files
/// (`ml_rail_tokens`, `ml_sidebar_tokens`, `ml_sidebar_skin_palettes`,
/// `ml_console_palettes`, `ml_control_room_palette`), each a private palette
/// with no relationship to the scheme or to each other.
///
/// `ThemeExtension` is Material 3's supported answer to exactly this: a brand
/// role that travels with the theme, is interpolated on theme change, and is
/// reachable from any `BuildContext` without a new inherited widget. One type
/// replaces those five files.
///
/// Read it with `MlChrome.of(context)`.
@immutable
class MlChrome extends ThemeExtension<MlChrome> {
  /// The rail's vertical gradient. Two stops, from
  /// `ui_kits/shared/shell.jsx`'s `linear-gradient(168deg,#0c1c34,#050b18)`.
  final Color railTop;
  final Color railBottom;

  /// The fill behind the **selected** destination. M3 calls this the
  /// navigation indicator; it is a stadium, and on navy it has to be a tint
  /// rather than a solid or it fights the accent bar beside it.
  final Color railIndicator;

  /// The 3dp bar marking the selected destination, inset at the leading edge.
  final Color railActiveBar;

  /// Icon and label ink on the rail, unselected and selected.
  final Color railIcon;
  final Color railIconSelected;
  final Color railLabel;
  final Color railLabelSelected;

  /// The hairline between the rail and the workspace, and between rail groups.
  final Color railDivider;

  /// The rail's section headings ("OPERATIONS", "INSIGHTS").
  final Color railSectionLabel;

  /// The workspace the content sits on. In dark this is the scheme's surface;
  /// in light it is a cool dotted field rather than flat white, which is what
  /// stops a page of white cards reading as one undifferentiated sheet.
  final Color canvasBase;
  final Color canvasDot;

  /// The top app bar, which floats over the canvas rather than sitting on it.
  final Color topBarSurface;
  final Color topBarBorder;

  /// The brand wordmark's cyan→blue gradient.
  final Color wordmarkStart;
  final Color wordmarkEnd;

  /// The coloured bloom under a raised filled button — the fill's own hue at
  /// ~35%, so it reads as light coming off the control rather than as a grey
  /// shadow beneath it.
  final Color glowAccent;

  /// The scrim behind a modal. Slate-900 rather than black, so the page behind
  /// cools rather than greys.
  final Color scrimStrong;
  final Color scrimSoft;

  const MlChrome({
    required this.railTop,
    required this.railBottom,
    required this.railIndicator,
    required this.railActiveBar,
    required this.railIcon,
    required this.railIconSelected,
    required this.railLabel,
    required this.railLabelSelected,
    required this.railDivider,
    required this.railSectionLabel,
    required this.canvasBase,
    required this.canvasDot,
    required this.topBarSurface,
    required this.topBarBorder,
    required this.wordmarkStart,
    required this.wordmarkEnd,
    required this.glowAccent,
    required this.scrimStrong,
    required this.scrimSoft,
  });

  /// Light theme: navy rail against a dotted cool-grey workspace.
  static const MlChrome light = MlChrome(
    railTop: MlTokens.sidebarGradientTop,
    railBottom: MlTokens.sidebarGradientBottom,
    railIndicator: Color(0x2422D3EE),
    railActiveBar: MlTokens.cyan400,
    railIcon: Color(0xFF9FB2CC),
    railIconSelected: MlTokens.cyan400,
    railLabel: Color(0xFFB8C6DA),
    railLabelSelected: Color(0xFFF2F8FF),
    railDivider: Color(0x1F94A3B8),
    railSectionLabel: Color(0xFF6E8099),
    canvasBase: MlTokens.slate50,
    canvasDot: Color(0x14475569),
    topBarSurface: Color(0xFFFFFFFF),
    topBarBorder: Color(0xFFE7EDF3),
    wordmarkStart: MlTokens.wordmarkGradientStart,
    wordmarkEnd: MlTokens.wordmarkGradientEnd,
    glowAccent: MlTokens.glowAccent,
    scrimStrong: MlTokens.barrierStrong,
    scrimSoft: MlTokens.barrierSoft,
  );

  /// Dark theme: the rail deepens so it still separates from the workspace.
  ///
  /// In light the rail is the darkest thing on screen and separates by
  /// contrast. In dark the workspace is already dark, so the rail has to go
  /// *below* it — `navy950`/`#020617` against a `#0A1424` canvas — or the two
  /// merge into one field and the navigation stops reading as a distinct
  /// region. This is why the rail is not simply the same two colours in both.
  static const MlChrome dark = MlChrome(
    railTop: Color(0xFF07101F),
    railBottom: MlTokens.navy950,
    railIndicator: Color(0x2E22D3EE),
    railActiveBar: MlTokens.cyan400,
    railIcon: Color(0xFF8496B0),
    railIconSelected: MlTokens.cyan400,
    railLabel: Color(0xFFA5B5CB),
    railLabelSelected: Color(0xFFF2F8FF),
    railDivider: Color(0x1F94A3B8),
    // 4.05:1 on `railTop`, in 88 renders — every section heading in the
    // console's rail ("OPERATIONS", "INSIGHTS", "ADMIN"). 11px, so the bar is
    // 4.5. #7385A0 is 5.07:1 against the same navy, still a step below
    // `railLabel` (#A5B5CB, 8.5:1), which is the distinction it exists to
    // draw.
    railSectionLabel: Color(0xFF7385A0),
    canvasBase: Color(0xFF0A1424),
    canvasDot: Color(0x14FFFFFF),
    topBarSurface: Color(0xFF0D1829),
    topBarBorder: Color(0xFF1E2C44),
    wordmarkStart: MlTokens.wordmarkGradientStart,
    wordmarkEnd: MlTokens.wordmarkGradientEnd,
    glowAccent: MlTokens.glowAccent,
    scrimStrong: Color(0x99020617),
    scrimSoft: Color(0x66020617),
  );

  static MlChrome from(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  /// The chrome for [context]'s theme.
  ///
  /// Falls back to the brightness default when no extension is installed, so a
  /// widget rendered under a bare `ThemeData` in a test still gets sane colours
  /// instead of a null crash.
  static MlChrome of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<MlChrome>() ?? from(theme.brightness);
  }

  /// The rail's gradient, ready to paint.
  LinearGradient get railGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [railTop, railBottom],
      );

  @override
  MlChrome copyWith({
    Color? railTop,
    Color? railBottom,
    Color? railIndicator,
    Color? railActiveBar,
    Color? railIcon,
    Color? railIconSelected,
    Color? railLabel,
    Color? railLabelSelected,
    Color? railDivider,
    Color? railSectionLabel,
    Color? canvasBase,
    Color? canvasDot,
    Color? topBarSurface,
    Color? topBarBorder,
    Color? wordmarkStart,
    Color? wordmarkEnd,
    Color? glowAccent,
    Color? scrimStrong,
    Color? scrimSoft,
  }) =>
      MlChrome(
        railTop: railTop ?? this.railTop,
        railBottom: railBottom ?? this.railBottom,
        railIndicator: railIndicator ?? this.railIndicator,
        railActiveBar: railActiveBar ?? this.railActiveBar,
        railIcon: railIcon ?? this.railIcon,
        railIconSelected: railIconSelected ?? this.railIconSelected,
        railLabel: railLabel ?? this.railLabel,
        railLabelSelected: railLabelSelected ?? this.railLabelSelected,
        railDivider: railDivider ?? this.railDivider,
        railSectionLabel: railSectionLabel ?? this.railSectionLabel,
        canvasBase: canvasBase ?? this.canvasBase,
        canvasDot: canvasDot ?? this.canvasDot,
        topBarSurface: topBarSurface ?? this.topBarSurface,
        topBarBorder: topBarBorder ?? this.topBarBorder,
        wordmarkStart: wordmarkStart ?? this.wordmarkStart,
        wordmarkEnd: wordmarkEnd ?? this.wordmarkEnd,
        glowAccent: glowAccent ?? this.glowAccent,
        scrimStrong: scrimStrong ?? this.scrimStrong,
        scrimSoft: scrimSoft ?? this.scrimSoft,
      );

  @override
  MlChrome lerp(covariant MlChrome? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return MlChrome(
      railTop: c(railTop, other.railTop),
      railBottom: c(railBottom, other.railBottom),
      railIndicator: c(railIndicator, other.railIndicator),
      railActiveBar: c(railActiveBar, other.railActiveBar),
      railIcon: c(railIcon, other.railIcon),
      railIconSelected: c(railIconSelected, other.railIconSelected),
      railLabel: c(railLabel, other.railLabel),
      railLabelSelected: c(railLabelSelected, other.railLabelSelected),
      railDivider: c(railDivider, other.railDivider),
      railSectionLabel: c(railSectionLabel, other.railSectionLabel),
      canvasBase: c(canvasBase, other.canvasBase),
      canvasDot: c(canvasDot, other.canvasDot),
      topBarSurface: c(topBarSurface, other.topBarSurface),
      topBarBorder: c(topBarBorder, other.topBarBorder),
      wordmarkStart: c(wordmarkStart, other.wordmarkStart),
      wordmarkEnd: c(wordmarkEnd, other.wordmarkEnd),
      glowAccent: c(glowAccent, other.glowAccent),
      scrimStrong: c(scrimStrong, other.scrimStrong),
      scrimSoft: c(scrimSoft, other.scrimSoft),
    );
  }
}
