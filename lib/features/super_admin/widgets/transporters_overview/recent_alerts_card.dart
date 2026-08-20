import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';

import 'overview_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'primitives.dart';

/// Aside card #3 — recent alerts.
class OvRecentAlertsCard extends StatelessWidget {
  const OvRecentAlertsCard({
    super.key,
    required this.tokens,
    required this.alerts,
    required this.subtitle,
    this.onViewAll,
  });

  final MlOv tokens;
  final List<AlertItem> alerts;

  /// Names the window the alerts were computed over, so the card cannot claim
  /// "the last 24h" while showing figures for the month.
  final String subtitle;

  /// The design shows a "View all" ghost button. These alerts are derived from
  /// the month's own rows rather than stored anywhere, so there is nothing to
  /// open — the button is omitted unless a caller supplies a destination.
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return OvGlassCard(
      tokens: t,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Recent alerts',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.f(
                        size: 16,
                        weight: FontWeight.w500,
                        letterSpacing: -0.16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.s(size: 11, color: t.inkMid),
                    ),
                  ],
                ),
              ),
              if (onViewAll != null) ...[
                const SizedBox(width: 10),
                _GhostButton(tokens: t, label: 'View all', onTap: onViewAll!),
              ],
            ],
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < alerts.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _AlertRow(tokens: t, item: alerts[i]),
          ],
        ],
      ),
    );
  }
}

class _AlertRow extends StatelessWidget {
  const _AlertRow({required this.tokens, required this.item});

  final MlOv tokens;
  final AlertItem item;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: t.overlay(0.02),
        borderRadius: BorderRadius.circular(MlOv.rTile),
        border: Border.all(color: t.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OvIconWell(tokens: t, icon: item.icon, tone: item.tone),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  style: t.s(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: t.inkHi,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.body,
                  style: t.s(size: 11, color: t.inkMid, height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(item.age, style: t.m(size: 10, color: t.inkLo)),
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.tokens,
    required this.label,
    required this.onTap,
  });

  final MlOv tokens;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            borderRadius: MlShape.radiusSmall,
            border: Border.all(color: t.line2),
          ),
          child: Text(label, style: t.s(size: 11, color: t.inkMid)),
        ),
      ),
    );
  }
}
