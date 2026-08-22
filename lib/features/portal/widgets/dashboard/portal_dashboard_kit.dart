// ============================================================================
// The portal dashboard band vocabulary (P7-20)
// ----------------------------------------------------------------------------
// The three org dashboards were the same page three times — a title, a
// copy-pasted `_wrap` helper, a 4-up stat row and a feature row — with no
// section headers, no period selector, no action queue and no deep links. They
// are rebuilt on the console's structure, and this file is the shared
// vocabulary so "rebuilt on the same structure" is enforced by the types
// rather than by three people remembering.
//
// Two rules the widgets here exist to hold:
//
//   1. **Nothing renders a number it does not have.** A [PortalKpi] takes a
//      `String?` value: null means "not available", and the tile renders a
//      muted dash with a reason instead of `0`. Reporting an unread count, an
//      unloaded query or a missing target as zero is the fault that put a
//      hardcoded 28,000 t target on the transporters chart and rendered every
//      colleague "offline" on the Employee Register — the same mistake twice
//      already, in two unrelated places.
//   2. **Every tile goes somewhere.** `route` is required on the KPI and queue
//      models. A dashboard tile that states a number and cannot show its
//      workings is decoration, and PLAN.md §4.4 rules decoration out.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/super_admin/widgets/super_admin_dashboard_widgets.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// The console's chart tokens, resolved for the portal's active theme so the
/// same charts can render on a light page.
MlGlass portalGlass(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
    ? MlGlass.dark
    : MlGlass.light;

/// The rolling window a dashboard is being read over.
enum PortalPeriod {
  day('Today', 1),
  week('7 days', 7),
  month('30 days', 30),
  year('12 months', 365);

  const PortalPeriod(this.label, this.days);
  final String label;
  final int days;

  /// What a delta on this window is measured against, short enough to sit in
  /// the corner of a stat tile: `1d`, `7d`, `30d`, `12m`.
  ///
  /// The badge used to say `24h` for all four, welded into the widget. Every
  /// portal delta is computed against the previous window of the SELECTED
  /// period (`priorFrom = from - period.days`), so on the live buyer dashboard
  /// a seven-day movement was captioned `24h`, and on `12 months` a year would
  /// have been.
  String get deltaWindow => switch (this) {
    PortalPeriod.day => '1d',
    PortalPeriod.week => '7d',
    PortalPeriod.month => '30d',
    PortalPeriod.year => '12m',
  };

  /// The start of this window, measured from midnight at the mine.
  ///
  /// [now] must already be a South African wall clock — pass [MlTime.now] or
  /// [MlTime.sast] output. It used to be `DateTime.now()`, so every dashboard
  /// figure in the product depended on how the reader's device was configured.
  DateTime startFrom(DateTime now) {
    final midnight = MlTime.startOfDay(now);
    return midnight.subtract(Duration(days: days - 1));
  }
}

/// One KPI: a real figure, an optional period-over-period delta, and the screen
/// that shows its workings.
///
/// [value] is `null` when there is no figure to show. It renders as a dash,
/// never as zero — a real zero is `'0'`.
///
/// ## "Still reading" is not "could not read", and this tile used to say it was
///
/// That null had TWO causes and one caption. A dashboard passes
/// `feed.valueOrNull`, which collapses a pending read and a failed one into the
/// same null, and the tile printed [emptyReason] over it — wording every
/// caller had written for the failure: *"earnings feed unavailable"*,
/// *"stockpiles unavailable"*, *"delivery values unavailable"*.
///
/// So for the second or two a feed takes to arrive, the dashboard told its
/// reader the feed was broken. Driven in a browser as `roadhaul.admin` on
/// 2026-08-22, a clean sign-in showed FOUR KPIs and three panels reporting
/// failure, and then filled in by itself with no reload and no retry — 235 t,
/// R184,611, 2 trucks on route. Nothing had gone wrong at any point; both RPCs
/// returned 200 with real rows, which is what made it worth chasing.
///
/// The same fault was found on the mine's stockpile band on 2026-08-21 and
/// fixed there, one card at a time — the note in
/// `mine_supplier_portal_dashboard_screen.dart` still says "the comment below
/// already named the trap; this line was the one still in it". It was closed
/// for one card and left open for the KPI band of all three dashboards, which
/// is what a one-card fix does to a class of fault.
///
/// [loading] is the missing half. When it is true the tile says it is still
/// reading; only when it is false does [emptyReason] get to speak. A caller
/// that cannot distinguish leaves it false and keeps the old behaviour, which
/// is why `dashboards_do_not_cry_wolf_test.dart` checks the DASHBOARDS rather
/// than this class.
class PortalKpi {
  const PortalKpi({
    required this.label,
    required this.value,
    required this.sublabel,
    required this.icon,
    required this.tone,
    required this.route,
    this.unit,
    this.delta,
    this.deltaGoodWhenUp = true,
    this.deltaPrefix,
    this.emptyReason = 'no data yet',
    this.loading = false,
  });

  final String label;
  final String? value;
  final String? unit;
  final String sublabel;
  final IconData icon;
  final MlTone tone;

  /// Where this number comes from. Tapping the tile opens it.
  final String route;

  /// Change against the previous window of the same length, already computed.
  /// `null` draws no badge — an unknown delta is not a flat one.
  final double? delta;
  final bool deltaGoodWhenUp;

  /// What [delta] is denominated in, written BEFORE the digits and after the
  /// sign: `R` gives `−R6,351`.
  ///
  /// The money tiles had none, so the buyer's Payable card carried a bare
  /// `−6351` beside a value of `R49,710`, and the transporter's Revenue card a
  /// bare `−956566` beside `R156,567`. A five-figure number with no symbol,
  /// on a card whose only other figure is Rand, reads as tons or as a
  /// percentage. This file already carries a long note about `R` being a
  /// prefix and not a unit, written when the same fault was found on the VALUE
  /// — the delta was the half that got missed.
  final String? deltaPrefix;
  final String emptyReason;

  /// Whether the feed behind [value] is still being read.
  ///
  /// Suppresses [emptyReason] in favour of [kPortalKpiLoadingReason]. See the
  /// class doc: a pending read and a failed one arrive at this tile as the
  /// same null, and only the caller can tell them apart.
  final bool loading;
}

/// What a KPI says while its feed is still in flight.
///
/// The same word the action queue already uses for the same state
/// (`PortalQueueItem.loading` renders "Checking…"), so a dashboard does not
/// describe one pending read two ways on one screen.
const String kPortalKpiLoadingReason = 'checking…';

/// The panel-sized counterpart of [kPortalKpiLoadingReason].
///
/// A whole section whose feed has not answered yet must not print its failure
/// card either — that is the same fault as the KPI's, one size up, and on the
/// transporter dashboard it filled three panels at once on every sign-in.
///
/// [what] names the feed in the reader's words, lower case: "earnings",
/// "fleet status", "stockpile balances".
MlEmptyState portalFeedPending(String what) => MlEmptyState(
  icon: Icons.hourglass_bottom_rounded,
  title: 'Reading $what…',
  message: 'This fills in as soon as the feed answers.',
);

/// The KPI band — 4-up on desktop, 2-up on tablet, stacked on a phone.
class PortalKpiRow extends StatelessWidget {
  const PortalKpiRow({super.key, required this.kpis, required this.period});

  final List<PortalKpi> kpis;

  /// The window every delta in this row is measured against. Required, because
  /// the badge used to assert a hardcoded `24h` whatever the reader had
  /// selected, and a caption nobody has to supply is a caption nobody keeps
  /// true.
  final PortalPeriod period;

  /// `+1,204` · `−R6,351` · `−35`.
  ///
  /// Thousands are grouped. `−956566` was a real badge on the transporter
  /// dashboard, sitting beside a value of `R156,567` which the same screen
  /// groups — so the two figures on one card were written in two different
  /// notations, and the ungrouped one is the harder to read by far.
  ///
  /// The sign is U+2212 MINUS SIGN, matching the figure style elsewhere; the
  /// arrow in `_Delta` keys off it.
  static String formatDelta(double d, {String? prefix}) {
    final a = d.abs();
    final n = a >= 100
        ? NumberFormat.decimalPattern('en_ZA').format(a.round())
        : a.toStringAsFixed(a >= 10 ? 0 : 1);
    return '${d >= 0 ? '+' : '−'}${prefix ?? ''}$n';
  }

  static const _gap = 14.0;

  Widget _tile(BuildContext context, PortalKpi k, Brightness brightness) {
    final tone = k.tone.colors(brightness);
    final d = k.delta;
    final hasDelta = d != null && d != 0;
    return SaStatTile(
      value: k.value ?? '—',
      unit: k.value == null ? null : k.unit,
      label: k.label,
      sublabel: k.value != null
          ? k.sublabel
          // A feed that has not answered yet has not failed. See the note on
          // [PortalKpi.loading].
          : (k.loading ? kPortalKpiLoadingReason : k.emptyReason),
      icon: k.icon,
      tint: tone.fg,
      iconFg: tone.fg,
      delta: hasDelta ? formatDelta(d, prefix: k.deltaPrefix) : null,
      // Colour answers "is this movement welcome?"; the ARROW is derived from
      // the sign inside `_Delta` and is no longer this decision's business.
      // While it was, an unwelcome fall rendered `▲ −35`.
      deltaTone: !hasDelta
          ? SaDeltaTone.flat
          : (d > 0) == k.deltaGoodWhenUp
          ? SaDeltaTone.good
          : SaDeltaTone.warn,
      deltaPeriod: hasDelta ? period.deltaWindow : null,
      onTap: () => context.go(k.route),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 1100 ? 4 : (c.maxWidth >= 620 ? 2 : 1);

        // Rows of equal-height tiles, each bounded by `IntrinsicHeight` — the
        // console's own arrangement, and not optional here. `SaStatTile` paints
        // its 3px accent as a `CrossAxisAlignment.stretch` sibling, so an
        // unbounded parent (an `MlGrid`, which is a `Wrap`) hands it
        // `h=Infinity` and it throws "BoxConstraints forces an infinite
        // height" — CLAUDE.md §10.4, third bullet. It also makes the tiles in
        // a row match, which is what the design wants anyway.
        final rows = <Widget>[];
        for (var i = 0; i < kpis.length; i += cols) {
          final slice = kpis.skip(i).take(cols).toList();
          rows.add(
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var j = 0; j < cols; j++) ...[
                    if (j > 0) const SizedBox(width: _gap),
                    Expanded(
                      child: j < slice.length
                          ? _tile(context, slice[j], brightness)
                          // Keeps the last row's tiles the same width as the
                          // rows above rather than stretching to fill.
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: _gap),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

/// One row of the action queue: work this org owes, and where to go and do it.
/// Whether an async read has produced nothing to show *yet*, as distinct from
/// having produced nothing.
extension PortalAsyncFirstLoad<T> on AsyncValue<T> {
  /// True only while there is still nothing to show.
  ///
  /// Deliberately not plain `isLoading`: Riverpod reports a **background
  /// refresh** as loading while the previous value is still held, and these
  /// dashboards are realtime-refreshed. Using `isLoading` alone would blank
  /// every queue count to '…' on each tick, which is a flicker rather than a
  /// fact.
  bool get isFirstLoad => isLoading && !hasValue;
}

class PortalQueueItem {
  const PortalQueueItem({
    required this.label,
    required this.count,
    required this.route,
    required this.icon,
    required this.tone,
    required this.clearedMessage,
    this.loading = false,
  });

  final String label;

  /// `null` when the count is not known. Zero means genuinely nothing waiting
  /// and renders [clearedMessage].
  final int? count;

  /// True while the underlying query is still in flight.
  ///
  /// [count] used to carry both facts: its own doc said "null while the
  /// underlying queue is loading **or has failed**", and the row rendered both
  /// as *"Could not read this queue"*. So every action queue accused itself of
  /// being broken for the second or two before its data arrived — caught on the
  /// mine dashboard, where a screenshot taken mid-load showed exactly that
  /// against a query that then returned 200.
  ///
  /// Not-yet and cannot-ever are different facts. A row that says the second
  /// when it means the first teaches people to ignore it, which is expensive on
  /// the one row that means it.
  final bool loading;
  final String route;
  final IconData icon;
  final MlTone tone;

  /// What to say at zero. "0 arrivals to check in" reads as a fault; "No trucks
  /// waiting at the gate" reads as the good news it is.
  final String clearedMessage;
}

/// The action queue — everything waiting on this org, in one place, each row a
/// link to the screen that clears it.
class PortalActionQueue extends StatelessWidget {
  const PortalActionQueue({super.key, required this.items});

  final List<PortalQueueItem> items;

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final outstanding = items.where((i) => (i.count ?? 0) > 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaSectionHeader(
          title: 'Action queue',
          subtitle: 'Work waiting on your team right now.',
          meta: outstanding == 0
              ? 'All clear'
              : '$outstanding queue${outstanding == 1 ? '' : 's'} with work',
        ),
        const SizedBox(height: 12),
        MlCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: s.divider),
                _QueueRow(item: items[i], brightness: brightness),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.item, required this.brightness});

  final PortalQueueItem item;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    final n = item.count;
    final clear = n == 0;
    final tone = (clear ? MlTone.neutral : item.tone).colors(brightness);

    return InkWell(
      onTap: () => context.go(item.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            MlIconWell(
              icon: clear ? Icons.check_rounded : item.icon,
              tone: clear ? MlTone.done : item.tone,
              size: 36,
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.titleSmall.copyWith(
                      color: s.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n == null
                        ? (item.loading
                              ? 'Checking…'
                              : 'Could not read this queue')
                        : clear
                        ? item.clearedMessage
                        : '$n waiting',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.labelSmall.copyWith(
                      color: s.textMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // A dash, not a zero: a queue that failed to load has not been
            // cleared. An ellipsis while it is still being read, for the same
            // reason — a dash is a result and loading is not one yet.
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 34),
              child: Align(
                widthFactor: 1,
                child: Text(
                  n == null ? (item.loading ? '…' : '—') : '$n',
                  style: context.mlText.code(
                    color: clear || n == null ? s.textFaint : tone.fg,
                    size: 17,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 19, color: s.textFaint),
          ],
        ),
      ),
    );
  }
}

/// A dashboard band: console section header, an optional `View →`, and content.
class PortalDashboardSection extends StatelessWidget {
  const PortalDashboardSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.meta,
    this.viewRoute,
    this.viewLabel = 'View',
  });

  final String title;
  final String subtitle;
  final String? meta;
  final String? viewRoute;
  final String viewLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = viewRoute;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SaSectionHeader(
          title: title,
          subtitle: subtitle,
          meta: meta,
          action: route == null
              ? null
              : TextButton(
                  onPressed: () => context.go(route),
                  child: Text('$viewLabel →'),
                ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

/// The period selector. Sits with the page title, not inside a band, because it
/// scopes the whole page.
class PortalPeriodSelector extends StatelessWidget {
  const PortalPeriodSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.options = PortalPeriod.values,
  });

  final PortalPeriod value;
  final ValueChanged<PortalPeriod> onChanged;
  final List<PortalPeriod> options;

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final accent = MlTone.accent.colors(brightness);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: s.surfaceSunken,
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        border: Border.all(color: s.borderCard),
      ),
      child: Wrap(
        spacing: 2,
        children: [
          for (final p in options)
            // A `Material` of its own, because an `InkWell` needs one and this
            // one did not have it.
            //
            // Every render of every dashboard logged *"No Material widget
            // found. _InkResponseStateWidget widgets require a Material widget
            // ancestor"* — 132 times in one test run, all from this line, and
            // no test failed because the assertion is thrown while BUILDING
            // and the framework carries on. What it costs in the running app
            // is the tap feedback: the period pills are the most-tapped
            // control on all three dashboards and they respond with no ripple
            // at all.
            //
            // `MaterialType.transparency` paints nothing, so the pills look
            // exactly as they did; it only gives the ink somewhere to land. A
            // component in a shared kit should not depend on an ancestor it
            // does not control — which is precisely how this survived: it
            // works under a `Scaffold` and not under a plain container.
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => onChanged(p),
                borderRadius: BorderRadius.circular(MlTokens.rSm),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: p == value ? accent.bg : Colors.transparent,
                    borderRadius: BorderRadius.circular(MlTokens.rSm),
                  ),
                  child: Text(
                    p.label,
                    style: context.mlText.labelMedium.copyWith(
                      color: p == value ? accent.fg : s.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One vehicle on the live strip.
class PortalLiveTruck {
  const PortalLiveTruck({
    required this.registration,
    required this.status,
    required this.tone,
    this.detail,
    this.route,
  });

  final String registration;
  final String status;
  final MlTone tone;

  /// ETA, stage or destination — whatever is genuinely known. Never invented:
  /// a truck with no computable ETA shows its stage instead of a guess.
  final String? detail;
  final String? route;
}

/// The live strip — what is moving, right now.
class PortalLiveStrip extends StatelessWidget {
  const PortalLiveStrip({
    super.key,
    required this.trucks,
    required this.emptyMessage,
  });

  final List<PortalLiveTruck> trucks;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;

    if (trucks.isEmpty) {
      return MlCard(
        child: MlEmptyState(
          icon: Icons.local_shipping_outlined,
          title: 'Nothing on the move',
          message: emptyMessage,
        ),
      );
    }

    return MlCard(
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (final t in trucks)
            Builder(
              builder: (context) {
                final tone = t.tone.colors(brightness);
                final chip = Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: tone.bg,
                    borderRadius: BorderRadius.circular(MlTokens.rMd),
                    border: Border.all(color: tone.fg.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.registration,
                        style: context.mlText.code(
                          color: s.textStrong,
                          size: 14,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        t.detail == null
                            ? t.status
                            : '${t.status} · ${t.detail}',
                        style: context.mlText.labelSmall.copyWith(
                          color: tone.fg,
                        ),
                      ),
                    ],
                  ),
                );
                final route = t.route;
                if (route == null) return chip;
                return InkWell(
                  onTap: () => context.go(route),
                  borderRadius: BorderRadius.circular(MlTokens.rMd),
                  child: chip,
                );
              },
            ),
        ],
      ),
    );
  }
}

/// The page title band: heading, blurb, period selector and any page actions.
class PortalDashboardHeader extends StatelessWidget {
  const PortalDashboardHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.period,
    required this.onPeriodChanged,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final PortalPeriod period;
  final ValueChanged<PortalPeriod> onPeriodChanged;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          // §3: the display face carries section titles as well as numerals.
          // This is the three portal dashboards' page title — the last one
          // still drawing through the sans text theme.
          style: MlType.figure(
            color: MlSemantic.of(context).textStrong,
            size: MlTokens.fsH1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: s.textMuted),
        ),
      ],
    );

    final controls = Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        PortalPeriodSelector(value: period, onChanged: onPeriodChanged),
        ...actions,
      ],
    );

    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 820) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [heading, const SizedBox(height: 14), controls],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: heading),
            const SizedBox(width: 16),
            // Never an unflexed `Wrap` in a `Row` (CLAUDE.md §10.4).
            Flexible(child: controls),
          ],
        );
      },
    );
  }
}
