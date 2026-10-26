import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/utils/ml_figures.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/providers/order_stockpile_provider.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/components/ml_meta.dart';

/// Compact, read-only view of the mine's stockpile fill for an order, shown to
/// the buyer (on their request) and the transporter (on their dispatched
/// route). Lets both see how much mineral is on the pile and how many full
/// loads are ready to collect, so trucks only roll when there is a full load.
class OrderFillLine extends ConsumerWidget {
  final String requestId;
  const OrderFillLine({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderStockpileProvider(requestId));
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (fill) {
        if (fill == null) return const SizedBox.shrink();
        final cap = fill.maxCapTons;
        final loads = fill.loadsReady;
        final complete = fill.isComplete;
        final accent = complete ? MlTokens.green600 : PortalColors.accent;
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MlSemantic.of(context).surfaceCard,
            borderRadius: MlShape.radiusMedium,
            border: Border.all(color: MlSemantic.of(context).borderCard),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.layers_outlined, size: 16, color: accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Stockpile${fill.mineral != null ? ' · ${fill.mineral}' : ''}',
                      style: textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    cap != null
                        // Grouped like the mine's own stockpile card: it read
                        // "5000 / 5000 t" beside "5,000 / 5,000 t" (S25 walk).
                        ? '${NumberFormat('#,##0').format(fill.balanceTons)} / ${mlTons(cap, decimals: 0)}'
                        : mlTons(fill.balanceTons, decimals: 0),
                    style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800, color: accent),
                  ),
                ],
              ),
              if (cap != null) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: MlShape.radiusSmall,
                  child: LinearProgressIndicator(
                    value: fill.fraction,
                    minHeight: 7,
                    backgroundColor: MlSemantic.of(context).borderCard,
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                complete
                    ? 'Order complete · ${mlCount(loads, 'full load')} '
                        'ready to collect'
                    : loads > 0
                        ? '${mlCount(loads, 'full load')} ready to collect'
                        : 'Being loaded — no full load ready yet',
                style: textTheme.bodySmall?.copyWith(
                  color: complete ? MlTokens.green600 : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
