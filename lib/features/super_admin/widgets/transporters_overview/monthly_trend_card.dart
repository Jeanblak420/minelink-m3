import 'package:flutter/material.dart';

import 'charts.dart';
import 'overview_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'primitives.dart';

/// Aside card #1 — headline growth, rail chart and the 2-up stat grid.
class OvMonthlyTrendCard extends StatelessWidget {
  const OvMonthlyTrendCard({
    super.key,
    required this.tokens,
    required this.data,
  });

  final MlOv tokens;
  final MonthlyTrend data;

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
          Text(
            'MONTHLY MOVEMENT TREND',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.s(
              size: 11,
              weight: FontWeight.w600,
              color: t.inkMid,
              letterSpacing: 1.68,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            // No prior month is an em dash, never a manufactured "+0%".
            data.headline ?? '—',
            style: t.s(
              size: 32,
              weight: FontWeight.w700,
              color: t.inkHi,
              letterSpacing: -0.64,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.caption,
            style: t.s(size: 11, color: t.tone(data.captionTone)),
          ),
          const SizedBox(height: 14),
          OvTrendRailChart(tokens: t, series: data.series),
          const SizedBox(height: 16),
          _StatGrid(tokens: t, stats: data.stats),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.tokens, required this.stats});

  final MlOv tokens;
  final List<TrendStat> stats;

  @override
  Widget build(BuildContext context) => OvCellGrid(
        columns: 2,
        narrowColumns: 1,
        // Was `narrowBelow: 190`, which is this same figure written as a row
        // width: (190 − 10) / 2.
        minCellWidth: 90,
        gap: 10,
        rowGap: 10,
        cells: [for (final s in stats) _StatTile(tokens: tokens, stat: s)],
      );
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.tokens, required this.stat});

  final MlOv tokens;
  final TrendStat stat;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: t.overlay(0.03),
        borderRadius: BorderRadius.circular(MlOv.rChip),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            TextSpan(
              style: t.m(
                size: 16,
                weight: FontWeight.w500,
                color: t.tone(stat.tone),
              ),
              children: [
                TextSpan(text: stat.value),
                if (stat.unit != null)
                  TextSpan(
                    text: stat.unit,
                    style: t.m(size: 10, color: t.inkLo),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(
            stat.label.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.s(
              size: 9,
              weight: FontWeight.w600,
              color: t.inkMid,
              letterSpacing: 1.08,
            ),
          ),
        ],
      ),
    );
  }
}
