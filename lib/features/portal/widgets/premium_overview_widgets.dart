import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

final _decimal = NumberFormat.decimalPattern();

String formatTons(double value, {String suffix = ' t'}) {
  final whole = value.truncateToDouble() == value;
  final text = whole ? _decimal.format(value.round()) : _decimal.format(value);
  return '$text$suffix';
}

/// Gradient/elevated panel used for every overview tile. Keeps the cyan-on-navy
/// portal identity but adds depth, an accent header rule, and optional badge.
class OverviewHeroTile extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget? badge;
  final Widget child;
  final VoidCallback? onTap;
  final bool muted;

  const OverviewHeroTile({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.badge,
    this.onTap,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(20);
    final fill = MlSemantic.of(context).surfaceCard;
    final deep = Color.alphaBlend(
      PortalColors.accent.withValues(alpha: muted ? 0.05 : 0.16),
      scheme.surface,
    );

    final content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MlSemantic.of(context).surfaceSunken,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: MlSemantic.of(context).borderCard),
                  ),
                  child: Icon(icon, color: PortalColors.accent, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (badge != null) ...[const SizedBox(width: 8), badge!],
              if (onTap != null) ...[
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: scheme.onSurfaceVariant),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Container(
            height: 3,
            width: 44,
            decoration: BoxDecoration(
              color: PortalColors.accent.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );

    final panel = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [fill, deep],
        ),
        borderRadius: radius,
        border: Border.all(color: MlSemantic.of(context).borderCard),
        boxShadow: [
          BoxShadow(
            color: PortalColors.accent.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: onTap == null
          ? content
          : Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: content,
              ),
            ),
    );

    return ClipRRect(borderRadius: radius, child: panel);
  }
}

/// Small pill that flags placeholder / not-yet-wired data.
class OverviewPlaceholderBadge extends StatelessWidget {
  final String label;
  const OverviewPlaceholderBadge({super.key, this.label = 'preview'});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MlSemantic.of(context).borderCard),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
          ),
        ],
      ),
    );
  }
}

/// Animated count-up number used for headline tonnage values.
///
/// Renders a **display numeral** by default — `MlType.figure`, which is
/// Fraunces with tabular figures (`docs/design-reference.md` §3, S5-6/S5-7).
///
/// It used to have no opinion: [style] was the only source of typography and
/// all six call sites passed it `textTheme.headlineSmall` or `headlineMedium`.
/// `AppTheme._mlTextTheme` ends with `.apply(fontFamily: MlTokens.fontSans)`,
/// which covers the whole text theme, so every tonnage in the portal was drawn
/// in the UI sans — and none had tabular digits, which is why an animating
/// figure re-measured on each frame and jittered while it counted up.
///
/// [style] still wins when passed, so a caller that genuinely wants something
/// else (a small mono inline figure) is not blocked. The difference is that
/// the default is now correct rather than absent.
class AnimatedTons extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final String suffix;

  const AnimatedTons({
    super.key,
    required this.value,
    this.style,
    this.suffix = ' t',
  });

  @override
  Widget build(BuildContext context) {
    final effective =
        style ?? MlType.figure(color: MlSemantic.of(context).textStrong);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(
        formatTons(v, suffix: suffix),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: effective,
      ),
    );
  }
}

/// Label + value row used for breakdowns (D/W/M/Y and stockpile bins).
class MetricBreakdownRow extends StatelessWidget {
  final String label;
  final double value;
  final bool emphasize;

  const MetricBreakdownRow({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: emphasize ? scheme.onSurface : scheme.onSurfaceVariant,
              fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            formatTons(value),
            style: (emphasize ? textTheme.titleMedium : textTheme.bodyLarge)
                ?.copyWith(
              fontWeight: FontWeight.w800,
              color: emphasize ? PortalColors.accent : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

/// One buyer's overview card: tonnage + recon / invoice actions.
class BuyerOverviewCard extends StatelessWidget {
  final String name;
  final double tons;
  final VoidCallback? onRecons;
  final VoidCallback? onInvoice;

  /// Optional third action opening the full per-buyer panel.
  final VoidCallback? onDetails;

  const BuyerOverviewCard({
    super.key,
    required this.name,
    required this.tons,
    this.onRecons,
    this.onInvoice,
    this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return OverviewHeroTile(
      title: name,
      icon: Icons.handshake_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tons out',
              style: textTheme.bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          AnimatedTons(
            value: tons,
            style: MlType.figure(
                color: scheme.onSurface, size: MlTokens.fsH1),
          ),
          const SizedBox(height: 16),
          _BuyerAction(
            icon: Icons.download_rounded,
            label: 'Download / view recons',
            onTap: onRecons,
          ),
          const SizedBox(height: 8),
          _BuyerAction(
            icon: Icons.receipt_long_outlined,
            label: 'Generate invoice',
            onTap: onInvoice,
          ),
          if (onDetails != null) ...[
            const SizedBox(height: 8),
            _BuyerAction(
              icon: Icons.open_in_full_rounded,
              label: 'View details',
              onTap: onDetails,
            ),
          ],
        ],
      ),
    );
  }
}

class _BuyerAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _BuyerAction({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          alignment: Alignment.centerLeft,
          backgroundColor: MlSemantic.of(context).surfaceCard,
          foregroundColor: MlTokens.accent,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          side: BorderSide(color: MlSemantic.of(context).borderCard),
        ),
        icon: Icon(icon, size: 18),
        label: Align(
          alignment: Alignment.centerLeft,
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
  }
}

/// Loading-activity rows (incoming + scheduled today).
class LoadingActivityCard extends StatelessWidget {
  final int incoming;
  final int scheduledToday;

  const LoadingActivityCard({
    super.key,
    required this.incoming,
    required this.scheduledToday,
  });

  @override
  Widget build(BuildContext context) {
    return OverviewHeroTile(
      title: 'Loading activity',
      icon: Icons.local_shipping_outlined,
      child: Column(
        children: [
          _ActivityRow(
            icon: Icons.login_rounded,
            label: 'Incoming trucks',
            value: '$incoming',
          ),
          const SizedBox(height: 10),
          _ActivityRow(
            icon: Icons.event_available_outlined,
            label: 'Scheduled trucks for the day',
            value: '$scheduledToday',
          ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ActivityRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: PortalColors.accent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ),
        Text(
          value,
          style: textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: scheme.onSurface),
        ),
      ],
    );
  }
}

/// Prominent accent CTA for requesting more buyers.
class RequestBuyersCard extends StatelessWidget {
  final VoidCallback? onTap;
  const RequestBuyersCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MlTokens.accent, MlTokens.navy800],
          ),
          borderRadius: radius,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group_add_outlined,
                      color: MlTokens.inkOnFill, size: 28),
                  const SizedBox(height: 14),
                  const Text(
                    'Request buyers',
                    style: TextStyle(
                      color: MlTokens.inkOnFill,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Ask the platform to connect you with more buyers.',
                    style: TextStyle(
                      color: MlTokens.overlayLight.withValues(alpha: 0.85),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Request now',
                        style: TextStyle(
                          color: MlTokens.overlayLight.withValues(alpha: 0.95),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded,
                          color: MlTokens.inkOnFill, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
