
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

class PortalStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  const PortalStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final valueColor = MlSemantic.of(context).textStrong;
    final iconColor = MlTokens.accent;
    final borderRadius = BorderRadius.circular(16);
    final isTappable = onTap != null;

    final cardBody = Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MlSemantic.of(context).surfaceSunken,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MlSemantic.of(context).borderCard),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MlType.figure(
                    color: valueColor,
                    size: MlTokens.fsH1,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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
              color: scheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    final card = Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: MlSemantic.of(context).surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: MlSemantic.of(context).borderCard),
      ),
      clipBehavior: isTappable ? Clip.antiAlias : Clip.none,
      child: isTappable
          ? InkWell(
              borderRadius: borderRadius,
              onTap: onTap,
              child: cardBody,
            )
          : cardBody,
    );

    final hint = tooltip ?? (isTappable ? 'Open $label' : null);
    if (hint == null || hint.isEmpty) return card;
    return Tooltip(message: hint, child: card);
  }
}

class PortalFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onOpen;

  const PortalFeatureCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final borderRadius = BorderRadius.circular(16);

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: MlSemantic.of(context).surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: MlSemantic.of(context).borderCard),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
            if (onOpen != null) ...[
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: MlSemantic.of(context).surfaceCard,
                    foregroundColor: MlTokens.accent,
                    elevation: 0,
                    side: BorderSide(color: MlSemantic.of(context).borderCard),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Open'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// PortalScrollBody DELETED 2026-08-14 (S5-14, P5-32) — replaced by
// `core/design/components/ml_page_body.dart` (MlPageBody), which uses
// MlTokens.contentPadding (28) and MlTokens.contentMaxWidth (1280) instead of
// this file's hardcoded 16/32 padding and 1200 cap, so a portal page and a
// console page now measure the same.
