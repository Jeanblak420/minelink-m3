import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/layout/app_breakpoints.dart';

/// One KPI tile for super-admin dashboards (registry stats, org insights, etc.).
///
/// When [onTap] is provided the card renders as a tappable surface (Material
/// [InkWell]) with a right-chevron affordance. The same callback handles both
/// mouse-click on desktop and tap on mobile — no platform branching needed.
class PlatformMetricItem {
  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;
  final String? tooltip;

  const PlatformMetricItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.onTap,
    this.tooltip,
  });
}

/// Wrap-based metric grid that sizes each card to its content instead of a fixed aspect ratio.
class PlatformMetricGrid extends StatelessWidget {
  final List<PlatformMetricItem> items;

  /// Columns when [MediaQuery] width is at or above [AppBreakpoints.dashboardWideMin].
  final int wideColumnCount;

  /// Minimum width before showing two columns on narrow layouts.
  final double twoColumnMinWidth;

  const PlatformMetricGrid({
    super.key,
    required this.items,
    this.wideColumnCount = 3,
    this.twoColumnMinWidth = 520,
  });

  @override
  Widget build(BuildContext context) {
    final screenWide = MediaQuery.sizeOf(context).width >= AppBreakpoints.dashboardWideMin;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final columns = screenWide && maxW >= AppBreakpoints.sidebarBreakpoint
            ? wideColumnCount
            : (maxW >= twoColumnMinWidth ? 2 : 1);
        const spacing = 12.0;
        final itemWidth = columns == 1 ? maxW : (maxW - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final item in items)
              SizedBox(
                width: itemWidth,
                child: PlatformMetricCard(item: item),
              ),
          ],
        );
      },
    );
  }
}

/// Blends [accent] into a [ColorScheme] surface tone for KPI card backgrounds.
Color platformMetricCardColor(ColorScheme scheme, Color accent) {
  return Color.alphaBlend(accent.withValues(alpha: 0.11), scheme.surfaceContainerLow);
}

Color platformMetricIconWellColor(ColorScheme scheme, Color accent) {
  return Color.alphaBlend(accent.withValues(alpha: 0.2), scheme.surfaceContainerHighest);
}

Color platformMetricBorderColor(ColorScheme scheme, Color accent) {
  return Color.alphaBlend(accent.withValues(alpha: 0.22), scheme.outlineVariant);
}

/// Compact horizontal metric card; avoids vertical [GridView] overflow on phones.
///
/// If [PlatformMetricItem.onTap] is supplied the card becomes a Material
/// [InkWell] with a right-chevron affordance — works for both mouse-click
/// (Windows desktop) and tap (mobile). Wrapping the [Card] in [InkWell] also
/// gives a free desktop hover ripple via the Material framework.
class PlatformMetricCard extends StatelessWidget {
  final PlatformMetricItem item;

  const PlatformMetricCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final valueColor = Color.lerp(cs.onSurface, item.accent, 0.72) ?? item.accent;
    final borderRadius = MlShape.radiusLarge;
    final isTappable = item.onTap != null;

    final cardBody = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: platformMetricIconWellColor(cs, item.accent),
              borderRadius: MlShape.radiusMedium,
            ),
            child: Icon(item.icon, color: valueColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: valueColor,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isTappable) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: cs.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    final card = Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: platformMetricCardColor(cs, item.accent),
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: platformMetricBorderColor(cs, item.accent)),
      ),
      clipBehavior: isTappable ? Clip.antiAlias : Clip.none,
      child: isTappable
          ? InkWell(
              borderRadius: borderRadius,
              onTap: item.onTap,
              child: cardBody,
            )
          : cardBody,
    );

    if (item.tooltip == null || item.tooltip!.isEmpty) return card;
    return Tooltip(message: item.tooltip!, child: card);
  }
}
