import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/ml_rail_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ui_prefs.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/console_palette_tokens.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_core.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_haul.dart';
import 'package:flutter_application_1/features/super_admin/widgets/sidebar/minelink_sidebar_weighbridge.dart';
import 'package:flutter_application_1/features/super_admin/widgets/super_admin_dashboard_widgets.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';

/// Settings → User Preferences — per-user appearance & accessibility for the
/// Super-Admin console (the design's Appearance panel relocated from the
/// floating palette button / top-bar theme toggle into Settings).
///
///  - Appearance/Display: light/dark mode, accent colour, canvas texture.
///  - Console sidebar: Classic / Haul / Weighbridge.
///  - Accessibility: text size, high contrast, bold text.
///
/// Everything here is saved to the signed-in admin's account only and never
/// affects other users.
class UserPreferencesScreen extends ConsumerWidget {
  const UserPreferencesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(uiPrefsProvider);
    final notifier = ref.read(uiPrefsProvider.notifier);
    final s = MlSemantic.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SaSectionHeader(
                  title: 'Appearance / Display',
                  subtitle:
                      'Theme mode, accent colour and workspace display — how the console looks for you.',
                ),
                const SizedBox(height: 14),
                _PrefsCard(
                  children: [
                    const _GroupLabel('Mode'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeButton(
                            label: 'Light',
                            icon: Icons.light_mode_outlined,
                            selected: !prefs.darkMode,
                            accent: prefs.accent.color,
                            onTap: () => notifier.setDarkMode(false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ModeButton(
                            label: 'Dark',
                            icon: Icons.dark_mode_outlined,
                            selected: prefs.darkMode,
                            accent: prefs.accent.color,
                            onTap: () => notifier.setDarkMode(true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const _GroupLabel('Accent'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final a in ConsoleAccent.values)
                          _AccentSwatch(
                            accent: a,
                            selected: a == prefs.accent,
                            onTap: () => notifier.setAccent(a),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      prefs.accent.label,
                      style: TextStyle(fontSize: 12, color: s.textMuted),
                    ),
                    const SizedBox(height: 18),
                    _SwitchRow(
                      title: 'Canvas texture',
                      description:
                          'Engineering dot-grid and soft brand washes behind the light workspace.',
                      value: prefs.canvasTexture,
                      onChanged: notifier.setCanvasTexture,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const SaSectionHeader(
                  title: 'Console sidebar',
                  subtitle:
                      'Five navigation rails — three layouts, two of them also in the app palette. Same destinations and same counts throughout.',
                ),
                const SizedBox(height: 14),
                _PrefsCard(
                  children: [
                    LayoutBuilder(
                      builder: (context, c) {
                        // Three across when there's room, otherwise stack.
                        final columns = c.maxWidth >= 660 ? 3 : 1;
                        const gap = 12.0;
                        final cardWidth =
                            (c.maxWidth - gap * (columns - 1)) / columns;
                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final skin in ConsoleSidebarSkin.values)
                              SizedBox(
                                width: cardWidth,
                                child: _SidebarSkinCard(
                                  skin: skin,
                                  dark: prefs.darkMode,
                                  accent: prefs.accent,
                                  selected: skin == prefs.sidebar,
                                  onTap: () => notifier.setSidebar(skin),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 15, color: s.textMuted),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Haul and Weighbridge ship in their delivered gold palette; the '
                            '· MineLink pair is the identical layout recoloured to the app '
                            'tokens, and those two follow your accent above. All five follow '
                            'your light/dark choice, carry the same live counts and remember '
                            'collapsed state.',
                            style: TextStyle(fontSize: 12, color: s.textMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const SaSectionHeader(
                  title: 'Accessibility',
                  subtitle:
                      'Text size, high contrast and font adjustments — applied across the console.',
                ),
                const SizedBox(height: 14),
                _PrefsCard(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: _GroupLabel('Text size')),
                        Text(
                          '${(prefs.textScale * 100).round()}%',
                          style: TextStyle(
                            fontFamily: MlTokens.fontMono,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: s.textStrong,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: prefs.textScale,
                      min: 0.85,
                      max: 1.3,
                      divisions: 9,
                      label: '${(prefs.textScale * 100).round()}%',
                      onChanged: notifier.setTextScale,
                    ),
                    const SizedBox(height: 8),
                    _SwitchRow(
                      title: 'High contrast',
                      description:
                          'Strengthens text and border contrast throughout the console.',
                      value: prefs.highContrast,
                      onChanged: notifier.setHighContrast,
                    ),
                    const SizedBox(height: 4),
                    _SwitchRow(
                      title: 'Bold text',
                      description: 'Renders console text with heavier weights.',
                      value: prefs.boldText,
                      onChanged: notifier.setBoldText,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 15, color: s.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Saved to your account only',
                      style: TextStyle(fontSize: 12, color: s.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White design card (surface-card fill, card border, lg radius).
class _PrefsCard extends StatelessWidget {
  final List<Widget> children;
  const _PrefsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: s.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rLg),
        border: Border.all(color: s.borderCard),
        boxShadow: MlTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

/// Uppercase micro group label (design's "MODE" / "ACCENT" captions).
class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: MlTokens.fontSans,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.66,
        color: s.textFaint,
      ),
    );
  }
}

/// Light/Dark segmented button — selected state fills with the accent.
class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Material(
      color: selected ? accent : s.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: selected ? accent : s.borderStrong),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18, color: selected ? MlTokens.inkOnFill : s.textBody),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? MlTokens.inkOnFill : s.textBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Accent colour swatch (32px rounded square, ring when selected).
class _AccentSwatch extends StatelessWidget {
  final ConsoleAccent accent;
  final bool selected;
  final VoidCallback onTap;
  const _AccentSwatch({
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Tooltip(
      message: accent.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: accent.color,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              width: 2.5,
              color: selected ? s.textStrong : Colors.transparent,
            ),
          ),
          child: selected
              ? const Icon(Icons.check_rounded, size: 16, color: MlTokens.inkOnFill)
              : null,
        ),
      ),
    );
  }
}

/// Selectable card for one sidebar version: a miniature of the real rail drawn
/// from that skin's own palette, its name, and what it's for.
class _SidebarSkinCard extends StatelessWidget {
  final ConsoleSidebarSkin skin;
  final bool dark;
  final ConsoleAccent accent;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarSkinCard({
    required this.skin,
    required this.dark,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    final ring = accent.color;
    return Semantics(
      selected: selected,
      button: true,
      label: '${skin.label} sidebar',
      child: Material(
        color: selected ? ring.withValues(alpha: 0.07) : s.surfaceCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? ring : s.borderStrong,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SidebarSkinPreview(skin: skin, dark: dark, accent: accent),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        skin.label,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: s.textStrong,
                        ),
                      ),
                    ),
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? ring : Colors.transparent,
                        border: Border.all(
                          color: selected ? ring : s.borderStrong,
                          width: 1.5,
                        ),
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              size: 13, color: MlTokens.inkOnFill)
                          : null,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  skin.description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: s.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Miniature of a rail, built from the skin's real palette so the swatch can't
/// drift from what actually renders. Labels are bars, not type — at this size
/// the shape of the rail is the information, and the differences that matter
/// (rounded capsule vs ink block vs tally column) survive the shrink.
class _SidebarSkinPreview extends StatelessWidget {
  final ConsoleSidebarSkin skin;
  final bool dark;
  final ConsoleAccent accent;

  const _SidebarSkinPreview({
    required this.skin,
    required this.dark,
    required this.accent,
  });

  static const _height = 104.0;

  /// Classic's palette, taken from the rail itself.
  ///
  /// Until S5-19 this was 32 hand-copied literals under a comment reading
  /// *"kept in sync by eye — it's a thumbnail, not chrome"*. A swatch whose
  /// only job is to show the user what the rail looks like is the worst place
  /// for a by-eye copy: when it drifts it does not look broken, it looks like
  /// a fourth option. `MlRailTokens.asSidebarTokens()` composites the rail's
  /// own translucent inks over its own surface, so this resolves to the same
  /// pixels the real rail paints.
  MlSidebarTokens get _classicTokens =>
      (dark ? MlRailTokens.navy : MlRailTokens.light).asSidebarTokens();

  /// The very palette the real rail will use — the app-palette variants come
  /// straight from `MlPaletteSidebarTokens`, so the swatch can't disagree with
  /// what renders.
  /// The app-nav rail draws from the Glass palette it shares with the insights
  /// screens, so the thumbnail is built from those same values.
  MlSidebarTokens get _appTokens {
    final g = dark ? MlGlass.dark : MlGlass.light;
    return MlSidebarTokens(
      isDarkSurface: g.isDark,
      surface: g.bg1,
      surfaceRaised: g.panel,
      surfaceHover: g.panel2,
      surfaceActive: g.accent.withValues(alpha: 0.16),
      border: g.line2,
      textPrimary: g.inkHi,
      textSecondary: g.ink,
      textMuted: g.inkMid,
      accent: g.accent,
      accentSoft: g.accent.withValues(alpha: 0.14),
      onAccent: g.bg0,
      badgeBg: g.accent,
      badgeFg: g.bg0,
      danger: g.bad,
      dangerBg: g.bad.withValues(alpha: 0.14),
      online: g.good,
      radius: 10,
    );
  }

  MlSidebarTokens get _tokens {
    final custom = MlPaletteSidebarTokens.forSkin(
      skin,
      dark: dark,
      accent: accent,
    );
    if (custom != null) return custom;
    if (skin.isApp) return _appTokens;
    if (skin.isHaul) return dark ? HaulTokens.dark : HaulTokens.light;
    if (skin.isWeighbridge) {
      return dark ? WeighbridgeTokens.dark : WeighbridgeTokens.light;
    }
    return _classicTokens;
  }

  static Widget _bar(Color color, double width, [double height = 4]) =>
      Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  /// Brand strip at the top of every rail: the mark, and for the drops the
  /// rule–word–rule strapline device.
  Widget _brand(MlSidebarTokens t) {
    final ruled = skin != ConsoleSidebarSkin.classic;
    return Column(
      children: [
        _bar(t.textSecondary, 30, 9),
        const SizedBox(height: 5),
        if (ruled)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _bar(t.accent, 14, 2),
              const SizedBox(width: 4),
              _bar(t.textMuted, 20, 3),
              const SizedBox(width: 4),
              _bar(t.accent, 14, 2),
            ],
          )
        else
          _bar(t.textMuted, 40, 3),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = _tokens;
    final wb = skin.isWeighbridge;
    // Haul detaches into a capsule; Weighbridge is flush with a 5px corner.
    final outerRadius = skin.isHaul
        ? 16.0
        : wb
            ? 5.0
            : skin.isApp
                ? 12.0
                : 10.0;

    return Container(
      height: _height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(outerRadius),
        border: Border.all(color: t.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, 9, 8, wb ? 8 : 7),
            child: _brand(t),
          ),
          if (wb) Container(height: 1, color: t.border),
          Expanded(
            child: Padding(
              // Weighbridge rows are full-bleed and hairline-ruled; the other
              // two float inset tiles.
              padding: EdgeInsets.symmetric(horizontal: wb ? 0 : 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _row(t, label: 32),
                  _row(t, label: 40, active: true),
                  _row(t, label: 26, count: true),
                  _row(t, label: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    MlSidebarTokens t, {
    required double label,
    bool active = false,
    bool count = false,
  }) {
    final wb = skin.isWeighbridge;
    // The app rail fills its active tile the same way Haul does.
    final haul = skin.isHaul || skin.isApp;

    // Weighbridge stamps a solid ink block and inverts the type on it; the
    // others tint the tile.
    final onInk = wb && active;
    final inkFg = t.onInk ??
        (t.isDarkSurface
            // Same derivation as `_onInk` in the Weighbridge skin: on a dark
            // skin the stamped block is paper, so its type is the panel; on a
            // light skin the block is ink, so its type is the paper (S5-19).
            ? t.surface
            : t.surfaceRaised);
    final fg = onInk
        ? inkFg
        : active
            ? t.textPrimary
            : t.textSecondary;

    Widget glyph;
    if (haul && active) {
      // Haul fills the icon chip with gold on the active row.
      glyph = Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: t.accent,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    } else {
      glyph = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: onInk ? inkFg : (active ? t.accent : t.textMuted),
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    final child = Row(
      children: [
        SizedBox(width: wb ? 8 : 6),
        glyph,
        const SizedBox(width: 6),
        _bar(fg, label, 4),
        const Spacer(),
        if (count)
          wb
              // Weighbridge's signature: the count is a mono figure in its own
              // right-hand tally column, not a pill.
              ? _bar(t.accent, 7, 5)
              : Container(
                  width: 13,
                  height: 7,
                  decoration: BoxDecoration(
                    color: t.badgeBg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
        SizedBox(width: wb ? 8 : 6),
      ],
    );

    if (wb) {
      return Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: active ? t.surfaceActive : Colors.transparent,
            border: Border(bottom: BorderSide(color: t.border)),
          ),
          child: child,
        ),
      );
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Container(
          decoration: BoxDecoration(
            color: active ? t.surfaceActive : Colors.transparent,
            borderRadius: BorderRadius.circular(haul ? 7 : 6),
            border: active
                ? Border.all(color: t.accent.withValues(alpha: 0.35))
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Titled switch row with a muted one-line description (design's
/// notification-prefs row pattern).
class _SwitchRow extends StatelessWidget {
  final String title;
  final String description;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: s.textStrong,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(fontSize: 12.5, color: s.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
