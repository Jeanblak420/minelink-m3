import 'package:flutter/widgets.dart';

/// Material 3's **window size classes** — the breakpoints the whole shell
/// switches on.
///
/// The shipping app had three breakpoints, each invented for the screen that
/// needed it and named after what it did rather than what it measured:
/// `sidebarBreakpoint` 900, `dashboardWideMin` 800, `compactTableMax` 600. So a
/// window 850px wide showed a drawer (because 850 < 900) *and* a multi-column
/// dashboard (because 850 >= 800) — a phone-shaped navigation wrapped around a
/// desktop-shaped page. Nothing was wrong with either number on its own; they
/// simply had no relationship to each other.
///
/// M3's classes are a single ladder, and every component that adapts uses the
/// same rungs. That is the property worth having: a layout decision made in one
/// widget cannot contradict one made in another.
///
/// | class | width | what MineLink shows |
/// |---|---|---|
/// | compact | < 600 | bottom navigation bar + modal drawer |
/// | medium | 600–839 | collapsed rail (icons) |
/// | expanded | 840–1199 | full rail with labels — the console look |
/// | large | ≥ 1200 | full rail, wider workspace |
///
/// M3 also defines `extraLarge` at 1600. MineLink folds it into [large]: the
/// only thing it would change is the content cap, and that is already a
/// separate decision made by the workspace rather than by the navigation.
enum MlWindowClass {
  compact,
  medium,
  expanded,
  large;

  /// The class for a window [width] in logical pixels.
  static MlWindowClass forWidth(double width) {
    if (width < 600) return MlWindowClass.compact;
    if (width < 840) return MlWindowClass.medium;
    if (width < 1200) return MlWindowClass.expanded;
    return MlWindowClass.large;
  }

  /// The class for [context]'s window.
  ///
  /// Uses `MediaQuery.sizeOf`, so a widget calling this rebuilds when the
  /// window resizes but **not** when unrelated media data (the text scaler,
  /// padding, the keyboard) changes. On Windows and web that difference is the
  /// whole cost of a resize.
  static MlWindowClass of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  /// Navigation is a bottom bar and a modal drawer rather than a rail.
  bool get usesBottomNav => this == MlWindowClass.compact;

  /// The rail is present but shows icons only.
  bool get usesCollapsedRail => this == MlWindowClass.medium;

  /// The rail is present with labels — what the super-admin console looks
  /// like, and what every role now gets at this width.
  bool get usesExpandedRail =>
      this == MlWindowClass.expanded || this == MlWindowClass.large;

  /// Any rail at all.
  bool get usesRail => usesCollapsedRail || usesExpandedRail;

  /// How wide the workspace lets its content grow before it stops.
  ///
  /// Capped so a dense table does not become a 2,000px line the eye cannot
  /// track back from. `large` gets more room than `expanded` because at that
  /// width the alternative is a page that is mostly margin.
  double get contentMaxWidth => switch (this) {
        MlWindowClass.compact => double.infinity,
        MlWindowClass.medium => double.infinity,
        MlWindowClass.expanded => 1280,
        MlWindowClass.large => 1600,
      };

  /// The padding between the workspace edge and its content.
  double get contentPadding => switch (this) {
        MlWindowClass.compact => 16,
        MlWindowClass.medium => 20,
        MlWindowClass.expanded => 28,
        MlWindowClass.large => 32,
      };

  /// How many columns a responsive tile grid should use at this width.
  ///
  /// Here rather than in each screen because five screens independently
  /// deciding "wide means three columns" is five places to disagree.
  int get gridColumns => switch (this) {
        MlWindowClass.compact => 1,
        MlWindowClass.medium => 2,
        MlWindowClass.expanded => 3,
        MlWindowClass.large => 4,
      };
}
