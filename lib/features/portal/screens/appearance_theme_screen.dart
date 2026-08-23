import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/theme/theme_mode_provider.dart';
import 'package:flutter_application_1/features/portal/providers/mine_appearance_provider.dart';
import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';
import 'package:flutter_application_1/core/design/tokens/ml_mine_premium_theme.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

/// Appearance & theme settings page.
///
/// Lets the operator choose the light/dark mode (app-wide), and — for the
/// mine/supplier dashboard — a premium theme direction (MineLink / Glass /
/// Industrial) and layout density. The dashboard theme selection is scoped to
/// the mine dashboard surface only and never restyles the buyer or transporter
/// portals.
class AppearanceThemeScreen extends ConsumerWidget {
  const AppearanceThemeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final appearance = ref.watch(mineAppearanceProvider);
    // Premium dashboard themes are mine/supplier-only.
    final isMineSupplier =
        ref.watch(portalWorkspaceProvider).isMineSupplier;

    // `MlPageBody` + `MlPageHeader`, like every other portal page.
    //
    // The title was a hand-rolled `titleLarge` in the SANS at w800, so this was
    // the one settings page whose heading was in a different typeface from the
    // thirty-six the header component exists for — and its 24px gutter was flat
    // rather than the responsive one every other page gets on a phone.
    return MlPageBody(
      maxWidth: 860,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // "Appearance" — the rail's word and, since 2026-08-22, the top
          // bar's. Three names for one destination is the fault the route-name
          // pass exists to end, and this page had two of them stacked.
          const MlPageHeader(
            title: 'Appearance',
            description:
                'Personalise how MineLink looks. Light or dark applies '
                'everywhere; the dashboard theme and density apply to your '
                'Mine/Supplier dashboard.',
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Light / Dark / System ----
              _SectionCard(
                title: 'Colour mode',
                subtitle: 'Applies across the whole app.',
                child: Row(
                  children: [
                    for (final mode in const [
                      ThemeMode.light,
                      ThemeMode.dark,
                      ThemeMode.system,
                    ]) ...[
                      if (mode != ThemeMode.light) const SizedBox(width: 10),
                      Expanded(
                        child: _ChoiceChipTile(
                          label: _modeLabel(mode),
                          icon: _modeIcon(mode),
                          selected: themeMode == mode,
                          onTap: () => ref
                              .read(themeModeProvider.notifier)
                              .setMode(mode),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Premium theme directions skin the ENTIRE mine workspace and are
              // only offered to mine/supplier users.
              if (isMineSupplier) ...[
                const SizedBox(height: 16),

                // ---- Dashboard theme direction ----
                _SectionCard(
                  title: 'Mine theme',
                  subtitle:
                      'Applies across your whole Mine/Supplier workspace — '
                      'sidebar, pages and dashboard.',
                  child: Column(
                    children: [
                      for (final direction in MineThemeDirection.values) ...[
                        if (direction != MineThemeDirection.values.first)
                          const SizedBox(height: 10),
                        _ThemeDirectionTile(
                          direction: direction,
                          selected: appearance.direction == direction,
                          onTap: () => ref
                              .read(mineAppearanceProvider.notifier)
                              .setDirection(direction),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ---- Density ----
                _SectionCard(
                  title: 'Density',
                  subtitle: 'Spacing of dashboard cards.',
                  child: Row(
                    children: [
                      for (final density in MineDensity.values) ...[
                        if (density != MineDensity.values.first)
                          const SizedBox(width: 10),
                        Expanded(
                          child: _ChoiceChipTile(
                            label: density.label,
                            icon: density == MineDensity.compact
                                ? Icons.density_small_rounded
                                : Icons.density_medium_rounded,
                            selected: appearance.density == density,
                            onTap: () => ref
                                .read(mineAppearanceProvider.notifier)
                                .setDensity(density),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _modeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }

  IconData _modeIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto_outlined;
    }
  }
}

/// Titled container grouping a set of appearance controls.
class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return MlCard(
      hero: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.mlText.titleMedium.copyWith(
              color: semantic.textStrong,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: context.mlText.bodyMedium.copyWith(color: semantic.textMuted),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

/// A selectable pill tile with icon + label (used for mode and density).
class _ChoiceChipTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ChoiceChipTile({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        onTap: onTap,
        child: AnimatedContainer(
          duration: MlTokens.durFast,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? MlTone.accent.well(Theme.of(context).brightness)
                : semantic.surfaceSunken,
            borderRadius: BorderRadius.circular(MlTokens.rMd),
            border: Border.all(
              color: selected ? MlTokens.accent : semantic.borderCard,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? MlTokens.accent : semantic.textMuted,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: context.mlText.titleSmall.copyWith(
                  color: selected ? semantic.textStrong : semantic.textBody,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row tile for a dashboard theme direction, with a live preview swatch.
class _ThemeDirectionTile extends StatelessWidget {
  final MineThemeDirection direction;
  final bool selected;
  final VoidCallback onTap;
  const _ThemeDirectionTile({
    required this.direction,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        onTap: onTap,
        child: AnimatedContainer(
          duration: MlTokens.durFast,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? MlTone.accent.well(Theme.of(context).brightness)
                : semantic.surfaceSunken,
            borderRadius: BorderRadius.circular(MlTokens.rMd),
            border: Border.all(
              color: selected ? MlTokens.accent : semantic.borderCard,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _ThemePreviewSwatch(direction: direction),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      direction.label,
                      style: context.mlText.titleMedium.copyWith(
                        color: semantic.textStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _describe(direction),
                      style: context.mlText.bodyMedium.copyWith(
                        color: semantic.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected ? MlTokens.accent : semantic.textFaint,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _describe(MineThemeDirection direction) {
    switch (direction) {
      case MineThemeDirection.minelink:
        return 'The current MineLink look — cyan accents on your existing theme.';
      case MineThemeDirection.glass:
        return 'Frosted translucent panels, iced sky-cyan & violet, aurora background.';
      case MineThemeDirection.industrial:
        return 'Graphite panels, safety-orange accents, sharp hairline borders.';
    }
  }
}

/// A small preview of a theme direction's background + accent colours.
class _ThemePreviewSwatch extends StatelessWidget {
  final MineThemeDirection direction;
  const _ThemePreviewSwatch({required this.direction});

  @override
  Widget build(BuildContext context) {
    final palette = MinePremiumPalette.forDirection(direction);

    // MineLink (current) preview uses the app's own tokens.
    final bg = palette?.bg ?? MlTokens.navy800;
    final accent = palette?.accent ?? MlTokens.accent;
    final accent2 = palette?.accent2 ?? MlTokens.cyan200;
    final radius = palette == null ? 12.0 : palette.cardRadius;

    return Container(
      width: 64,
      height: 52,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: MlShape.radiusMedium,
        border: Border.all(color: palette?.border ?? MlTokens.navy700),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 26,
            height: 8,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(radius / 2),
            ),
          ),
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: accent2,
                  borderRadius: BorderRadius.circular(radius / 2),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: (palette?.accentWarm ?? MlTokens.amber700)
                      .withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(radius / 2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
