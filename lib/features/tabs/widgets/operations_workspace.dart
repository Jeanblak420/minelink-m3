import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

import 'package:flutter/material.dart';

class WorkspaceMetric {
  final String label;
  final String value;
  final IconData icon;

  const WorkspaceMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class WorkspaceAction {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const WorkspaceAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isPrimary = false,
  });
}

class WorkspaceItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? trailing;
  final VoidCallback? onTap;

  const WorkspaceItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
    this.onTap,
  });
}

class OperationsWorkspace extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<WorkspaceMetric> metrics;
  final List<WorkspaceAction> actions;
  final String sectionTitle;
  final List<WorkspaceItem> items;
  final Widget? sectionTrailing;
  final String emptyTitle;
  final String emptyMessage;
  final IconData emptyIcon;
  final Widget? footer;

  const OperationsWorkspace({
    super.key,
    required this.title,
    required this.subtitle,
    required this.metrics,
    required this.actions,
    required this.sectionTitle,
    required this.items,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.emptyIcon,
    this.sectionTrailing,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: MlShape.radiusExtraLarge,
              gradient: LinearGradient(
                colors: [
                  Color.alphaBlend(
                    scheme.primary.withAlpha(42),
                    scheme.surfaceContainerHighest,
                  ),
                  Color.alphaBlend(
                    scheme.tertiary.withAlpha(18),
                    scheme.surface,
                  ),
                ],
              ),
              border: Border.all(color: scheme.outlineVariant.withAlpha(160)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _WorkspaceChip(
                      label: 'Live Workspace',
                      icon: Icons.blur_on_rounded,
                    ),
                    _WorkspaceChip(
                      label: title,
                      icon: Icons.dashboard_customize_outlined,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (metrics.isNotEmpty)
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: metrics.map((metric) {
                return SizedBox(
                  width: 190,
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: scheme.surface.withAlpha(190),
                      borderRadius: MlShape.radiusExtraLarge,
                      border: Border.all(
                        color: scheme.outlineVariant.withAlpha(150),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(metric.icon, color: scheme.primary),
                        const SizedBox(height: 12),
                        Text(
                          metric.value,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metric.label,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: actions.map((action) {
                if (action.isPrimary) {
                  return FilledButton.tonalIcon(
                    onPressed: action.onPressed,
                    icon: Icon(action.icon),
                    label: Text(action.label),
                  );
                }

                return OutlinedButton.icon(
                  onPressed: action.onPressed,
                  icon: Icon(action.icon),
                  label: Text(action.label),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  sectionTitle,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (sectionTrailing != null) sectionTrailing!,
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: scheme.surface.withAlpha(190),
                borderRadius: MlShape.radiusExtraLarge,
                border: Border.all(color: scheme.outlineVariant.withAlpha(150)),
              ),
              child: Column(
                children: [
                  Icon(emptyIcon, size: 48, color: scheme.primary),
                  const SizedBox(height: 16),
                  Text(
                    emptyTitle,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptyMessage,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: scheme.surface.withAlpha(190),
                      borderRadius: MlShape.radiusExtraLarge,
                      border: Border.all(
                        color: scheme.outlineVariant.withAlpha(150),
                      ),
                    ),
                    child: ListTile(
                      onTap: item.onTap,
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer.withAlpha(220),
                          borderRadius: MlShape.radiusLarge,
                        ),
                        child: Icon(item.icon, color: scheme.primary),
                      ),
                      title: Text(item.title),
                      subtitle: Text(item.subtitle),
                      trailing: item.trailing != null
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer.withAlpha(200),
                                borderRadius: MlShape.pill,
                              ),
                              child: Text(
                                item.trailing!,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: scheme.onSecondaryContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          if (footer != null) ...[const SizedBox(height: 20), footer!],
        ],
      ),
    );
  }
}

class _WorkspaceChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _WorkspaceChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withAlpha(185),
        borderRadius: MlShape.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
