import 'package:flutter/material.dart';
// `show`-scoped: Flutter 3.44 moved CupertinoPageTransitionsBuilder out of
// material.dart into cupertino/route.dart, and importing all of cupertino
// unscoped brings in names that collide with material's.
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;

import 'package:flutter_application_1/core/design/tokens/m3/ml_chrome.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_motion.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_scheme.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Application-wide [ThemeData], built on Material 3.
///
/// ## What changed from the shipping app, and why it matters
///
/// The previous theme seeded a `ColorScheme` from `MlTokens.teal700` — a
/// colour that appears nowhere in the interface — and then hand-restyled the
/// dozen or so components anyone had noticed looked wrong. Every Material
/// widget nobody had got to yet still came out teal: switches, sliders, text
/// selection handles, the cursor, progress indicators, date pickers, the
/// refresh spinner. The theme was a list of exceptions rather than a system.
///
/// This one starts from [MlScheme], which *is* the brand, and then themes the
/// full component set from it. The practical test: an unstyled Material widget
/// dropped anywhere in the app should now look like it belongs. That is the
/// difference between a design system and a pile of overrides.
///
/// Everything here reads from four token files and nothing else —
/// [MlScheme] (colour), [MlShape] (corners), [MlMotion] (timing),
/// [MlTypeScale] (type) — plus [MlChrome] for the navy chrome, installed as a
/// `ThemeExtension` so it travels with the theme.
class AppTheme {
  const AppTheme._();

  static ThemeData get lightTheme => build(Brightness.light);
  static ThemeData get darkTheme => build(Brightness.dark);

  /// Builds the theme for [brightness].
  ///
  /// [accent] overrides the brand primary — the per-admin accent in
  /// Settings → User Preferences. [highContrast] strengthens ink and borders.
  /// Both flow through [MlScheme], so they reach every component rather than
  /// only the handful the console used to patch by hand.
  static ThemeData build(
    Brightness brightness, {
    Color? accent,
    bool highContrast = false,
  }) {
    var scheme = MlScheme.of(brightness);
    if (accent != null) scheme = MlScheme.withAccent(scheme, accent);
    if (highContrast) scheme = MlScheme.highContrast(scheme);

    final semantic = MlSemantic.fromScheme(scheme);
    final chrome = MlChrome.from(brightness);
    final text = MlTypeScale.textTheme(scheme.onSurface);
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // The default family only. Per-slot families are assigned in
      // [MlTypeScale] and must not be flattened by an `.apply(fontFamily:)`
      // over the finished theme — doing that is what silently turned twelve
      // Fraunces figures into the UI sans in the shipping app.
      fontFamily: MlTokens.fontSans,
      textTheme: text,
      primaryTextTheme: text,

      scaffoldBackgroundColor: semantic.surfaceApp,
      canvasColor: semantic.surfaceCard,
      dividerColor: scheme.outlineVariant,

      // The brand chrome, carried on the theme so any widget can reach it.
      extensions: <ThemeExtension<dynamic>>[chrome],

      // M3 route transitions. Flutter still defaults several platforms to the
      // Material 2 zoom/fade; naming them keeps web, Windows and Android
      // consistent with each other, which matters when the same build is
      // judged on all three.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),

      // ------------------------------------------------------------ surfaces

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: chrome.topBarSurface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        toolbarHeight: MlTokens.appBarHeight,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: semantic.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: MlShape.radiusLarge,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: semantic.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        // M3 puts dialogs and sheets on the same step — 28. The shipping app
        // had them at 16 and 24 respectively for no stated reason.
        shape: MlShape.dialog,
        barrierColor: chrome.scrimStrong,
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: semantic.surfaceCard,
        modalBackgroundColor: semantic.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: MlShape.radiusTopExtraLarge,
        ),
        clipBehavior: Clip.antiAlias,
        dragHandleColor: scheme.outline,
        showDragHandle: true,
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: chrome.railBottom,
        surfaceTintColor: Colors.transparent,
        scrimColor: chrome.scrimStrong,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(MlShape.extraLarge),
            bottomRight: Radius.circular(MlShape.extraLarge),
          ),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),

      // A scrollbar you can see on a navy card.
      //
      // Material's default thumb is `onSurface` at 8% — drawn over this app's
      // console surfaces that is very nearly nothing, which matters because a
      // scrollbar is not decoration: on the wide tables it is the ONLY thing
      // saying there are columns past the right edge (see `MlWideTable`).
      //
      // `onSurfaceVariant` — the muted-ink role — rather than the accent: a
      // scrollbar is chrome, and a cyan bar under every table would read as a
      // control. Thicker on hover, because the thumb is also a drag target and
      // 6px is not one.
      //
      // The alpha is MEASURED, not chosen. `outline` at 0.55 composited to
      // (59,72,99) on the console card — **2.01:1**, under WCAG's 3:1 for a
      // non-text control, which for the one thing telling a reader a table has
      // more columns is not good enough. 0.6 then measured 2.88:1 in the LIGHT
      // theme, which is the sort of near-miss only a number catches. 0.7 clears
      // both; `wide_table_scrollbar_test.dart` computes it from these colours.
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return scheme.primary;
          }
          if (states.contains(WidgetState.hovered)) {
            return scheme.onSurfaceVariant.withValues(alpha: 0.85);
          }
          return scheme.onSurfaceVariant.withValues(alpha: 0.7);
        }),
        thickness: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.hovered) ? 10 : 6,
        ),
        radius: const Radius.circular(MlShape.small),
        crossAxisMargin: 2,
        mainAxisMargin: 4,
        interactive: true,
      ),

      // ------------------------------------------------------------- buttons
      //
      // All four families share a height and a shape so a row of mixed buttons
      // sits on one baseline. 48 is the minimum comfortable touch target and
      // this app is used on a phone in a mine.

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(80, 48),
          shape: MlShape.control,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          // A DISABLED label that can still be read.
          //
          // Material's defaults are `onSurface` at 38% on a container of the
          // same colour at 12%, which composites to #767E8C on #2C3649:
          // **2.97:1**. That is Material's number, not this app's, and it is
          // how "Continue" on the due-diligence gate and "Create and invite"
          // in the new-group dialog came out — the two buttons that say what
          // the form is FOR while you are still filling it in.
          //
          // WCAG exempts an inactive control from the 4.5 bar, and this
          // product has taken the same line everywhere else it came up (the
          // sign-in veil, the pager, the driver hero): exempt is not a
          // licence to be unreadable. `onSurfaceVariant` is 5.72:1 on that
          // container and still reads as clearly off — the FILL is what says
          // disabled, and the fill is unchanged.
          disabledForegroundColor: scheme.onSurfaceVariant,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(80, 48),
          shape: MlShape.control,
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: MlShape.control,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(80, 48),
          shape: MlShape.control,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          backgroundColor: semantic.surfaceCard,
          foregroundColor: scheme.primary,
          elevation: 1,
          shadowColor: scheme.shadow,
          surfaceTintColor: Colors.transparent,
        ),
      ),

      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape: MlShape.pillShape,
          foregroundColor: scheme.onSurfaceVariant,
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primaryContainer,
        foregroundColor: scheme.onPrimaryContainer,
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        // M3 gives the FAB the large shape, not a circle.
        shape: MlShape.dialog,
        extendedTextStyle: text.labelLarge,
      ),

      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          selectedBackgroundColor: scheme.secondaryContainer,
          selectedForegroundColor: scheme.onSecondaryContainer,
          foregroundColor: scheme.onSurfaceVariant,
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
          minimumSize: const Size(48, 44),
        ),
      ),

      toggleButtonsTheme: ToggleButtonsThemeData(
        borderRadius: MlShape.radiusMedium,
        borderColor: scheme.outline,
        selectedBorderColor: scheme.primary,
        selectedColor: scheme.onPrimaryContainer,
        fillColor: scheme.primaryContainer,
        color: scheme.onSurfaceVariant,
        constraints: const BoxConstraints(minHeight: 44, minWidth: 48),
      ),

      // --------------------------------------------------------------- input

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: semantic.surfaceSunken,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: _inputBorder(Colors.transparent),
        enabledBorder: _inputBorder(scheme.outlineVariant),
        focusedBorder: _inputBorder(scheme.primary, width: 2),
        errorBorder: _inputBorder(scheme.error),
        focusedErrorBorder: _inputBorder(scheme.error, width: 2),
        disabledBorder: _inputBorder(scheme.outlineVariant),
        hintStyle: text.bodyMedium?.copyWith(color: semantic.textFaint),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        floatingLabelStyle:
            text.labelMedium?.copyWith(color: scheme.primary),
        helperStyle: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: scheme.onSurfaceVariant,
        suffixIconColor: scheme.onSurfaceVariant,
      ),

      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(semantic.surfaceCard),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(MlShape.shapeMedium),
          elevation: const WidgetStatePropertyAll(2),
        ),
      ),

      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(semantic.surfaceCard),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(MlShape.shapeMedium),
          elevation: const WidgetStatePropertyAll(2),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: semantic.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 2,
        shape: MlShape.shapeMedium,
        textStyle: text.bodyMedium,
      ),

      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(semantic.surfaceSunken),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        overlayColor:
            WidgetStatePropertyAll(scheme.primary.withValues(alpha: 0.08)),
        elevation: const WidgetStatePropertyAll(0),
        shape: const WidgetStatePropertyAll(MlShape.pillShape),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        textStyle: WidgetStatePropertyAll(text.bodyMedium),
        hintStyle: WidgetStatePropertyAll(
          text.bodyMedium?.copyWith(color: semantic.textFaint),
        ),
        constraints: const BoxConstraints(minHeight: 48),
      ),

      searchViewTheme: SearchViewThemeData(
        backgroundColor: semantic.surfaceCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: MlShape.dialog,
        dividerColor: scheme.outlineVariant,
        headerHintStyle:
            text.bodyLarge?.copyWith(color: semantic.textFaint),
        headerTextStyle: text.bodyLarge,
      ),

      // ---------------------------------------------------------- navigation
      //
      // The rail and drawer are painted by MlAppShell against MlChrome's navy,
      // so these themes exist for the ones that sit on the workspace instead —
      // and so a bare NavigationBar in a test still looks right.

      navigationBarTheme: NavigationBarThemeData(
        // NO FIXED HEIGHT.
        //
        // It was 72 — a number that fits exactly one 16px line of label and
        // then stops. A `NavigationBar` does not ellipsize, so a label too long
        // for its slot wraps, and a wrapped label in a fixed-height bar is
        // clipped rather than overflowed: nothing raises, no sweep fails, and
        // the words are simply not there. Measured at 360px: the mine guard's
        // "Incidents & gate checks" took three lines and ran 6px past the
        // bottom of the bar, and the supervisor's "Supervisor & stockpiles"
        // did the same.
        //
        // Worse, 72 ignored the text scale entirely, while this console lets
        // every user set one (`ConsolePrefs.textScale`, 0.85–1.3). A fixed
        // chrome height under a user-controlled type size can only be right at
        // one setting.
        //
        // `MlAppShell` computes the height from the label style and the live
        // text scaler instead — see `_bottomBarHeight`. Left unset here so
        // there is one answer, not a theme value and a widget value that can
        // disagree. Pinned by `test/widgets/bottom_nav_labels_test.dart`.
        backgroundColor: chrome.topBarSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: scheme.secondaryContainer,
        indicatorShape: MlShape.pillShape,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? text.labelMedium?.copyWith(color: scheme.onSurface)
              : text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: chrome.railBottom,
        elevation: 0,
        indicatorColor: chrome.railIndicator,
        indicatorShape: MlShape.pillShape,
        useIndicator: true,
        selectedIconTheme:
            IconThemeData(color: chrome.railIconSelected, size: 24),
        unselectedIconTheme: IconThemeData(color: chrome.railIcon, size: 24),
        selectedLabelTextStyle:
            text.labelMedium?.copyWith(color: chrome.railLabelSelected),
        unselectedLabelTextStyle:
            text.labelMedium?.copyWith(color: chrome.railLabel),
      ),

      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: chrome.railBottom,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: chrome.railIndicator,
        indicatorShape: MlShape.pillShape,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? text.labelLarge?.copyWith(color: chrome.railLabelSelected)
              : text.labelLarge?.copyWith(color: chrome.railLabel),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? chrome.railIconSelected
                : chrome.railIcon,
          ),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: scheme.onSurfaceVariant,
        labelStyle: text.titleSmall,
        unselectedLabelStyle: text.titleSmall,
        indicatorColor: scheme.primary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: scheme.outlineVariant,
        overlayColor:
            WidgetStatePropertyAll(scheme.primary.withValues(alpha: 0.08)),
      ),

      // -------------------------------------------------------- small things

      chipTheme: ChipThemeData(
        backgroundColor: semantic.surfaceSunken,
        selectedColor: scheme.secondaryContainer,
        disabledColor: semantic.surfaceSunken,
        surfaceTintColor: Colors.transparent,
        checkmarkColor: scheme.onSecondaryContainer,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge,
        // M3 chips are stadium-shaped. The shipping app used an 8dp rectangle,
        // which is what made its chips read as tiny buttons.
        shape: MlShape.pillShape,
        side: BorderSide(color: scheme.outlineVariant),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        elevation: 0,
        pressElevation: 0,
      ),

      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        textStyle: text.labelSmall,
        smallSize: 8,
        largeSize: 18,
        padding: const EdgeInsets.symmetric(horizontal: 5),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: MlShape.radiusExtraSmall,
        ),
        textStyle: text.bodySmall?.copyWith(color: scheme.onInverseSurface),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        waitDuration: MlMotion.enter,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: MlShape.shapeExtraSmall,
        elevation: 2,
        insetPadding: const EdgeInsets.all(16),
      ),

      listTileTheme: ListTileThemeData(
        shape: MlShape.control,
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle:
            text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        selectedColor: scheme.onSecondaryContainer,
        selectedTileColor: scheme.secondaryContainer,
      ),

      expansionTileTheme: ExpansionTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: MlShape.radiusMedium,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: MlShape.radiusMedium,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        iconColor: scheme.primary,
        collapsedIconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        collapsedTextColor: scheme.onSurface,
      ),

      dataTableTheme: DataTableThemeData(
        headingTextStyle:
            text.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        dataTextStyle: text.bodyMedium,
        headingRowColor: WidgetStatePropertyAll(semantic.surfaceSunken),
        dividerThickness: 1,
        columnSpacing: 24,
        horizontalMargin: 16,
      ),

      // ------------------------------------------------------------ controls

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.outline,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : semantic.surfaceSunken,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.transparent
              : scheme.outline,
        ),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(scheme.onPrimary),
        side: BorderSide(color: scheme.outline, width: 2),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(MlShape.extraSmall)),
        ),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : scheme.outline,
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: semantic.surfaceSunken,
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        valueIndicatorColor: scheme.inverseSurface,
        valueIndicatorTextStyle:
            text.labelMedium?.copyWith(color: scheme.onInverseSurface),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: semantic.surfaceSunken,
        circularTrackColor: semantic.surfaceSunken,
      ),

      // Text selection. Left on the seeded scheme in the shipping app, which is
      // why the cursor and the selection handles were teal on a cyan interface —
      // the single most visible symptom of the two-palette problem.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: isDark ? 0.32 : 0.22),
        selectionHandleColor: scheme.primary,
      ),

      splashFactory: InkSparkle.splashFactory,
      focusColor: scheme.primary.withValues(alpha: 0.12),
      hoverColor: scheme.primary.withValues(alpha: 0.06),
      highlightColor: scheme.primary.withValues(alpha: 0.10),
      splashColor: scheme.primary.withValues(alpha: 0.10),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) =>
      OutlineInputBorder(
        borderRadius: MlShape.radiusMedium,
        borderSide: BorderSide(color: color, width: width),
      );
}
