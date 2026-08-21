// ============================================================================
// MineLink — Targets Screen
// ----------------------------------------------------------------------------
// Two target systems behind one switch. Each tab carries the same four parts:
//
//   SET      a dial per target
//   VIEW     a table (months) or ladder (horizons)
//   GRAPH    performance over time
//   RECORD   closed months / closed cycles, read-only
//
// The screen owns no persistence. Every edit calls out through a callback and
// waits for new [data] to come back down, so the widget layer can never hold a
// target the backend rejected.
// ============================================================================

import 'package:flutter_application_1/core/design/components/ml_wide_table.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';

import 'minelink_screens_core.dart';
import 'minelink_targets_core.dart';
import 'minelink_targets_charts.dart';
import 'minelink_target_dial.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

enum MlTargetsTab { shortTerm, longTerm }

class MineLinkTargetsScreen extends StatefulWidget {
  const MineLinkTargetsScreen({
    super.key,
    required this.data,
    this.onMonthTargetChanged,
    this.onHorizonDraftChanged,
    this.onLockCycle,
    this.onStartNewCycle,
    this.onNavigate,
    this.errorFor,
    this.tokens,
    this.initialTab = MlTargetsTab.shortTerm,
    this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 40),
  });

  final MlTargetsData data;

  /// `(monthKey, tons)` — e.g. `('2026-09', 450)`. Persist, then push new
  /// [data] down. The screen does not mutate its own copy.
  final void Function(String monthKey, double tons)? onMonthTargetChanged;

  /// `(horizonKey, tons)` — e.g. `('d7', 90)`. Draft only; nothing is
  /// committed until [onLockCycle].
  final void Function(String horizonKey, double tons)? onHorizonDraftChanged;

  /// Commit all six horizons. Only ever called when every horizon is set and
  /// the user has confirmed.
  final void Function(Map<String, double> targets)? onLockCycle;

  /// Only ever called once the 365 days have elapsed.
  final VoidCallback? onStartNewCycle;

  final ValueChanged<String>? onNavigate;

  /// Why the last write for a target was refused, if it was.
  ///
  /// Keyed exactly as the write path keys its own calls — `m:2026-09` for a
  /// month, `h:d7` for a horizon — so the message lands on the dial it belongs
  /// to. A notice that scrolls away cannot be read next to the field it is
  /// about, and the ring disagreeing with the input is precisely the moment
  /// somebody needs to see why.
  final String? Function(String key)? errorFor;

  final MlGlass? tokens;
  final MlTargetsTab initialTab;
  final EdgeInsets padding;

  @override
  State<MineLinkTargetsScreen> createState() => _MineLinkTargetsScreenState();
}

class _MineLinkTargetsScreenState extends State<MineLinkTargetsScreen> {
  late MlTargetsTab _tab = widget.initialTab;
  MlTargetOutcome? _historyFilter;

  MlTargetsData get d => widget.data;

  @override
  Widget build(BuildContext context) {
    final t = widget.tokens ?? MlGlass.of(context);

    return Container(
      color: t.bg0,
      child: SingleChildScrollView(
        padding: widget.padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (d.cycleComplete) ...[
              _CycleCompleteBanner(
                tokens: t,
                cycle: d.cycle,
                onReview: () => setState(() => _tab = MlTargetsTab.longTerm),
              ),
              const SizedBox(height: 16),
            ],
            _tabs(t),
            const SizedBox(height: 14),
            if (_tab == MlTargetsTab.shortTerm)
              ..._shortTerm(t)
            else
              ..._longTerm(t),
          ],
        ),
      ),
    );
  }

  // -- tabs ----------------------------------------------------------------

  Widget _tabs(MlGlass t) {
    final unset = <int>[
      for (var i = 0; i < d.months.length; i++)
        if (d.canEditMonth(i) && d.months[i].target <= 0) i
    ].length;
    final pending = kMlHorizons
        .where((z) => d.horizonOutcome(z) == MlTargetOutcome.pending)
        .length;

    Widget tab(MlTargetsTab v, IconData icon, String label, int badge) {
      final on = _tab == v;
      return MlHoverLift(
        lift: 0,
        onTap: () => setState(() => _tab = v),
        builder: (context, hovered) => AnimatedContainer(
          duration: mlScreenMotion(context, const Duration(milliseconds: 140)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: on ? t.accent.withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: MlShape.radiusSmall,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: on ? t.accent2 : t.inkMid),
              const SizedBox(width: 8),
              // Flexible and WRAPPING, not ellipsising. The note below this
              // builder is explicit that nothing here can ellipsize without
              // destroying the meaning — "Long term targets & goals" truncated
              // to "Long term targets…" is a different tab. So the label takes
              // a second line instead, which is what a tab with a long label
              // should do at an accessibility text size.
              //
              // It began overflowing by 131px when the label moved from 13 onto
              // titleSmall's 14. The Wrap around the tabs already stacks them
              // vertically; what it could not do is make ONE tab narrower than
              // its own contents.
              Flexible(
                child: Text(
                  label,
                  softWrap: true,
                  style: context.mlText.titleSmall.copyWith(
                    color: on ? t.accent2 : t.inkMid,
                  ),
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '$badge',
                  style: context.mlText.code(
                    color: (on ? t.accent : t.inkLo),
                    size: 10,
                    weight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // A Wrap, not a Row. Two tabs reading "Short term targets" and "Long
        // term targets & goals" side by side are wider than a narrow console
        // at an accessibility text size, and a Row would simply overflow —
        // there is nothing here that can ellipsize without destroying the
        // label. The second tab drops to its own line instead.
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: t.inkHi.withValues(alpha: 0.04),
            border: Border.all(color: t.line),
            borderRadius: MlShape.radiusMedium,
          ),
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              tab(MlTargetsTab.shortTerm, Icons.calendar_month_outlined,
                  'Short term targets', unset),
              tab(MlTargetsTab.longTerm, Icons.flag_outlined,
                  'Long term targets & goals', pending),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _tab == MlTargetsTab.shortTerm
              ? 'Month by month. Any month that has not closed can be edited; '
                  'closed months are a record and stay locked.'
              : 'Six horizon goals committed as one 12-month cycle. Once locked, '
                  'nothing changes until the cycle has run its full 365 days.',
          style: context.mlText.bodySmall.copyWith(color: t.inkMid, height: 1.5),
        ),
      ],
    );
  }

  // ========================================================================
  // SHORT TERM
  // ========================================================================

  List<Widget> _shortTerm(MlGlass t) {
    final editable = <int>[
      for (var i = 0; i < d.months.length; i++)
        if (d.canEditMonth(i)) i
    ];
    final unset = editable.where((i) => d.months[i].target <= 0).length;

    return [
      // SET
      MlPanel(
        tokens: t,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            MlSectionHead(
              tokens: t,
              size: 18,
              title: 'Set monthly targets',
              subtitle: 'One dial per month that has not closed — '
                  '${editable.length} available'
                  '${unset > 0 ? ', $unset still without a target' : ''}. '
                  'Closed months do not appear here; they are locked.',
            ),
            const SizedBox(height: 14),
            _dialGrid(
              editable
                  .map((i) => MlTargetDial(
                        tokens: t,
                        label: d.months[i].label,
                        sublabel: i == d.currentIndex
                            ? 'CURRENT MONTH · IN PROGRESS'
                            : 'PLANNED',
                        target: d.months[i].target,
                        actual: d.months[i].hasActuals
                            ? d.months[i].total
                            : null,
                        highlighted: i == d.currentIndex,
                        errorText:
                            widget.errorFor?.call('m:${d.months[i].key}'),
                        onChanged: (v) => widget.onMonthTargetChanged
                            ?.call(d.months[i].key, v),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // GRAPH
      MlPanel(
        tokens: t,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            MlSectionHead(
              tokens: t,
              size: 18,
              title: 'Short-term performance',
              subtitle: 'Every month, target against actual. Hollow columns '
                  'are targets, solid columns are what moved. Dashed hollow '
                  'columns are planned months with no actuals yet.',
            ),
            const SizedBox(height: 14),
            MlShortTermChart(data: d, tokens: t),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // VIEW
      _MonthTable(
        tokens: t,
        data: d,
        onChanged: widget.onMonthTargetChanged,
      ),
      const SizedBox(height: 16),

      // RECORD
      _TargetHistory(
        tokens: t,
        data: d,
        filter: _historyFilter,
        onFilter: (f) => setState(() => _historyFilter = f),
      ),
    ];
  }

  // ========================================================================
  // LONG TERM
  // ========================================================================

  List<Widget> _longTerm(MlGlass t) {
    final editable = d.canEditCycle;

    return [
      _CycleCard(
        tokens: t,
        data: d,
        onLock: _confirmLock,
        onStartNew: _confirmNewCycle,
      ),
      const SizedBox(height: 16),

      // SET
      MlPanel(
        tokens: t,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            MlSectionHead(
              tokens: t,
              size: 18,
              title: 'Set horizon targets',
              subtitle: editable
                  ? 'One dial per horizon. All six must be set before the '
                      'cycle can be locked.'
                  : 'These six were locked in and reopen in '
                      '${d.daysUntilCycleReopens} days. Until then they are a '
                      'fixed commitment — that is what makes the growth '
                      'measurable.',
            ),
            const SizedBox(height: 14),
            _dialGrid(
              kMlHorizons.map((z) {
                final reached = d.horizonReached(z);
                return MlTargetDial(
                  tokens: t,
                  label: '${z.name} target',
                  sublabel: '${z.description} · DAY ${z.days}',
                  target: d.horizonTarget(z),
                  actual: d.horizonActual(z),
                  editable: editable,
                  note: reached
                      ? null
                      : 'checkpoint in ${z.days - d.elapsedCycleDays} days',
                  lockedNote:
                      'Locked for ${d.daysUntilCycleReopens} more days',
                  errorText: widget.errorFor?.call('h:${z.key}'),
                  onChanged: (v) =>
                      widget.onHorizonDraftChanged?.call(z.key, v),
                );
              }).toList(),
            ),
            if (editable) ...[
              const SizedBox(height: 16),
              _LockWarning(
                tokens: t,
                canLock: d.cycle.canLock,
                unset: d.cycle.unsetHorizons.length,
                onLock: _confirmLock,
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 16),

      // VIEW
      _HorizonLadder(tokens: t, data: d),
      const SizedBox(height: 16),

      // GRAPH ×2
      MlPanel(
        tokens: t,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            MlSectionHead(
              tokens: t,
              size: 18,
              title: 'Cycle progress',
              subtitle: 'Cumulative tonnage since the cycle start. Markers '
                  'show each horizon target and whether it was met; the '
                  'vertical line is today.',
            ),
            const SizedBox(height: 14),
            MlCycleChart(data: d, tokens: t),
          ],
        ),
      ),
      const SizedBox(height: 16),
      MlPanel(
        tokens: t,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            MlSectionHead(
              tokens: t,
              size: 18,
              title: 'Horizon attainment',
              subtitle: 'How each of the six goals landed against its target. '
                  'Dashed outlines are horizons whose checkpoint has not '
                  'arrived yet.',
            ),
            const SizedBox(height: 14),
            MlHorizonChart(data: d, tokens: t),
          ],
        ),
      ),
      const SizedBox(height: 16),

      // RECORD
      _CycleArchive(tokens: t, cycles: d.pastCycles),
    ];
  }

  Widget _dialGrid(List<Widget> dials) => LayoutBuilder(
        builder: (context, c) {
          final cols = (c.maxWidth / 232).floor().clamp(1, 6);
          return MlGrid(columns: cols, gap: 12, children: dials);
        },
      );

  // -- confirmations -------------------------------------------------------

  Future<void> _confirmLock() async {
    if (!d.cycle.canLock) {
      final missing =
          d.cycle.unsetHorizons.map((z) => z.name).join(', ');
      await _dialog(
        title: 'Set all six horizons first',
        body: 'Still unset: $missing.\n\nA cycle cannot be locked with gaps — '
            'an unset horizon would read as a missed one for the next 12 '
            'months.',
        confirmLabel: null,
      );
      return;
    }
    final ok = await _dialog(
      title: 'Lock in this 12-month cycle?',
      body: 'None of the six targets can be changed, raised or lowered until '
          'the full cycle has run its 365 days.\n\nThat is deliberate: a target '
          'you can move when you fall behind measures nothing. You will be '
          'notified when the cycle closes and the next one can be set.',
      confirmLabel: 'Lock in cycle',
    );
    if (ok == true) {
      widget.onLockCycle?.call(Map<String, double>.from(d.cycle.draft));
    }
  }

  Future<void> _confirmNewCycle() async {
    final ok = await _dialog(
      title: 'Start a new 12-month cycle?',
      body: 'The closed cycle moves to Past cycles and stays read-only. The '
          'new one can be edited until you lock it in.',
      confirmLabel: 'Start new cycle',
    );
    if (ok == true) widget.onStartNewCycle?.call();
  }

  Future<bool?> _dialog({
    required String title,
    required String body,
    required String? confirmLabel,
  }) {
    final t = widget.tokens ?? MlGlass.of(context);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.panel,
        shape: RoundedRectangleBorder(
          borderRadius: MlShape.radiusLarge,
          side: BorderSide(color: t.line2),
        ),
        title: Text(
          title,
          style: context.mlText.editorialMedium.copyWith(color: t.inkHi),
        ),
        content: Text(
          body,
          style: context.mlText.bodyMedium.copyWith(
            color: t.inkMid,
            height: 1.55,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(confirmLabel == null ? 'Close' : 'Cancel',
                style: TextStyle(color: t.inkMid)),
          ),
          if (confirmLabel != null)
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: t.accent),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(confirmLabel,
                  style: TextStyle(
                      color: t.isDark ? t.bg0 : MlTokens.inkOnFill,
                      fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Cycle-complete notification
// ===========================================================================

class _CycleCompleteBanner extends StatelessWidget {
  const _CycleCompleteBanner({
    required this.tokens,
    required this.cycle,
    required this.onReview,
  });

  final MlGlass tokens;
  final MlCycle cycle;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.good.withValues(alpha: 0.13), t.good.withValues(alpha: 0.02)],
        ),
        borderRadius: MlShape.radiusMedium,
        border: Border.all(color: t.good.withValues(alpha: 0.38)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlWell(
              icon: Icons.notifications_active_outlined,
              color: t.good,
              size: 34,
              iconSize: 16,
              radius: 9),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Your 12-month cycle has closed',
                    style: context.mlText.titleSmall.copyWith(
                      color: t.inkHi,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text(
                  '${cycle.label} has run its full 365 days. You can now review '
                  'how the six horizon goals landed and set new long-term '
                  'targets for the next cycle.',
                  style: context.mlText.bodySmall.copyWith(
                    color: t.inkMid,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _FilledButton(
              tokens: t, label: 'Review & set new cycle', onTap: onReview),
        ],
      ),
    );
  }
}

// ===========================================================================
// Cycle status card
// ===========================================================================

class _CycleCard extends StatelessWidget {
  const _CycleCard({
    required this.tokens,
    required this.data,
    required this.onLock,
    required this.onStartNew,
  });

  final MlGlass tokens;
  final MlTargetsData data;
  final VoidCallback onLock;
  final VoidCallback onStartNew;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final c = data.cycle;
    final done = data.cycleComplete;

    final badge = c.isDraft
        ? _StatusBadge(
            tokens: t,
            label: 'DRAFT — NOT LOCKED',
            color: t.warn,
            icon: Icons.flag_outlined,
            dashed: true)
        : done
            ? _StatusBadge(
                tokens: t,
                label: 'CYCLE COMPLETE',
                color: t.good,
                icon: Icons.check_rounded)
            : _StatusBadge(
                tokens: t,
                label: 'LOCKED FOR ${data.daysUntilCycleReopens} MORE DAYS',
                color: t.accent2,
                icon: Icons.lock_outline_rounded);

    return MlPanel(
      tokens: t,
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, box) {
          final ring = SizedBox(
            width: 104,
            height: 104,
            child: CustomPaint(
              painter: _ProgressRingPainter(
                value: data.cycleProgress,
                track: t.inkHi.withValues(alpha: 0.12),
                fill: done ? t.good : t.accent,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${data.elapsedCycleDays}',
                        style: TextStyle(
                          fontFamily: MlGlass.mono,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          height: 1,
                          color: t.inkHi,
                        )),
                    const SizedBox(height: 4),
                    Text('OF 365 DAYS',
                        style: TextStyle(
                          fontFamily: MlGlass.sans,
                          fontSize: 8,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w600,
                          color: t.inkMid,
                        )),
                  ],
                ),
              ),
            ),
          );

          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              badge,
              const SizedBox(height: 10),
              Text(c.label,
                  style: context.mlText.editorialMedium.copyWith(color: t.inkHi)),
              const SizedBox(height: 4),
              Text(
                c.isDraft
                    ? 'Set all six horizon targets, then lock the cycle in. '
                        'After that they cannot be changed for a full 12 months.'
                    : done
                        ? 'This cycle has run its full 12 months. You can now '
                            'set the next one.'
                        : 'Targets reopen in ${data.daysUntilCycleReopens} days, '
                            'once the full 12-month cycle has run.',
                style: context.mlText.bodySmall.copyWith(
                  color: t.inkMid,
                  height: 1.5,
                ),
              ),
            ],
          );

          final action = done
              ? _FilledButton(
                  tokens: t, label: 'Start new cycle', onTap: onStartNew)
              : c.isDraft
                  ? _FilledButton(
                      tokens: t, label: 'Lock in cycle', onTap: onLock)
                  : Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: t.line2),
                        borderRadius: MlShape.radiusSmall,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_outline_rounded,
                              size: 12, color: t.inkXlo),
                          const SizedBox(width: 7),
                          Text('Locked',
                              style: context.mlText.labelSmall.copyWith(
                                color: t.inkLo,
                                fontWeight: FontWeight.w400,
                              )),
                        ],
                      ),
                    );

          if (box.maxWidth < 760) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: ring),
                const SizedBox(height: 16),
                body,
                const SizedBox(height: 16),
                Align(alignment: Alignment.centerLeft, child: action),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ring,
              const SizedBox(width: 22),
              Expanded(child: body),
              const SizedBox(width: 18),
              action,
            ],
          );
        },
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.value,
    required this.track,
    required this.fill,
  });

  final double value;
  final Color track;
  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    const th = 9.0;
    final r = (size.width - th) / 2;
    final rect = Rect.fromCircle(
        center: Offset(size.width / 2, size.height / 2), radius: r);
    canvas.drawCircle(
        rect.center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = th
          ..color = track);
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -1.5707963,
      value.clamp(0.0, 1.0) * 6.2831853,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = th
        ..strokeCap = StrokeCap.round
        ..color = fill,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter old) =>
      old.value != value || old.fill != fill;
}

// ===========================================================================
// Lock warning
// ===========================================================================

class _LockWarning extends StatelessWidget {
  const _LockWarning({
    required this.tokens,
    required this.canLock,
    required this.unset,
    required this.onLock,
  });

  final MlGlass tokens;
  final bool canLock;
  final int unset;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [t.warn.withValues(alpha: 0.11), t.warn.withValues(alpha: 0.02)],
        ),
        borderRadius: MlShape.radiusMedium,
        border: Border.all(color: t.warn.withValues(alpha: 0.34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlWell(
              icon: Icons.rule_rounded,
              color: t.warn,
              size: 34,
              iconSize: 16,
              radius: 9),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Locking is permanent for 12 months',
                    style: context.mlText.titleSmall.copyWith(
                      color: t.inkHi,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text(
                  'Once you lock this cycle, none of the six targets can be '
                  'edited, raised or lowered until the full 12-month cycle has '
                  'run. That is deliberate — a target you can move when you '
                  'fall behind measures nothing. You will be notified when the '
                  'cycle closes and the next one can be set.'
                  '${unset > 0 ? '\n\n$unset horizon${unset == 1 ? '' : 's'} still without a target.' : ''}',
                  style: context.mlText.bodySmall.copyWith(
                    color: t.inkMid,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _FilledButton(
            tokens: t,
            label: 'Lock in cycle',
            onTap: onLock,
            enabled: canLock,
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Month table (view)
// ===========================================================================

class _MonthTable extends StatelessWidget {
  const _MonthTable({
    required this.tokens,
    required this.data,
    this.onChanged,
  });

  final MlGlass tokens;
  final MlTargetsData data;
  final void Function(String monthKey, double tons)? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return MlPanel(
      tokens: t,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MlSectionHead(
            tokens: t,
            size: 18,
            title: 'All months',
            subtitle: 'Every month in one list. Closed months show a padlock '
                'and cannot be edited from anywhere on this screen.',
          ),
          const SizedBox(height: 14),
          // Four `Expanded` columns and no minimum, which on a phone is the
          // registry's disease exactly: at 412px the ATTAINMENT cell got
          // 118.8px for content needing 154.9 (bar + `117%` + a `SURPASSED`
          // badge) and the locked TARGET field got 46px for 55.2. Twenty-two
          // overflows in one screen, found 2026-08-20 by rendering the board at
          // phone width for the first time.
          //
          // `_minWidth` is what the columns actually need, so the table scrolls
          // sideways below it and lays out normally above it.
          MlWideTable(
            minWidth: _minWidth(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(flex: 24, child: _th(t, 'Month')),
                    Expanded(flex: 20, child: _th(t, 'Target')),
                    Expanded(flex: 20, child: _th(t, 'Actual')),
                    Expanded(flex: 36, child: _th(t, 'Attainment')),
                  ],
                ),
                const SizedBox(height: 8),
                Container(height: 1, color: t.line2),
                for (var i = 0; i < data.months.length; i++) ...[
                  if (i == data.currentIndex + 1) _plannedDivider(t),
                  _row(context, t, i),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The width below which the four columns stop fitting.
  ///
  /// Derived from the widest cell rather than picked: ATTAINMENT carries a
  /// progress bar, a right-aligned percentage (44px) and an outcome badge, and
  /// it is 36% of the row — so the row cannot be narrower than that cell's
  /// needs divided by its share. Scaled by the live text scaler because the
  /// console lets each admin set one (`ConsolePrefs.textScale`, and the
  /// platform's on top of it); a fixed figure would be right at 1.0 and wrong
  /// for anybody who moved the slider.
  double _minWidth(BuildContext context) {
    const attainmentCell = 212.0; // bar 56 + 10 + pct 44 + 8 + badge ~94
    const attainmentShare = 36 / 100;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return (attainmentCell / attainmentShare) * scale;
  }

  Widget _th(MlGlass t, String s) => Text(
        s.toUpperCase(),
        style: TextStyle(
          fontFamily: MlGlass.sans,
          fontSize: 9,
          letterSpacing: 1.15,
          fontWeight: FontWeight.w600,
          color: t.inkLo,
        ),
      );

  Widget _plannedDivider(MlGlass t) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 14, 0, 8),
        child: Row(
          children: [
            Text('PLANNED — EDITABLE',
                style: TextStyle(
                  fontFamily: MlGlass.sans,
                  fontSize: 9,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w600,
                  color: t.accent2,
                )),
            const SizedBox(width: 10),
            Expanded(
                child: Container(
                    height: 1, color: t.accent.withValues(alpha: 0.22))),
          ],
        ),
      );

  Widget _row(BuildContext context, MlGlass t, int i) {
    final m = data.months[i];
    final locked = data.isPast(i);
    final outcome = m.outcome;
    final color = mlOutcomeColor(t, outcome);
    final att = m.target > 0 ? m.attainment : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: i == data.currentIndex
            ? t.accent.withValues(alpha: 0.05)
            : Colors.transparent,
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 24,
            // Three unflexed children in one cell — the month, a lock and a
            // CURRENT badge — so each took its natural width from an unbounded
            // constraint (CLAUDE.md 10.4). At 860px and text scale 2.0 that is
            // 15px more than the cell has. Only visible above 1.3, which is
            // where this sweep used to stop.
            //
            // The MONTH flexes first and the badge second: a row reading
            // "August 20…  CURRENT" still tells you which month is current,
            // and one reading "August 2026  CURR…" tells you less.
            child: Row(
              children: [
                Flexible(
                  child: Text(m.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.labelMedium.copyWith(
                        color: locked ? t.inkMid : t.inkHi,
                        fontWeight: i == data.currentIndex ? FontWeight.w700 : FontWeight.w500,
                      )),
                ),
                if (locked) ...[
                  const SizedBox(width: 7),
                  Icon(Icons.lock_outline_rounded, size: 12, color: t.inkXlo),
                ],
                if (i == data.currentIndex) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text('CURRENT',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: MlGlass.sans,
                          fontSize: 8,
                          letterSpacing: 1,
                          color: t.accent2,
                        )),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            flex: 20,
            child: locked
                ? _readOnlyField(context, t, m.target)
                : Text(
                    m.target > 0 ? '${mlTons(m.target, decimals: 0)} t' : '—',
                    style: context.mlText.code(
                      color: m.target > 0 ? t.ink : t.inkLo,
                      size: 12,
                      weight: FontWeight.w400,
                    ),
                  ),
          ),
          Expanded(
            flex: 20,
            child: Text(
              m.hasActuals ? '${mlTons(m.total)} t' : '—',
              style: context.mlText.code(
                color: m.hasActuals ? t.inkHi : t.inkXlo,
                size: 12,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 36,
            child: m.hasActuals
                ? Row(
                    children: [
                      Expanded(child: _AttBar(tokens: t, outcome: outcome, attainment: att)),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 44,
                        child: Text(
                          m.target > 0 ? '${(att * 100).round()}%' : '—',
                          textAlign: TextAlign.right,
                          style: context.mlText.code(
                            color: m.target > 0 ? color : t.inkLo,
                            size: 11,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(width: 8),
                        _OutcomeBadge(tokens: t, outcome: outcome),
                      ],
                    ],
                  )
                : Text('awaiting actuals',
                    style: context.mlText.labelSmall.copyWith(
                      color: t.inkXlo,
                      fontWeight: FontWeight.w400,
                    )),
          ),
        ],
      ),
    );
  }

  Widget _readOnlyField(BuildContext context, MlGlass t, double target) => Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: t.inkHi.withValues(alpha: 0.015),
          borderRadius: MlShape.radiusSmall,
          border: Border.all(color: t.line2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, size: 11, color: t.inkXlo),
            const SizedBox(width: 7),
            Text(
              target > 0 ? '${mlTons(target, decimals: 0)} t' : 'no target',
              style: context.mlText.code(
                color: t.inkMid,
                size: 12,
                weight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
}

// ===========================================================================
// Horizon ladder (view)
// ===========================================================================

class _HorizonLadder extends StatelessWidget {
  const _HorizonLadder({required this.tokens, required this.data});

  final MlGlass tokens;
  final MlTargetsData data;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return MlPanel(
      tokens: t,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MlSectionHead(
            tokens: t,
            size: 18,
            title: 'Progress against each horizon',
            subtitle: 'Measured on cumulative tonnage from the cycle start, so '
                'progress compounds rather than resetting each period.',
          ),
          const SizedBox(height: 14),
          for (final z in kMlHorizons) ...[
            _row(context, t, z),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, MlGlass t, MlHorizon z) {
    final outcome = data.horizonOutcome(z);
    final target = data.cycle.targets[z.key] ?? 0;
    final actual = data.horizonActual(z);
    final pending = outcome == MlTargetOutcome.pending;
    final att = (target > 0 && actual != null) ? actual / target : 0.0;
    final color = mlOutcomeColor(t, outcome);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: t.inkHi.withValues(alpha: 0.015),
        borderRadius: MlShape.radiusMedium,
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(z.name,
                    style: context.mlText.titleSmall.copyWith(
                      color: t.inkHi,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 3),
                Text(z.description,
                    style: TextStyle(
                        fontFamily: MlGlass.sans,
                        fontSize: 9,
                        letterSpacing: 0.6,
                        color: t.inkLo)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 92,
            child: Text(
              target > 0 ? '${mlTons(target, decimals: 0)} t' : '—',
              style: context.mlText.code(
                color: t.inkMid,
                size: 12,
                weight: FontWeight.w400,
              ),
            ),
          ),
          SizedBox(
            width: 96,
            child: Text(
              pending ? 'not reached' : '${mlTons(actual ?? 0)} t',
              style: TextStyle(
                fontFamily: pending ? MlGlass.sans : MlGlass.mono,
                fontSize: pending ? 10.5 : 12,
                fontWeight: FontWeight.w600,
                color: pending ? t.inkLo : t.inkHi,
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                    child: _AttBar(
                        tokens: t, outcome: outcome, attainment: att)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 46,
                  child: Text(
                    pending ? '—' : '${(att * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: context.mlText.code(
                      color: color,
                      size: 11,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // A floor, not a fixed width. 104 keeps the badges aligned down the
          // ladder at normal type, but the console's text-size slider goes to
          // 1.3 and "SURPASSED" outgrows the box there — the column has to be
          // able to take the extra from the bar beside it rather than clip.
          // Covered by the width x text-scale sweep in
          // `test/widgets/targets_screen_test.dart`.
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 104),
            child: Align(
              alignment: Alignment.centerRight,
              widthFactor: 1,
              child: _OutcomeBadge(tokens: t, outcome: outcome),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Target history (record)
// ===========================================================================

class _TargetHistory extends StatelessWidget {
  const _TargetHistory({
    required this.tokens,
    required this.data,
    required this.filter,
    required this.onFilter,
  });

  final MlGlass tokens;
  final MlTargetsData data;
  final MlTargetOutcome? filter;
  final ValueChanged<MlTargetOutcome?> onFilter;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final past = <MapEntry<int, MlMonthTarget>>[
      for (var i = 0; i < data.months.length; i++)
        if (data.isPast(i)) MapEntry(i, data.months[i])
    ];
    if (past.isEmpty) return const SizedBox.shrink();

    final counts = <MlTargetOutcome, int>{};
    for (final e in past) {
      counts[e.value.outcome] = (counts[e.value.outcome] ?? 0) + 1;
    }
    final shown =
        filter == null ? past : past.where((e) => e.value.outcome == filter);

    return MlPanel(
      tokens: t,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MlSectionHead(
            tokens: t,
            size: 18,
            title: 'Target history',
            subtitle: 'Closed months, read-only. Surpassed at or above target, '
                'close within 10%, short below that.',
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _filterChip(t, null, 'ALL MONTHS', past.length, t.inkHi),
              _filterChip(t, MlTargetOutcome.surpassed, 'SURPASSED',
                  counts[MlTargetOutcome.surpassed] ?? 0, t.good),
              _filterChip(t, MlTargetOutcome.close, 'CLOSE',
                  counts[MlTargetOutcome.close] ?? 0, t.accent2),
              _filterChip(t, MlTargetOutcome.short, 'SHORT',
                  counts[MlTargetOutcome.short] ?? 0, t.bad),
            ],
          ),
          const SizedBox(height: 16),
          // Five flexed columns plus a fixed 116px badge column. At 360px the
          // attainment cell had 44.2px for a `117%` needing 54, and the bar
          // beside it had already been squeezed to nothing — so the row read as
          // a percentage with a blank space where its meter should be. Same
          // treatment as the month table above it.
          //
          // The filter chips stay OUTSIDE the scroll view: they are a control,
          // not a column, and a control that slides away from the table it
          // filters is worse than a narrow one.
          MlWideTable(
            minWidth: _minWidth(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [for (final e in shown) _row(context, t, e.value)],
            ),
          ),
        ],
      ),
    );
  }

  /// The width below which the history columns stop fitting.
  ///
  /// The badge column is a fixed 116px, so it comes off the top; the rest is
  /// governed by ATTAINMENT, which is 24 of the remaining 88 flex units and
  /// carries a bar, a gap and a right-aligned percentage. Scaled by the live
  /// text scaler, because the console has a per-admin text-size slider.
  double _minWidth(BuildContext context) {
    const badgeColumn = 116.0;
    const attainmentCell = 110.0; // bar 56 + gap 10 + pct 44
    const attainmentShare = 24 / 88;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return (attainmentCell / attainmentShare + badgeColumn) * scale;
  }

  Widget _filterChip(
      MlGlass t, MlTargetOutcome? value, String label, int count, Color color) {
    final on = filter == value;
    return MlHoverLift(
      lift: 0,
      onTap: () => onFilter(on && value != null ? null : value),
      builder: (context, hovered) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: on
              ? t.accent.withValues(alpha: 0.08)
              : t.inkHi.withValues(alpha: hovered ? 0.04 : 0.015),
          border: Border.all(
              color: on ? t.accent.withValues(alpha: 0.4) : t.line),
          borderRadius: MlShape.radiusMedium,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                  color: color, borderRadius: MlShape.radiusExtraSmall),
            ),
            const SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$count',
                    style: TextStyle(
                      fontFamily: MlGlass.mono,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      height: 1,
                      color: color,
                    )),
                const SizedBox(height: 3),
                Text(label,
                    style: context.mlText.labelSmall.copyWith(
                      color: t.inkMid,
                      letterSpacing: 0.8,
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, MlGlass t, MlMonthTarget m) {
    final outcome = m.outcome;
    final color = mlOutcomeColor(t, outcome);
    final variance = m.target > 0 ? m.total - m.target : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 18,
            // Flexible: a Row hands a non-flex child unbounded width
            // (CLAUDE.md 10.4), so this month label could not ellipsize inside
            // its own column and pushed the row over at large text sizes.
            child: Row(
              children: [
                Icon(Icons.lock_outline_rounded, size: 11, color: t.inkXlo),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(m.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.labelMedium.copyWith(color: t.ink)),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 15,
            child: Text(
              m.target > 0 ? '${mlTons(m.target, decimals: 0)} t' : '—',
              style: context.mlText.code(
                color: t.inkMid,
                size: 12,
                weight: FontWeight.w400,
              ),
            ),
          ),
          Expanded(
            flex: 15,
            child: Text('${mlTons(m.total)} t',
                style: context.mlText.code(
                  color: t.inkHi,
                  size: 12,
                  weight: FontWeight.w600,
                )),
          ),
          Expanded(
            flex: 16,
            child: Text(
              m.target > 0
                  ? '${variance >= 0 ? '+' : '−'}${mlTons(variance.abs())} t'
                  : '—',
              style: context.mlText.code(
                color: variance >= 0 ? t.good : t.bad,
                size: 12,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 24,
            child: Row(
              children: [
                Expanded(
                    child: _AttBar(
                        tokens: t,
                        outcome: outcome,
                        attainment: m.attainment)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 44,
                  child: Text(
                    m.target > 0 ? '${(m.attainment * 100).round()}%' : '—',
                    textAlign: TextAlign.right,
                    style: context.mlText.code(
                      color: color,
                      size: 11,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 116,
            child: Align(
              alignment: Alignment.centerRight,
              child: _OutcomeBadge(tokens: t, outcome: outcome),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Cycle archive (record)
// ===========================================================================

class _CycleArchive extends StatelessWidget {
  const _CycleArchive({required this.tokens, required this.cycles});

  final MlGlass tokens;
  final List<MlArchivedCycle> cycles;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return MlPanel(
      tokens: t,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          MlSectionHead(
            tokens: t,
            size: 18,
            title: 'Past cycles',
            subtitle: 'Closed cycles, read-only — what was aimed at and what '
                'landed.',
          ),
          const SizedBox(height: 14),
          if (cycles.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Text(
                'No closed cycles yet. The first will appear here once this '
                'one completes.',
                textAlign: TextAlign.center,
                style: context.mlText.bodySmall.copyWith(color: t.inkMid),
              ),
            ),
          for (final c in cycles) ...[
            _cycle(context, t, c),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _cycle(BuildContext context, MlGlass t, MlArchivedCycle c) {
    final hit = c.surpassedCount;
    final band = hit >= 4
        ? MlTargetOutcome.surpassed
        : hit >= 2
            ? MlTargetOutcome.close
            : MlTargetOutcome.short;

    return Container(
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
      decoration: BoxDecoration(
        color: t.inkHi.withValues(alpha: 0.015),
        borderRadius: MlShape.radiusMedium,
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A Wrap, not a Row with a Spacer. A Spacer collapses to zero when
          // the row is full and the children then overflow, which is what
          // happened here at text scale 2.0 — the label, the badge and the
          // read-only note together are wider than a narrow console.
          //
          // `width: double.infinity` is load-bearing: a Wrap sizes to its
          // content, so without it `spaceBetween` has no free space to
          // distribute and the note renders glued to the badge instead of at
          // the right edge (CLAUDE.md 10.4).
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(c.label,
                        style: context.mlText.titleSmall.copyWith(
                          color: t.inkHi,
                          fontWeight: FontWeight.w700,
                        )),
                    _OutcomeBadge(
                        tokens: t,
                        outcome: band,
                        overrideLabel: '$hit OF 6 SURPASSED'),
                  ],
                ),
                Text('closed cycle · read-only',
                    style: context.mlText.labelSmall.copyWith(
                      color: t.inkLo,
                      fontWeight: FontWeight.w400,
                    )),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MlGrid(
            columns: 6,
            gap: 8,
            children: kMlHorizons.map((z) {
              final tgt = c.targets[z.key] ?? 0;
              final act = c.actuals[z.key] ?? 0;
              final o = c.outcomeFor(z);
              final color = mlOutcomeColor(t, o);
              final a = tgt > 0 ? act / tgt : 0.0;
              return Container(
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
                decoration: BoxDecoration(
                  color: t.inkHi.withValues(alpha: 0.02),
                  borderRadius: MlShape.radiusSmall,
                  border: Border.all(color: t.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(z.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: MlGlass.sans,
                          fontSize: 9,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w600,
                          color: t.inkLo,
                        )),
                    const SizedBox(height: 4),
                    Text('${(a * 100).round()}%',
                        style: context.mlText.code(
                          color: color,
                          size: 12,
                          weight: FontWeight.w600,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      '${mlTons(act, decimals: 0)} / ${mlTons(tgt, decimals: 0)}',
                      style: context.mlText.code(
                        color: t.inkLo,
                        size: 10,
                        weight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: MlShape.pill,
                      child: Container(
                        height: 3,
                        color: t.inkHi.withValues(alpha: 0.08),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: a.clamp(0.0, 1.0),
                          // Stated, not inferred — see the guard
                          // `fractional-fill-declares-its-height`.
                          heightFactor: 1,
                          child: ColoredBox(color: color),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Shared bits
// ===========================================================================

/// Attainment bar that carries its band, with a tick at 100% so the reference
/// stays visible even when the fill stops well short of it.
class _AttBar extends StatelessWidget {
  const _AttBar({
    required this.tokens,
    required this.outcome,
    required this.attainment,
  });

  final MlGlass tokens;
  final MlTargetOutcome outcome;
  final double attainment;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final cap = attainment > 1.25 ? attainment : 1.25;
    final color = mlOutcomeColor(t, outcome);
    return SizedBox(
      height: 6,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: t.inkHi.withValues(alpha: 0.06),
                borderRadius: MlShape.pill,
              ),
            ),
          ),
          // `heightFactor: 1` is what makes this bar EXIST.
          //
          // A `Stack`'s non-positioned children are laid out with LOOSE
          // constraints, and a `FractionallySizedBox` that declares only a
          // `widthFactor` passes its parent's height range straight through —
          // so the inner `DecoratedBox`, which has no child, took
          // `constraints.smallest` and came out **6px wide by 0px tall**. The
          // track painted (it is `Positioned.fill`, which is tight) and the
          // 100% tick painted (a `Container` expands under loose constraints),
          // so every attainment bar in the product rendered as an empty rail
          // with a notch: the one element whose whole job is to show the
          // number was the one element missing. Measured out of
          // `screen-targets-org-type-desktop-dark.png` on 2026-08-21 — the row
          // for Sep 2025 reads 82%, and the 315px rail was one flat colour end
          // to end.
          //
          // Inherited from the shipping app, not introduced here.
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (attainment / cap).clamp(0.0, 1.0),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: outcome == MlTargetOutcome.close
                    // Hatched, so 'close' separates from its neighbours without
                    // needing a fourth colour.
                    ? LinearGradient(
                        colors: [color, color.withValues(alpha: 0.45)],
                        tileMode: TileMode.repeated,
                        begin: Alignment.topLeft,
                        end: const Alignment(-0.85, 1),
                      )
                    : LinearGradient(
                        colors: [color.withValues(alpha: 0.65), color]),
                borderRadius: MlShape.pill,
              ),
            ),
          ),
          Align(
            alignment: Alignment((1 / cap) * 2 - 1, 0),
            child: Container(width: 1, color: t.inkHi.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }
}

class _OutcomeBadge extends StatelessWidget {
  const _OutcomeBadge({
    required this.tokens,
    required this.outcome,
    this.overrideLabel,
  });

  final MlGlass tokens;
  final MlTargetOutcome outcome;
  final String? overrideLabel;

  IconData get _icon {
    switch (outcome) {
      case MlTargetOutcome.surpassed:
        return Icons.check_rounded;
      case MlTargetOutcome.close:
        return Icons.adjust_rounded;
      case MlTargetOutcome.short:
        return Icons.south_rounded;
      case MlTargetOutcome.pending:
        return Icons.schedule_rounded;
      case MlTargetOutcome.none:
        return Icons.remove_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final color = mlOutcomeColor(t, outcome);
    final dashed = outcome == MlTargetOutcome.close ||
        outcome == MlTargetOutcome.pending;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        border: Border.all(
          color: color.withValues(alpha: dashed ? 0.34 : 0.38),
        ),
        borderRadius: MlShape.radiusSmall,
      ),
      // Flexible, because a Row hands a non-flex child UNBOUNDED width
      // (CLAUDE.md 10.4) and its own ellipsis then never engages. Only
      // visible above text scale 1.3, which is where these sweeps used to
      // stop -- the shells compose the in-app slider with the platform's
      // and cap at kMaxEffectiveTextScale = 2.0, so everything between the
      // two was a size a real user could reach and nothing had rendered.
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 11, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              overrideLabel ?? outcome.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: MlGlass.sans,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.tokens,
    required this.label,
    required this.color,
    required this.icon,
    this.dashed = false,
  });

  final MlGlass tokens;
  final String label;
  final Color color;
  final IconData icon;
  final bool dashed;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          border: Border.all(color: color.withValues(alpha: 0.34)),
          borderRadius: MlShape.radiusSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: context.mlText.labelSmall.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                )),
          ],
        ),
      );
}

class _FilledButton extends StatelessWidget {
  const _FilledButton({
    required this.tokens,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final MlGlass tokens;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return MlHoverLift(
      lift: 0,
      onTap: enabled ? onTap : null,
      builder: (context, hovered) => Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: enabled
              ? LinearGradient(colors: [t.accent2, t.accent])
              : null,
          color: enabled ? null : t.inkHi.withValues(alpha: 0.08),
          borderRadius: MlShape.radiusMedium,
        ),
        child: Text(
          label,
          style: context.mlText.labelMedium.copyWith(
            color: enabled ? (t.isDark ? t.bg0 : MlTokens.inkOnFill) : t.inkXlo,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
