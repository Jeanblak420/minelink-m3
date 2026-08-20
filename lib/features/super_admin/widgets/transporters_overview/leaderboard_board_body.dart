// ============================================================================
// Full-screen leaderboard — the body
// ----------------------------------------------------------------------------
// Ported from the drop's `screens/leaderboard_full_screen.dart`. Content area
// only: the console shell owns the sidebar, app bar, page title and bell, and
// the drop is explicit that they must not be duplicated here.
//
// Three deviations from the drop, all deliberate:
//
//  1. Tokens are the instance-based [MlOv] this feature already vendors, so the
//     board follows the console's light/dark preference. The drop is dark-only
//     and reads static `MlTokens.*`.
//
//  2. The ranking table's column geometry SCALES WITH TEXT SIZE. The drop pins
//     RANK to 58px, TONS to 108px and so on, and floors the table at 1000px
//     inside a horizontal scroller. Those widths are sized for 13px type; an
//     admin on the console's 1.3 text scale (UiPrefs) would push every
//     numeral out of its own cell — the scroller cannot help, because it is the
//     cells that are too small, not the table. Header and body read the SAME
//     scaled geometry, so the columns stay locked to each other either way.
//
//  3. The delta column header comes from the data instead of reading "VS. JUL",
//     because the period control can put a quarter or a year behind it.
// ============================================================================

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'leaderboard_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'package:flutter_application_1/core/design/components/ml_wide_table.dart';
import 'primitives.dart';

class OvLeaderboardBoardBody extends StatelessWidget {
  const OvLeaderboardBoardBody({
    super.key,
    required this.data,
    required this.onBack,
    this.tokens,
    this.onPeriodSelected,
    this.onExport,
    this.padding = const EdgeInsets.fromLTRB(28, 24, 28, 32),
  });

  final OvLeaderboardBoard data;

  /// Required by the drop's contract: the board is always somewhere you came
  /// from, so there is always a way back.
  final VoidCallback onBack;

  final MlOv? tokens;
  final ValueChanged<int>? onPeriodSelected;
  final VoidCallback? onExport;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final t = tokens ?? MlOv.of(context);
    return Container(
      color: t.canvas,
      child: Stack(
        children: [
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
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Header(
                  tokens: t,
                  data: data,
                  onBack: onBack,
                  onPeriodSelected: onPeriodSelected,
                  onExport: onExport,
                ),
                const SizedBox(height: 18),
                _KpiRow(tokens: t, kpis: data.kpis),
                if (data.podium.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _Podium(tokens: t, entries: data.podium),
                ],
                const SizedBox(height: 18),
                _RankingTable(tokens: t, data: data),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.tokens,
    required this.data,
    required this.onBack,
    this.onPeriodSelected,
    this.onExport,
  });

  final MlOv tokens;
  final OvLeaderboardBoard data;
  final VoidCallback onBack;
  final ValueChanged<int>? onPeriodSelected;
  final VoidCallback? onExport;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _BackChip(tokens: t, onTap: onBack),
        const SizedBox(height: 12),
        Text(
          data.eyebrow.toUpperCase(),
          style: t.s(
            size: 11,
            weight: FontWeight.w600,
            color: t.inkLo,
            letterSpacing: 1.89,
          ),
        ),
        const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            style: t.f(size: 34, letterSpacing: -0.5, height: 1.05),
            children: [
              TextSpan(text: data.titleLead),
              TextSpan(
                text: data.titleAccent,
                style: t.f(
                  size: 34,
                  color: t.acc,
                  letterSpacing: -0.5,
                  height: 1.05,
                  style: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(data.subtitle, style: t.s(size: 13, color: t.inkMid)),
      ],
    );

    final right = Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (data.periods.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: t.overlay(0.02),
              borderRadius: MlShape.radiusMedium,
              border: Border.all(color: t.line2),
            ),
            child: Wrap(
              spacing: 2,
              children: [
                for (var i = 0; i < data.periods.length; i++)
                  _PeriodChip(
                    tokens: t,
                    label: data.periods[i],
                    active: i == data.activePeriod,
                    onTap: onPeriodSelected == null
                        ? null
                        : () => onPeriodSelected!(i),
                  ),
              ],
            ),
          ),
        if (onExport != null)
          _OutlineButton(
            tokens: t,
            label: 'Export',
            icon: Icons.download_rounded,
            onTap: onExport!,
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        // The drop drops the controls below the title under 760px.
        if (c.maxWidth < 760) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [left, const SizedBox(height: 16), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: left),
            const SizedBox(width: 16),
            right,
          ],
        );
      },
    );
  }
}

class _BackChip extends StatefulWidget {
  const _BackChip({required this.tokens, required this.onTap});

  final MlOv tokens;
  final VoidCallback onTap;

  @override
  State<_BackChip> createState() => _BackChipState();
}

class _BackChipState extends State<_BackChip> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.fromLTRB(7, 5, 11, 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(MlOv.rPill),
                border: Border.all(
                  color:
                      _hovered ? t.acc.withValues(alpha: 0.40) : t.line2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 16,
                    color: _hovered ? t.acc2 : t.inkMid,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Back to overview',
                    style: t.s(
                      size: 12,
                      color: _hovered ? t.acc2 : t.inkMid,
                    ),
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

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.tokens,
    required this.label,
    required this.active,
    this.onTap,
  });

  final MlOv tokens;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return MouseRegion(
      cursor: onTap == null
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: active ? t.acc.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: MlShape.radiusSmall,
            border: Border.all(
              color:
                  active ? t.acc.withValues(alpha: 0.30) : Colors.transparent,
            ),
          ),
          child: Text(
            label,
            style: t.s(
              size: 12,
              weight: active ? FontWeight.w600 : FontWeight.w400,
              color: active ? t.acc2 : t.inkMid,
            ),
          ),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.tokens,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final MlOv tokens;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            // minHeight, not height: a bordered box with a fixed height counts
            // its border on top of its padding (CLAUDE.md §10.4).
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: MlShape.radiusMedium,
              border: Border.all(color: t.line2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: t.inkMid),
                const SizedBox(width: 7),
                Text(label, style: t.s(size: 12, color: t.inkMid)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// KPI row
// ---------------------------------------------------------------------------

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.tokens, required this.kpis});

  final MlOv tokens;
  final List<OvBoardKpi> kpis;

  @override
  Widget build(BuildContext context) => OvCellGrid(
        columns: kpis.length,
        narrowColumns: 2,
        narrowBelow: 860,
        gap: 14,
        rowGap: 14,
        cells: [for (final k in kpis) _KpiTile(tokens: tokens, kpi: k)],
      );
}

class _KpiTile extends StatelessWidget {
  const _KpiTile({required this.tokens, required this.kpi});

  final MlOv tokens;
  final OvBoardKpi kpi;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: t.overlay(0.025),
        borderRadius: MlShape.radiusLarge,
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            kpi.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.s(
              size: 10,
              weight: FontWeight.w600,
              color: t.inkMid,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                style: t.m(
                  size: 22,
                  weight: FontWeight.w500,
                  color: kpi.tone == null ? t.inkHi : t.tone(kpi.tone!),
                ),
                children: [
                  TextSpan(text: kpi.value),
                  if (kpi.unit != null)
                    TextSpan(
                      text: kpi.unit,
                      style: t.m(size: 12, color: t.inkLo),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Podium — visual order 2 · 1 · 3, leader in the middle and wider
// ---------------------------------------------------------------------------

class _Podium extends StatelessWidget {
  const _Podium({required this.tokens, required this.entries});

  final MlOv tokens;

  /// In rank order; reordered for display here.
  final List<OvPodiumEntry> entries;

  @override
  Widget build(BuildContext context) {
    final byRank = {for (final e in entries) e.rank: e};
    // 2 · 1 · 3 — putting the leader first is the drop's listed mistake #3.
    final ordered = [
      if (byRank[2] != null) byRank[2]!,
      if (byRank[1] != null) byRank[1]!,
      if (byRank[3] != null) byRank[3]!,
    ];

    return OvFlexRow(
      gap: 14,
      stackedGap: 14,
      // The cards are bottom-aligned in the design, which only reads as
      // deliberate when they end level too.
      equalHeight: true,
      items: [
        for (final e in ordered)
          OvFlexItem(
            basis: e.rank == 1 ? 375 : 300,
            minWidth: e.rank == 1 ? 290 : 270,
            child: e.rank == 1
                ? _LeaderCard(tokens: tokens, entry: e)
                : _RunnerUpCard(tokens: tokens, entry: e),
          ),
      ],
    );
  }
}

class _LeaderCard extends StatelessWidget {
  const _LeaderCard({required this.tokens, required this.entry});

  final MlOv tokens;
  final OvPodiumEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final radius = MlShape.radiusLargeIncreased;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: t.acc.withValues(alpha: 0.6),
            blurRadius: 48,
            spreadRadius: -22,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: t.acc.withValues(alpha: 0.32)),
            gradient: LinearGradient(
              begin: const Alignment(-0.9, -1),
              end: const Alignment(0.9, 1),
              colors: [
                t.acc.withValues(alpha: 0.14),
                t.acc3.withValues(alpha: 0.05),
                t.glassBase.withValues(alpha: 0.85),
              ],
              stops: const [0, 0.45, 0.8],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        t.acc.withValues(alpha: 0),
                        t.acc.withValues(alpha: 0.7),
                        t.acc.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: MlShape.radiusMedium,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [t.acc3, t.acc],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: t.acc.withValues(alpha: 0.8),
                                blurRadius: 18,
                                spreadRadius: -8,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.emoji_events_rounded,
                            size: 20,
                            color: t.trophyInk,
                          ),
                        ),
                        const Spacer(),
                        if (entry.delta != null)
                          Flexible(
                            child: Text(
                              entry.delta!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: t.m(
                                size: 12,
                                weight: FontWeight.w500,
                                color: entry.deltaUp ? t.good : t.bad,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'RANK 0${entry.rank}',
                      style: t.s(
                        size: 11,
                        weight: FontWeight.w600,
                        color: t.acc2,
                        letterSpacing: 1.76,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.s(
                        size: 20,
                        weight: FontWeight.w600,
                        color: t.inkHi,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(
                          style: t.m(
                            size: 28,
                            weight: FontWeight.w500,
                            color: t.acc2,
                          ),
                          children: [
                            TextSpan(text: entry.tons),
                            TextSpan(
                              text: ' t',
                              style: t.m(size: 13, color: t.inkMid),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OvMeter(
                      fraction: entry.barFraction,
                      height: 5,
                      track: t.overlay(0.06),
                      gradient: LinearGradient(colors: [t.acc, t.acc3]),
                      glowColor: t.acc,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      [
                        entry.shareLabel,
                        if (entry.metaSuffix != null) entry.metaSuffix!,
                      ].join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.m(size: 11, color: t.inkMid),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunnerUpCard extends StatelessWidget {
  const _RunnerUpCard({required this.tokens, required this.entry});

  final MlOv tokens;
  final OvPodiumEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.overlay(0.025),
        borderRadius: MlShape.radiusLargeIncreased,
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.overlay(0.05),
                  borderRadius: MlShape.radiusMedium,
                  border: Border.all(color: t.line2),
                ),
                child: Text(
                  '${entry.rank}',
                  style: t.m(size: 12, color: t.inkMid),
                ),
              ),
              const Spacer(),
              if (entry.delta != null)
                Flexible(
                  child: Text(
                    entry.delta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: t.m(
                      size: 12,
                      color: entry.deltaUp ? t.good : t.bad,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            entry.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.s(size: 16, weight: FontWeight.w600, color: t.inkHi),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(
                style: t.m(size: 20, weight: FontWeight.w500, color: t.inkHi),
                children: [
                  TextSpan(text: entry.tons),
                  TextSpan(
                    text: ' t',
                    style: t.m(size: 12, color: t.inkLo),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          OvMeter(
            fraction: entry.barFraction,
            track: t.overlay(0.06),
            color: t.acc2.withValues(alpha: entry.rank == 2 ? 0.60 : 0.38),
          ),
          const SizedBox(height: 10),
          Text(
            entry.shareLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.m(size: 11, color: t.inkLo),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Full ranking table
// ---------------------------------------------------------------------------

/// Column geometry, scaled by the reader's text size.
///
/// The drop's fixed widths are sized for 13px numerals. The console lets each
/// admin run 0.85–1.3, and at 1.3 a 108px TONS cell cannot hold "12,460.8" —
/// which the horizontal scroller cannot fix, because the cell is what is too
/// small. Scaling every width and the table's own floor by the same factor
/// keeps the design's proportions and keeps the header locked to the body.
@immutable
class _Cols {
  const _Cols(this.scale);

  final double scale;

  double get rank => 58 * scale;
  double get tons => 108 * scale;
  double get trips => 66 * scale;
  double get avg => 100 * scale;
  double get onTime => 88 * scale;
  double get open => 88 * scale;
  double get delta => 92 * scale;
  double get gap => 14 * scale;
  double get minWidth => 1000 * scale;

  static const double nameFlex = 1.5;
  static const double shareFlex = 1.3;

  static _Cols of(BuildContext context) {
    // Ratio of scaled to unscaled 13px body type — 1.0 at the default.
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    return _Cols(scale.clamp(1.0, 2.0));
  }
}

class _RankingTable extends StatelessWidget {
  const _RankingTable({required this.tokens, required this.data});

  final MlOv tokens;
  final OvLeaderboardBoard data;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final cols = _Cols.of(context);

    return OvGlassCard(
      tokens: t,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.tableTitle,
                        style: t.f(size: 17, letterSpacing: -0.18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.tableSubtitle,
                        style: t.s(size: 12, color: t.inkMid),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: OvPill(
                    tokens: t,
                    label: data.countLabel,
                    tone: OvTone.ink,
                    mono: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (data.rows.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
              child: Text(
                'No transporters are registered yet.',
                style: t.s(size: 13, color: t.inkMid),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final width = math.max(cols.minWidth, c.maxWidth);
                final table = SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeaderRow(
                        tokens: t,
                        cols: cols,
                        deltaLabel: data.deltaColumnLabel,
                      ),
                      for (var i = 0; i < data.rows.length; i++)
                        _BodyRow(
                          tokens: t,
                          cols: cols,
                          row: data.rows[i],
                          // The leader treatment belongs to whoever actually
                          // moved product, so an all-quiet period has none.
                          leader: i == 0 && !data.rows[i].inactive,
                          last: i == data.rows.length - 1,
                        ),
                    ],
                  ),
                );
                if (width <= c.maxWidth) return table;
                return MlWideTable(child: table);
              },
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.line)),
            ),
            child: Text(
              data.footnote,
              style: t.s(size: 11, color: t.inkLo, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lays out one grid line with the shared column geometry.
///
/// The header row and every body row go through this widget — that is what
/// keeps the columns aligned. Do not rebuild a row with its own `Row`.
class _GridLine extends StatelessWidget {
  const _GridLine({
    required this.cols,
    required this.rank,
    required this.name,
    required this.share,
    required this.tons,
    required this.trips,
    required this.avg,
    required this.onTime,
    required this.open,
    required this.delta,
    required this.padding,
    this.decoration,
  });

  final _Cols cols;
  final Widget rank;
  final Widget name;
  final Widget share;
  final Widget tons;
  final Widget trips;
  final Widget avg;
  final Widget onTime;
  final Widget open;
  final Widget delta;
  final EdgeInsets padding;
  final BoxDecoration? decoration;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: decoration,
        child: Row(
          children: [
            SizedBox(width: cols.rank, child: rank),
            SizedBox(width: cols.gap),
            Expanded(flex: (_Cols.nameFlex * 100).round(), child: name),
            SizedBox(width: cols.gap),
            Expanded(flex: (_Cols.shareFlex * 100).round(), child: share),
            SizedBox(width: cols.gap),
            SizedBox(width: cols.tons, child: tons),
            SizedBox(width: cols.gap),
            SizedBox(width: cols.trips, child: trips),
            SizedBox(width: cols.gap),
            SizedBox(width: cols.avg, child: avg),
            SizedBox(width: cols.gap),
            SizedBox(width: cols.onTime, child: onTime),
            SizedBox(width: cols.gap),
            SizedBox(width: cols.open, child: open),
            SizedBox(width: cols.gap),
            SizedBox(width: cols.delta, child: delta),
          ],
        ),
      );
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.tokens,
    required this.cols,
    required this.deltaLabel,
  });

  final MlOv tokens;
  final _Cols cols;
  final String deltaLabel;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final style = t.s(
      size: 10,
      weight: FontWeight.w600,
      color: t.inkMid,
      letterSpacing: 1.14,
    );
    Widget right(String s) =>
        Text(s, textAlign: TextAlign.right, maxLines: 1, style: style);

    return _GridLine(
      cols: cols,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        color: t.overlay(0.02),
        border: Border(
          top: BorderSide(color: t.line),
          bottom: BorderSide(color: t.line),
        ),
      ),
      rank: Text('RANK', maxLines: 1, style: style),
      name: Text('TRANSPORTER', maxLines: 1, style: style),
      share: Text('SHARE', maxLines: 1, style: style),
      tons: right('TONS'),
      trips: right('TRIPS'),
      avg: right('AVG / TRIP'),
      onTime: right('ON-TIME'),
      open: right('WB OPEN'),
      delta: right(deltaLabel.toUpperCase()),
    );
  }
}

class _BodyRow extends StatelessWidget {
  const _BodyRow({
    required this.tokens,
    required this.cols,
    required this.row,
    required this.leader,
    required this.last,
  });

  final MlOv tokens;
  final _Cols cols;
  final OvRankRow row;
  final bool leader;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final t = tokens;

    Widget num(String text, Color color, {double size = 13}) => Text(
          text,
          textAlign: TextAlign.right,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.m(size: size, color: color),
        );

    return _GridLine(
      cols: cols,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      decoration: BoxDecoration(
        gradient: leader
            ? LinearGradient(
                colors: [
                  t.acc.withValues(alpha: 0.09),
                  t.acc.withValues(alpha: 0),
                ],
                stops: const [0, 0.6],
              )
            : null,
        border:
            last ? null : Border(bottom: BorderSide(color: t.line)),
      ),
      rank: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: MlShape.radiusSmall,
            gradient: leader
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [t.acc3, t.acc],
                  )
                : null,
            color: leader ? null : t.overlay(row.inactive ? 0.03 : 0.05),
            border: leader
                ? null
                : Border.all(color: row.inactive ? t.line : t.line2),
          ),
          child: Text(
            '${row.rank}',
            style: t.m(
              size: 11,
              weight: leader ? FontWeight.w600 : FontWeight.w400,
              color: leader
                  ? t.trophyInk
                  : row.inactive
                      ? t.inkXlo
                      : t.inkMid,
            ),
          ),
        ),
      ),
      name: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            row.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.s(
              size: 14,
              weight: row.inactive ? FontWeight.w500 : FontWeight.w600,
              color: row.inactive ? t.inkMid : t.inkHi,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            row.meta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.s(
              size: 11,
              color: row.inactive ? t.inkXlo : t.inkLo,
            ),
          ),
        ],
      ),
      share: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          OvMeter(
            fraction: row.barFraction,
            track: t.overlay(row.inactive ? 0.05 : 0.06),
            gradient: leader ? LinearGradient(colors: [t.acc, t.acc3]) : null,
            color: leader
                ? null
                : t.acc2.withValues(alpha: row.rank == 2 ? 0.60 : 0.38),
          ),
          const SizedBox(height: 6),
          Text(
            row.shareLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: t.m(
              size: 10,
              color: leader
                  ? t.inkMid
                  : row.inactive
                      ? t.inkXlo
                      : t.inkLo,
            ),
          ),
        ],
      ),
      tons: num(
        row.tons,
        leader ? t.acc2 : (row.inactive ? t.inkLo : t.inkHi),
      ),
      trips: num(row.trips, row.inactive ? t.inkLo : t.inkHi),
      avg: num(row.avgPerTrip, row.inactive ? t.inkXlo : t.inkHi),
      onTime: num(row.onTime, t.tone(row.onTimeTone)),
      open: num(row.waybillsOpen, t.tone(row.waybillsOpenTone)),
      delta: num(row.delta, t.tone(row.deltaTone), size: 12),
    );
  }
}
