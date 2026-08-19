// ============================================================================
// Transporters overview — the body
// ----------------------------------------------------------------------------
// The content area only: no sidebar, no app bar, no page title. The portal
// scaffold already owns those and the drop deliberately does not duplicate
// them (README §10).
//
// Layout is CSS flex reproduced by [OvFlexRow]: each region declares a basis
// and a minimum, leftover width is split EQUALLY, and the row collapses to a
// column once the minimums no longer fit. At the reference width (~1950) that
// gives main ≈ 1176 and aside ≈ 756, with the fleet card pinned at 320.
// ============================================================================

import 'package:flutter/material.dart';

import 'fleet_distribution_card.dart';
import 'leaderboard_card.dart';
import 'monthly_trend_card.dart';
import 'overview_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'primitives.dart';
import 'recent_alerts_card.dart';
import 'tons_moved_card.dart';
import 'transporter_card.dart';

class TransportersOverviewBody extends StatefulWidget {
  const TransportersOverviewBody({
    super.key,
    required this.data,
    this.tokens,
    this.showAlerts = true,
    this.padding = const EdgeInsets.fromLTRB(28, 24, 28, 32),
    this.onOpenWorkspace,
    this.onViewAllAlerts,
    this.onOpenLeaderboard,
  });

  final OverviewData data;

  /// Overrides the palette. Defaults to the console's own light/dark choice.
  final MlOv? tokens;

  final bool showAlerts;
  final EdgeInsets padding;

  /// Null, or a row whose `id` is empty, hides that card's action.
  final void Function(TransporterRow row)? onOpenWorkspace;
  final VoidCallback? onViewAllAlerts;

  /// Opens the full ranking. Null leaves the leaderboard card exactly as it
  /// was — no chevron, no hover lift, no pointer cursor.
  final VoidCallback? onOpenLeaderboard;

  @override
  State<TransportersOverviewBody> createState() =>
      _TransportersOverviewBodyState();
}

class _TransportersOverviewBodyState extends State<TransportersOverviewBody> {
  OvTransporterFilter _filter = OvTransporterFilter.all;

  /// The cards actually shown, after the chip filter.
  List<TransporterRow> get _visible {
    final all = widget.data.transporters;
    if (all.isEmpty) return all;
    final avg = all.fold<double>(0, (s, c) => s + c.tonsValue) / all.length;
    return all.where((c) => _filter.accepts(c, avg)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens ?? MlOv.of(context);
    final d = widget.data;

    return Container(
      color: t.canvas,
      child: Stack(
        children: [
          // Page-level ambient wash behind the content.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: t.ambientLeft),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: t.ambientRight),
            ),
          ),
          SingleChildScrollView(
            padding: widget.padding,
            child: OvFlexRow(
              gap: MlOv.columnGap,
              stackedGap: 16,
              items: [
                OvFlexItem(
                  basis: MlOv.mainBasis,
                  minWidth: MlOv.mainMin,
                  child: _mainColumn(t, d),
                ),
                OvFlexItem(
                  basis: MlOv.asideBasis,
                  minWidth: MlOv.asideMin,
                  child: _aside(t, d),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mainColumn(MlOv t, OverviewData d) {
    final visible = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        OvFlexRow(
          gap: 18,
          // The two cards read as one band across the top of the page, so the
          // shorter one runs to the taller one's height instead of leaving a
          // ragged bottom edge.
          equalHeight: true,
          items: [
            OvFlexItem(
              basis: 320,
              minWidth: 280,
              // Fixed: `flex: 0 1 320px`. If this card grows past 320 on a
              // wide window, the grow flag was lost.
              grow: false,
              child: OvFleetDistributionCard(tokens: t, data: d.fleet),
            ),
            OvFlexItem(
              basis: 420,
              minWidth: 340,
              child: OvTonsMovedCard(tokens: t, data: d.tons),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _TopTransportersHeader(
          tokens: t,
          subtitle: d.topTransportersSubtitle,
          count: d.transporters.length,
          selected: _filter,
          onSelect: (f) => setState(() => _filter = f),
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty)
          _EmptyList(tokens: t, filter: _filter)
        else
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            OvTransporterCard(
              tokens: t,
              row: visible[i],
              onOpenWorkspace:
                  (widget.onOpenWorkspace == null || visible[i].id.isEmpty)
                      ? null
                      : () => widget.onOpenWorkspace!(visible[i]),
            ),
          ],
      ],
    );
  }

  Widget _aside(MlOv t, OverviewData d) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          OvMonthlyTrendCard(tokens: t, data: d.trend),
          const SizedBox(height: 16),
          OvLeaderboardCard(
            tokens: t,
            data: d.leaderboard,
            onTap: widget.onOpenLeaderboard,
          ),
          if (widget.showAlerts) ...[
            const SizedBox(height: 16),
            OvRecentAlertsCard(
              tokens: t,
              alerts: d.alerts,
              subtitle: 'Signals from ${d.tons.contextLine.last}',
              onViewAll: widget.onViewAllAlerts,
            ),
          ],
        ],
      );
}

class _TopTransportersHeader extends StatelessWidget {
  const _TopTransportersHeader({
    required this.tokens,
    required this.subtitle,
    required this.count,
    required this.selected,
    required this.onSelect,
  });

  final MlOv tokens;
  final String subtitle;
  final int count;
  final OvTransporterFilter selected;
  final ValueChanged<OvTransporterFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 12,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Top transporters',
              style: t.f(size: 19, weight: FontWeight.w500, letterSpacing: -0.19),
            ),
            const SizedBox(height: 2),
            Text(subtitle, style: t.s(size: 12, color: t.inkMid)),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in OvTransporterFilter.values)
              _FilterChip(
                tokens: t,
                label: f.label,
                count: f == OvTransporterFilter.all ? count : null,
                active: f == selected,
                onTap: () => onSelect(f),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.tokens,
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
  });

  final MlOv tokens;
  final String label;
  final bool active;
  final int? count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        // No `alignment:` here. A Wrap hands its children its own maxWidth, and
        // a Container with an alignment and no width expands to fill it — the
        // chips then stack as four full-width bars instead of sitting in a row.
        child: Container(
          constraints: const BoxConstraints(minHeight: 28),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active ? t.acc.withValues(alpha: 0.10) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active ? t.acc.withValues(alpha: 0.4) : t.line2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: t.s(
                  size: 11.5,
                  weight: FontWeight.w500,
                  color: active ? t.acc2 : t.inkMid,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 6),
                Text(
                  '$count',
                  style: t.m(
                    size: 11,
                    color: t.acc2.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when a filter matches nothing — an empty list should say why it is
/// empty, not just stop.
class _EmptyList extends StatelessWidget {
  const _EmptyList({required this.tokens, required this.filter});

  final MlOv tokens;
  final OvTransporterFilter filter;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return OvGlassCard(
      tokens: t,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_shipping_outlined, size: 22, color: t.inkLo),
          const SizedBox(height: 10),
          Text(
            filter == OvTransporterFilter.all
                ? 'No transporter activity this month'
                : 'No transporters match “${filter.label}”',
            textAlign: TextAlign.center,
            style: t.s(size: 13, weight: FontWeight.w600, color: t.ink),
          ),
        ],
      ),
    );
  }
}
