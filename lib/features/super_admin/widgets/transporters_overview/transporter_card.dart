import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';

import 'charts.dart';
import 'overview_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'primitives.dart';

/// One row in the "Top transporters" list.
class OvTransporterCard extends StatelessWidget {
  const OvTransporterCard({
    super.key,
    required this.tokens,
    required this.row,
    this.onOpenWorkspace,
  });

  final MlOv tokens;
  final TransporterRow row;

  /// Null hides the action rather than offering a button that goes nowhere.
  final VoidCallback? onOpenWorkspace;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return OvGlassCard(
      tokens: t,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      child: OvFlexRow(
        gap: 28,
        stackedGap: 24,
        crossAxisAlignment: CrossAxisAlignment.center,
        items: [
          OvFlexItem(
            basis: 320,
            minWidth: 280,
            child: _Identity(tokens: t, row: row),
          ),
          OvFlexItem(
            // 300, not the drop's 260. Four cells share this column, and the
            // widest holds a five-figure tonnage plus its unit — 84px of
            // JetBrains Mono. At 260 the leader's tons ellipsise, which is the
            // one number on the card nobody can afford to lose.
            basis: 300,
            minWidth: 250,
            child: _Stats(tokens: t, row: row),
          ),
          OvFlexItem(
            // 260/240, not the drop's 220/200. The meter row is
            // label + gap + bar + gap + a 40px percentage, and the label and
            // the bar are both flex-1 — so the label gets (W − 64) / 2. At
            // 220 that is 78px and "Waybills closed" needs 86: the card's own
            // meter label rendered as "Waybills clos…" on any window wide
            // enough for the three-column arrangement (~1750px with the rail).
            // Measured 2026-08-21. It never showed up in a render because the
            // console's content column collapses these cards to one column
            // first, and it never failed a sweep because a truncation is a
            // valid layout.
            basis: 260,
            minWidth: 240,
            child: _Meters(tokens: t, row: row, onOpen: onOpenWorkspace),
          ),
        ],
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.tokens, required this.row});

  final MlOv tokens;
  final TransporterRow row;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 48×48 conic cyan/teal/sky ring, 1px padding, inner panel at r13.
        Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            borderRadius: MlShape.radiusLarge,
            gradient: SweepGradient(
              startAngle: 3.66, // 210°
              endAngle: 3.66 + 6.2832,
              colors: [
                t.acc.withValues(alpha: 0.4),
                t.acc3.withValues(alpha: 0.4),
                t.acc2.withValues(alpha: 0.4),
                t.acc.withValues(alpha: 0.4),
              ],
            ),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.avatarInner,
              borderRadius: MlShape.radiusLarge,
            ),
            child: Text(
              row.code,
              style: t.m(size: 14, weight: FontWeight.w700, color: t.acc2),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    row.name,
                    style: t.s(
                      size: 16,
                      weight: FontWeight.w600,
                      color: t.inkHi,
                      letterSpacing: -0.16,
                    ),
                  ),
                  for (final b in row.badges)
                    OvPill(tokens: t, label: b.label, tone: b.tone),
                ],
              ),
              const SizedBox(height: 4),
              _DotList(
                tokens: t,
                parts: [
                  '${row.employees} employees',
                  '${row.drivers} drivers',
                  '${row.fleet} fleet',
                  '${row.routes} routes',
                  // "never active", not "last active never".
                  row.lastActive == null
                      ? 'never active'
                      : 'last active ${row.lastActive}',
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Capped at 240 as designed, but with no minimum: a `Row`
                  // measures its non-flex children at unbounded width, so a
                  // hard floor here is what overflows the card at 1.3 scale.
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 240),
                      child: OvTempoBars(tokens: t, values: row.tempo),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      '15-DAY TEMPO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: t.s(size: 10, color: t.inkLo, letterSpacing: 1.2),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DotList extends StatelessWidget {
  const _DotList({required this.tokens, required this.parts});

  final MlOv tokens;
  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0)
            Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(color: t.inkLo, shape: BoxShape.circle),
            ),
          Text(parts[i], style: t.s(size: 11, color: t.inkMid)),
        ],
      ],
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.tokens, required this.row});

  final MlOv tokens;
  final TransporterRow row;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return OvCellGrid(
      columns: 4,
      narrowColumns: 2,
      // 100px per cell, because that is what the widest thing in one holds:
      // "12,420.5t" is ~95px of 15px JetBrains Mono, and the labels above it
      // ("WB DONE") are shorter than that. The old threshold said the ROW had
      // to be 300 wide, which at 305 gave each cell 72 and printed the board's
      // ranking figure as "4,382.…" on a phone. Measured 2026-08-21.
      minCellWidth: 100,
      // …and at 10 rather than the drop's 14: five figures of tonnage plus a
      // unit is 84px of JetBrains Mono, which three 14px gaps do not leave
      // room for at the width this column actually gets.
      gap: 10,
      cells: [
        _Cell(tokens: t, label: 'Trips', value: row.trips),
        _Cell(tokens: t, label: 'Tons', value: row.tons, unit: 't'),
        _Cell(tokens: t, label: 'WB done', value: row.waybillsDone),
        _Cell(
          tokens: t,
          label: 'WB open',
          value: '${row.waybillsOpen}',
          tone: row.openTone,
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.tokens,
    required this.label,
    required this.value,
    this.unit,
    this.tone = OvTone.ink,
  });

  final MlOv tokens;
  final String label;
  final String value;
  final String? unit;
  final OvTone tone;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.metricLabel,
        ),
        const SizedBox(height: 4),
        Text.rich(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          TextSpan(
            style: t.m(size: 15, weight: FontWeight.w500, color: t.tone(tone)),
            children: [
              TextSpan(text: value),
              // Tight against the figure, as in the reference: the space the
              // drop's code puts here is the last 6px this cell has.
              if (unit != null)
                TextSpan(text: unit, style: t.m(size: 10, color: t.inkLo)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Meters extends StatelessWidget {
  const _Meters({required this.tokens, required this.row, this.onOpen});

  final MlOv tokens;
  final TransporterRow row;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < row.meters.length; i++) ...[
          if (i > 0) const SizedBox(height: 10),
          _MeterRow(tokens: t, spec: row.meters[i]),
        ],
        if (onOpen != null) ...[
          const SizedBox(height: 14),
          _OpenWorkspaceButton(tokens: t, onTap: onOpen),
        ],
      ],
    );
  }
}

class _MeterRow extends StatelessWidget {
  const _MeterRow({required this.tokens, required this.spec});

  final MlOv tokens;
  final OvMeterSpec spec;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Row(
      children: [
        Flexible(
          child: Text(
            spec.label,
            // TWO lines, and it wraps. The width above is sized so one line
            // is enough at the default text scale; a reader who has raised
            // the console's scale gets a taller row rather than a cut label,
            // which is the right way for this to give.
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.s(size: 11, color: t.inkMid),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OvMeter(
            fraction: spec.percent / 100,
            track: t.overlay(0.05),
            gradient: LinearGradient(colors: [t.acc3, t.acc]),
          ),
        ),
        const SizedBox(width: 12),
        // minWidth, not a fixed box: 100% at the 1.3 text scale is wider than
        // the 40px the design reserves.
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 40),
          child: Align(
            alignment: Alignment.centerRight,
            widthFactor: 1,
            child: Text('${spec.percent}%', style: t.m(size: 12)),
          ),
        ),
      ],
    );
  }
}

class _OpenWorkspaceButton extends StatefulWidget {
  const _OpenWorkspaceButton({required this.tokens, this.onTap});

  final MlOv tokens;
  final VoidCallback? onTap;

  @override
  State<_OpenWorkspaceButton> createState() => _OpenWorkspaceButtonState();
}

class _OpenWorkspaceButtonState extends State<_OpenWorkspaceButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.acc.withValues(alpha: _hover ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(MlOv.rChip),
            border: Border.all(color: t.acc.withValues(alpha: 0.28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  'Open workspace',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: t.s(
                    size: 12,
                    weight: FontWeight.w600,
                    color: t.acc2,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Icon(Icons.arrow_forward_rounded, size: 15, color: t.acc2),
            ],
          ),
        ),
      ),
    );
  }
}
