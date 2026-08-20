import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';

import 'charts.dart';
import 'overview_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'primitives.dart';

/// Right card of the top row: headline tonnage, the daily chart, three
/// icon-well metrics and the four-up footer.
class OvTonsMovedCard extends StatelessWidget {
  const OvTonsMovedCard({super.key, required this.tokens, required this.data});

  final MlOv tokens;
  final TonsMoved data;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return OvGlassCard(
      tokens: t,
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 204),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            OvCardHeader(
              tokens: t,
              label: 'Tons moved this period',
              // Absent when there is no prior period to compare against.
              trailing: data.delta == null
                  ? null
                  : OvPill(
                      tokens: t,
                      label: data.delta!.label,
                      tone: data.delta!.tone,
                    ),
            ),
            const SizedBox(height: 2),
            LayoutBuilder(
              builder: (context, c) {
                final headline = _Headline(tokens: t, data: data);
                final chart = _ChartBlock(tokens: t, data: data);
                if (c.maxWidth < 250 + 44 + 340) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [headline, const SizedBox(height: 20), chart],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Flexible(child: headline),
                    const SizedBox(width: 44),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: chart,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: t.line2)),
              ),
              child: OvCellGrid(
                columns: data.metrics.length,
                narrowColumns: 1,
                narrowBelow: 420,
                gap: 14,
                cells: [
                  for (final m in data.metrics)
                    _MiniMetricTile(tokens: t, metric: m),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OvCellGrid(
              columns: 4,
              narrowColumns: 2,
              narrowBelow: 420,
              cells: [
                for (final cell in data.footer)
                  _StatCell(tokens: t, cell: cell),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Headline extends StatelessWidget {
  const _Headline({required this.tokens, required this.data});

  final MlOv tokens;
  final TonsMoved data;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            // 80px of Fraunces is the one thing on this screen that cannot
            // ellipsis or wrap, and an admin on the 1.3 text scale would push
            // it straight through the card edge. Scale down rather than break.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(
                  style: t.f(
                    size: 80,
                    weight: FontWeight.w500,
                    height: 1,
                    letterSpacing: -2.4,
                  ),
                  children: [
                    TextSpan(text: data.value),
                    TextSpan(
                      text: '  ${data.valueSuffix}',
                      style: t.s(size: 20, color: t.inkMid),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (var i = 0; i < data.contextLine.length; i++) ...[
                if (i > 0) Text('·', style: t.s(size: 13, color: t.inkXlo)),
                Text(
                  data.contextLine[i],
                  style: t.s(size: 13, color: t.inkMid),
                ),
              ],
              if (data.deltaLine != null) ...[
                Text('·', style: t.s(size: 13, color: t.inkXlo)),
                Text(
                  data.deltaLine!,
                  style: t.s(
                    size: 12,
                    weight: FontWeight.w600,
                    color: t.tone(data.deltaLineTone),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartBlock extends StatelessWidget {
  const _ChartBlock({required this.tokens, required this.data});

  final MlOv tokens;
  final TonsMoved data;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            const h = 150.0;
            final w = c.maxWidth;
            final n = data.series.length;
            return SizedBox(
              height: h,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  OvTonsAreaChart(
                    tokens: t,
                    series: data.series,
                    compareSeries: data.compareSeries,
                    targetY: data.targetY,
                  ),
                  if (n > 1)
                    for (final i in data.markerIndexes)
                      if (i >= 0 && i < n)
                        Positioned(
                          left: (i / (n - 1)) * w - 3.5,
                          top: data.series[i] * h - 3.5,
                          child: _Marker(tokens: t, active: i == n - 1),
                        ),
                  // The caption rides just above its own rule, and is absent
                  // entirely when no target is set. It moves to the left edge
                  // when the rule sits high, where the right edge already
                  // belongs to the callout chip.
                  if (data.targetY != null && data.targetLabel != null)
                    Positioned(
                      right: data.targetY! < 0.3 ? null : 6,
                      left: data.targetY! < 0.3 ? 0 : null,
                      top: (data.targetY!.clamp(0.0, 1.0) * h) - 14,
                      child: Text(
                        data.targetLabel!.toUpperCase(),
                        style: t.m(
                          size: 9,
                          weight: FontWeight.w500,
                          color: t.acc2.withValues(alpha: 0.8),
                          letterSpacing: 1.8,
                        ),
                      ),
                    ),
                  if (data.calloutLabel != null)
                    Positioned(
                      right: 0,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: t.calloutFill,
                          borderRadius: MlShape.radiusSmall,
                          border:
                              Border.all(color: t.acc.withValues(alpha: 0.4)),
                          boxShadow: t.cardShadow,
                        ),
                        child: Text(
                          data.calloutLabel!,
                          style: t.m(
                            size: 12,
                            weight: FontWeight.w500,
                            letterSpacing: 0.72,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 14,
          child: LayoutBuilder(
            builder: (context, c) => Stack(
              children: [
                for (final tick in data.axisLabels)
                  Positioned(
                    left: tick.key <= 0
                        ? 0
                        : tick.key >= 1
                            ? null
                            : tick.key * c.maxWidth - 12,
                    right: tick.key >= 1 ? 0 : null,
                    child: Text(
                      tick.value,
                      style: t.m(
                        size: 9,
                        color: tick.key >= 1 ? t.inkMid : t.inkLo,
                        letterSpacing: 1.26,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Legend and axis caption share a line until they cannot, then the
        // caption drops to its own. As a Row with an unflexed caption, the
        // caption took its natural width first — at a 2.0 text scale that left
        // the legend a sliver, narrower than one key's own dash, and it
        // overflowed with its label already squeezed to nothing.
        // Same fault, same shape, as the movement chart's legend.
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final k in data.legend)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        OvKeyLine(
                          color: k.muted
                              ? t.inkMid.withValues(alpha: 0.7)
                              : t.tone(k.tone).withValues(alpha: 0.9),
                          dashed: k.dashed,
                        ),
                        const SizedBox(width: 7),
                        Flexible(
                          child: Text(
                            k.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.s(size: 11, color: t.inkMid),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Text(
                'DAILY · TONS',
                style: t.m(size: 9, color: t.inkXlo, letterSpacing: 1.62),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.tokens, required this.active});

  final MlOv tokens;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? t.acc : t.markerFill,
        border: Border.all(color: t.acc, width: 1.5),
        boxShadow: active
            ? [
                BoxShadow(
                  color: t.acc.withValues(alpha: 0.16),
                  spreadRadius: 4,
                ),
                BoxShadow(
                  color: t.acc.withValues(alpha: 0.65),
                  blurRadius: 16,
                ),
              ]
            : null,
      ),
    );
  }
}

class _MiniMetricTile extends StatelessWidget {
  const _MiniMetricTile({required this.tokens, required this.metric});

  final MlOv tokens;
  final MiniMetric metric;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Row(
      children: [
        OvIconWell(tokens: t, icon: metric.icon, tone: metric.tone),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                metric.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.metricLabel,
              ),
              const SizedBox(height: 3),
              Text.rich(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                TextSpan(
                  style: t.m(size: 15, weight: FontWeight.w500),
                  children: [
                    TextSpan(text: metric.value),
                    if (metric.unit != null)
                      TextSpan(
                        text: ' ${metric.unit}',
                        style: t.m(size: 10, color: t.inkLo),
                      ),
                    if (metric.trailing != null)
                      TextSpan(
                        text: '  ${metric.trailing}',
                        style: t.s(
                          size: 11,
                          color: metric.trailingTone == null
                              ? t.inkLo
                              : t.tone(metric.trailingTone!),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.tokens, required this.cell});

  final MlOv tokens;
  final OvStatCell cell;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.line2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            cell.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.metricLabel,
          ),
          const SizedBox(height: 6),
          Text.rich(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            TextSpan(
              style: t.m(
                size: 18,
                weight: FontWeight.w500,
                color: t.tone(cell.tone),
              ),
              children: [
                TextSpan(text: cell.value),
                if (cell.suffix != null)
                  TextSpan(
                    text: cell.suffix,
                    style: t.m(size: 11, color: t.inkLo),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
