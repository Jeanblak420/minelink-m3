import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/features/super_admin/data/models/company_monthly_ops_stats.dart';
import 'package:flutter_application_1/features/super_admin/data/models/target_scope.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/providers/targets_provider.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart'
    show mlThousands;
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/overview_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/transporters_overview_body.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Transporters overview — the layout from the 2026-08-09 "Replacing old views
/// and screens" drop, fed from live data instead of the drop's sample dataset.
///
/// Mounted at `/super-admin/insights/transporter` only; buyer and mine/supplier
/// keep the previous layout until their own versions land.
///
/// Every figure on screen is derived from [monthlyInsightsBundleProvider] (the
/// per-company monthly RPC) and [rawReconRowsProvider] (weighbridge rows).
/// Where the drop showed a metric this system has no data for — on-time %,
/// route reliability, an August forecast, "anomalies" — the slot was retargeted
/// to something real rather than filled with a plausible number. In a live
/// admin console a fabricated tonnage is worse than a blank; see
/// [TransportersOverviewMapper] for each substitution.
class TransportersOverviewV2Screen extends ConsumerWidget {
  const TransportersOverviewV2Screen({super.key});

  /// Transporter targets are an org-type commitment, so this screen reads the
  /// same scope `/super-admin/targets/org-type/transporter` writes.
  static const TargetScope _targetScope = TargetScope.orgType('transporter');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(monthlyInsightsBundleProvider('transporter'));
    final rows = ref.watch(rawReconRowsProvider(null)).valueOrNull ??
        const <RawReconRow>[];

    // This month's transporter target, from the same store the targets screen
    // writes to — so the dashed line here and the dial there are one number.
    // Null until somebody sets one, and null draws no line and no caption:
    // a target nobody chose must not look like a target somebody did.
    final targets = ref.watch(targetsProvider(_targetScope)).valueOrNull;
    final monthTarget = targets == null || targets.months.isEmpty
        ? null
        : targets
            .months[targets.currentIndex.clamp(0, targets.months.length - 1)]
            .target;

    return bundleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Error(
        message: friendlyError(e),
        onRetry: () =>
            ref.invalidate(monthlyInsightsBundleProvider('transporter')),
      ),
      data: (bundle) {
        final data = TransportersOverviewMapper.build(
          bundle: bundle,
          rows: rows,
          // Zero is "not set" in the targets store, and must stay
          // indistinguishable from absent here rather than becoming a line
          // at zero.
          targetTons:
              (monthTarget != null && monthTarget > 0) ? monthTarget : null,
        );
        return TransportersOverviewBody(
          data: data,
          // "Open workspace" opens that transporter's read-only company
          // mirror — the same destination the previous layout used.
          onOpenWorkspace: (row) => context.go(
            '/super-admin/insights/transporter/company/${row.id}',
          ),
          // `push`, not `go`: the board is a drill-down, so the console's back
          // button should return to this overview rather than to whatever came
          // before it.
          onOpenLeaderboard: () =>
              context.push('/super-admin/insights/transporter/leaderboard'),
        );
      },
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = MlOv.of(context);
    return Container(
      color: t.canvas,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 34, color: t.bad),
          const SizedBox(height: 12),
          Text(
            "Couldn't load transporter insights",
            style: t.s(size: 16, weight: FontWeight.w700, color: t.inkHi),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: t.s(size: 12, color: t.inkMid),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ===========================================================================
// Mapper — the only place raw data becomes screen figures
// ===========================================================================

/// Maps the live monthly bundle + weighbridge rows onto [OverviewData].
///
/// Kept free of Flutter context so it can be unit-tested without pumping a
/// widget — see `test/widgets/transporters_overview_v2_test.dart`.
///
/// **Substitutions made against the drop's dataset**, each because the metric
/// it showed has no source in this platform:
///
/// | Drop | Here | Why |
/// |---|---|---|
/// | `Forecast Aug 42,180 t +8.4%` | Trucks active, of fleet on file | no forecasting model exists |
/// | `Reliability 92%` | Waybills closed % | no scheduled-vs-actual data |
/// | `On-time 96%` meter | Waybills closed % | same |
/// | `Route reliability`, `Anomalies`, `Reviews needed`, `Routes rested` | turnaround, transporters, loads, variances, missing PODs, fleet | those four have no table behind them |
/// | `Target 28.0k` | `monthly_targets` at org-type scope, or nothing | the drop's line and caption disagreed and neither was stored |
abstract final class TransportersOverviewMapper {
  /// The drop's donut order: cyan · violet · pink · slate · dark slate.
  static const List<OvTone> _sliceTones = [
    OvTone.accent,
    OvTone.violet,
    OvTone.pink,
    OvTone.slate,
    OvTone.slateDark,
  ];

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  /// Weighbridge rows attributed to a transporter.
  static List<RawReconRow> _transporterRows(List<RawReconRow> rows) =>
      rows.where((r) => (r.transporterName ?? '').isNotEmpty).toList();

  /// Daily net-mass totals across [month], one entry per elapsed day.
  ///
  /// [now] decides how much of the current month has elapsed — it is passed in
  /// rather than read from the clock so the series always describes the period
  /// the rest of the screen is reporting on.
  static List<double> _dailyTons(
    List<RawReconRow> rows,
    DateTime month, {
    required DateTime now,
    int? days,
    String? company,
  }) {
    final last = days ??
        (_sameMonth(month, now)
            ? now.day
            : DateTime(month.year, month.month + 1, 0).day);
    final out = List<double>.filled(last, 0);
    for (final r in rows) {
      if (!_sameMonth(r.tripDate, month)) continue;
      if (company != null && r.transporterName != company) continue;
      final i = r.tripDate.day - 1;
      if (i >= 0 && i < last) out[i] += r.netMass ?? 0;
    }
    return out;
  }

  /// Net-mass totals for the last [count] calendar months, oldest first.
  static List<double> _monthlyTons(
    List<RawReconRow> rows,
    int count, {
    required DateTime now,
  }) =>
      List<double>.generate(count, (i) {
        final m = DateTime(now.year, now.month - (count - 1 - i));
        return rows
            .where((r) => _sameMonth(r.tripDate, m))
            .fold<double>(0, (s, r) => s + (r.netMass ?? 0));
      });

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'[\s_-]+')).where((w) => w.isNotEmpty);
    if (parts.isEmpty) return '??';
    return parts.take(2).map((w) => w[0]).join().toUpperCase();
  }

  static String _ago(DateTime from, DateTime now) {
    final d = now.difference(from);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  /// Thousands-grouped with exactly one decimal, per the drop's formatting
  /// rule: format once here so no widget can drift from it.
  static String _dec1(double v) {
    final scaled = (v * 10).round();
    final whole = scaled ~/ 10;
    final frac = (scaled % 10).abs();
    return '${mlThousands(whole)}.$frac';
  }

  static String _tons(double v) => '${_dec1(v)} t';

  static String _pct1(double v) => '${(v * 10).round() / 10}%';

  /// The drop's chart mapping (README §7): 10% headroom top, 12% bottom, with
  /// zero pinned near the floor so the area reads as a quantity.
  ///
  /// Both series and the target rule go through this with ONE shared [max], so
  /// what the eye compares is genuinely comparable.
  static List<double> _normalise(List<double> values, double max) {
    if (max <= 0) return List<double>.filled(values.length, 0.9);
    return [
      for (final v in values) (1 - (v / max) * 0.78 - 0.10).clamp(0.0, 1.0),
    ];
  }

  static OverviewData build({
    required MonthlyInsightsBundle bundle,
    required List<RawReconRow> rows,
    double? targetTons,
    DateTime? now,
  }) {
    final today = now ?? MlTime.now();
    final thisMonth = DateTime(today.year, today.month);
    final lastMonth = DateTime(today.year, today.month - 1);
    final monthName = _months[today.month - 1];
    final periodLabel = '$monthName ${today.year} · MTD';
    final tRows = _transporterRows(rows);
    final monthRows =
        tRows.where((r) => _sameMonth(r.tripDate, thisMonth)).toList();

    // ---- series -----------------------------------------------------------
    final currentDaily = _dailyTons(tRows, thisMonth, now: today);
    // NOTE: the prior month is its whole self, not its first N days. That is
    // the comparison the previous cut of this screen shipped and its numbers
    // are quoted elsewhere; changing the basis is a separate decision.
    final previousDaily = _dailyTons(tRows, lastMonth, now: today);
    final monthlyTrend = _monthlyTons(tRows, 6, now: today);

    final currentTotal = currentDaily.fold<double>(0, (s, v) => s + v);
    final previousTotal = previousDaily.fold<double>(0, (s, v) => s + v);

    // Headline tonnage comes from the RPC (authoritative for the month); the
    // deltas come from recon rows, the only basis with a previous month to
    // compare against. Null when there is nothing to compare — better a
    // missing pill than an invented one.
    final tons = bundle.aggregate.tonsMoved;
    final hasPrev = previousTotal > 0;
    final deltaPct =
        hasPrev ? (currentTotal - previousTotal) / previousTotal * 100 : null;
    final deltaTons = hasPrev ? currentTotal - previousTotal : null;

    double? peak;
    int? peakDay;
    for (var i = 0; i < currentDaily.length; i++) {
      if (peak == null || currentDaily[i] > peak) {
        peak = currentDaily[i];
        peakDay = i + 1;
      }
    }
    if (peak == 0) {
      peak = null;
      peakDay = null;
    }
    final elapsed = currentDaily.length;
    final avgPerDay = elapsed > 0 ? currentTotal / elapsed : null;

    final companies = [...bundle.companies]
      ..sort((a, b) => b.tonsMoved.compareTo(a.tonsMoved));
    final trips = companies.fold<int>(0, (s, c) => s + c.trips);
    final loads = companies.fold<int>(0, (s, c) => s + c.loadsCount);
    final wbDone = bundle.aggregate.completedWaybills;
    final wbOpen = bundle.aggregate.pendingWaybills;
    final wbTotal = wbDone + wbOpen;
    final fleetTotal = bundle.aggregate.fleetVehiclesTotal;

    // ---- fleet utilisation: trucks that actually moved / fleet on file ----
    final activeTrucks = <String>{};
    final trucksByCompany = <String, Set<String>>{};
    for (final r in monthRows) {
      final reg = r.truckReg;
      if (reg == null || reg.isEmpty) continue;
      activeTrucks.add(reg);
      trucksByCompany
          .putIfAbsent(r.transporterName!, () => <String>{})
          .add(reg);
    }
    final utilisedPct = fleetTotal > 0
        ? ((activeTrucks.length / fleetTotal) * 100).round().clamp(0, 100)
        : 0;

    // ---- the flagship chart ------------------------------------------------
    // The stored target is a MONTH of tonnage; this plot is DAILY tonnage. The
    // drop drew the month's figure straight onto the daily axis and captioned
    // it "Target 28.0k" — on a series topping out near 1,400 t that rule pins
    // itself to the ceiling and flattens every real day into the floor. What
    // belongs on a daily axis is the daily pace the month's target implies, so
    // that is what is drawn, and the caption says `t/day` so it cannot be read
    // as anything else.
    final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
    final targetPace = targetTons == null ? null : targetTons / daysInMonth;

    final chartMax = [
      ...currentDaily,
      ...previousDaily,
      // An absent target must not widen the scale; a real one must, or its
      // own rule could be drawn outside the plot box.
      if (targetPace != null) targetPace,
    ].fold<double>(0, (a, b) => b > a ? b : a);

    final series = _normalise(currentDaily, chartMax);
    final compare = _normalise(previousDaily, chartMax);
    final targetY = targetPace == null || chartMax <= 0
        ? null
        : _normalise([targetPace], chartMax).single;

    final markers = <int>{
      for (var i = 0; i < currentDaily.length; i += 3) i,
      if (currentDaily.isNotEmpty) currentDaily.length - 1,
    }.toList()
      ..sort();

    final axis = <MapEntry<double, String>>[
      for (final day in const [1, 5, 9, 13, 17])
        if (day < elapsed)
          MapEntry(
            (day - 1) / (elapsed - 1),
            day.toString().padLeft(2, '0'),
          ),
      if (elapsed > 1) const MapEntry(1.0, 'Today'),
    ];

    // ---- per-company cards -------------------------------------------------
    final transporters = <TransporterRow>[];
    for (var i = 0; i < companies.length && i < 6; i++) {
      final c = companies[i];
      final lastSeen = _lastActive(tRows, c.companyName);
      final closed = c.completedWaybills + c.pendingWaybills;
      final util = c.fleetVehicles > 0
          ? (((trucksByCompany[c.companyName]?.length ?? 0) / c.fleetVehicles) *
                  100)
              .round()
              .clamp(0, 100)
          : 0;

      // PoD coverage is real: completed trips this month that carry a photo.
      final done =
          monthRows.where((r) => r.transporterName == c.companyName && r.tripStatus == 'completed');
      final withPod = done.where((r) => r.podPhotoPath != null).length;
      final podPct = done.isEmpty ? null : (withPod / done.length * 100).round();

      transporters.add(
        TransporterRow(
          id: c.companyId,
          code: _initials(c.companyName),
          name: c.companyName,
          badges: [
            if (i == 0 && c.tonsMoved > 0)
              const OvBadge('Top volume', OvTone.accent)
            else if (c.trips > 0)
              const OvBadge('Active', OvTone.good)
            else
              const OvBadge('Idle', OvTone.warn),
            if (podPct != null)
              OvBadge(
                '$podPct% PoD',
                podPct >= 95
                    ? OvTone.good
                    : podPct >= 85
                        ? OvTone.warn
                        : OvTone.bad,
              ),
          ],
          employees: c.employees,
          drivers: c.drivers,
          fleet: c.fleetVehicles,
          routes: c.routesDistinct,
          lastActive: lastSeen == null ? 'never' : _ago(lastSeen, today),
          tempo: _dailyTons(tRows, thisMonth,
              now: today, days: 15, company: c.companyName),
          trips: '${c.trips}',
          tons: _dec1(c.tonsMoved),
          tonsValue: c.tonsMoved,
          waybillsDone: '${c.completedWaybills}',
          waybillsOpen: c.pendingWaybills,
          meters: [
            OvMeterSpec('Utilisation', util),
            // Not "on-time" — no scheduled-vs-actual data exists to compute
            // that, so the second meter reports waybill close-out instead.
            OvMeterSpec(
              'Waybills closed',
              closed > 0 ? (c.completedWaybills / closed * 100).round() : 0,
            ),
          ],
        ),
      );
    }

    // ---- donut: fleet split across companies ------------------------------
    final byFleet = [...bundle.companies]
      ..sort((a, b) => b.fleetVehicles.compareTo(a.fleetVehicles));
    final withFleet = byFleet.where((c) => c.fleetVehicles > 0).toList();
    final named =
        withFleet.length > _sliceTones.length ? _sliceTones.length - 1 : withFleet.length;
    final slices = <FleetSlice>[
      for (var i = 0; i < named; i++)
        FleetSlice(
          label: withFleet[i].companyName,
          count: withFleet[i].fleetVehicles,
          tone: _sliceTones[i],
        ),
    ];
    final rest =
        withFleet.skip(named).fold<int>(0, (s, c) => s + c.fleetVehicles);
    if (rest > 0) {
      slices.add(FleetSlice(
        label: 'Other (${withFleet.length - named})',
        count: rest,
        tone: _sliceTones.last,
      ));
    }

    // ---- leaderboard -------------------------------------------------------
    final boardTotal = companies.fold<double>(0, (s, c) => s + c.tonsMoved);
    final leaderTons = companies.isEmpty ? 0.0 : companies.first.tonsMoved;
    final board = <LeaderboardEntry>[
      for (var i = 0; i < companies.length && i < 5; i++)
        LeaderboardEntry(
          rank: '${i + 1}',
          name: companies[i].companyName,
          tons: _tons(companies[i].tonsMoved),
          share: _pct1(
            boardTotal > 0 ? companies[i].tonsMoved / boardTotal * 100 : 0,
          ),
          barFraction:
              leaderTons > 0 ? companies[i].tonsMoved / leaderTons : 0.0,
          muted: companies[i].tonsMoved <= 0,
        ),
    ];

    // ---- alerts: real conditions only -------------------------------------
    final variance = monthRows
        .where((r) =>
            r.netMass != null &&
            r.deliveredTons != null &&
            (r.netMass! - r.deliveredTons!).abs() > 0.5)
        .length;
    final noPod = monthRows
        .where((r) => r.tripStatus == 'completed' && r.podPhotoPath == null)
        .length;
    final idle =
        bundle.companies.where((c) => c.fleetVehicles > 0 && c.trips == 0);

    final alerts = <AlertItem>[];
    if (variance > 0) {
      alerts.add(AlertItem(
        tone: OvTone.bad,
        icon: Icons.balance_rounded,
        title: 'Weight variance on $variance load${variance == 1 ? '' : 's'}',
        body: 'Mine net mass and delivered tons differ by more than 0.5 t.',
        age: monthName,
      ));
    }
    if (noPod > 0) {
      alerts.add(AlertItem(
        tone: OvTone.warn,
        icon: Icons.photo_camera_outlined,
        title: 'POD missing on $noPod delivered load${noPod == 1 ? '' : 's'}',
        body: 'Completed trips with no proof-of-delivery photo uploaded.',
        age: monthName,
      ));
    }
    if (wbOpen > 0) {
      alerts.add(AlertItem(
        tone: OvTone.warn,
        icon: Icons.fact_check_outlined,
        title: '$wbOpen waybill${wbOpen == 1 ? '' : 's'} still open',
        body: 'Loads dispatched without a closed-out waybill.',
        age: monthName,
      ));
    }
    for (final c in idle.take(2)) {
      alerts.add(AlertItem(
        tone: OvTone.warn,
        icon: Icons.local_shipping_outlined,
        title: '${c.companyName} has run no trips',
        body: '${c.fleetVehicles} vehicle(s) on file, no movement recorded.',
        age: monthName,
      ));
    }
    if (alerts.isEmpty) {
      alerts.add(AlertItem(
        tone: OvTone.good,
        icon: Icons.check_circle_outline_rounded,
        title: 'Nothing needs attention',
        body: 'No weight variances, missing PODs or open waybills.',
        age: monthName,
      ));
    }

    // ---- movement card -----------------------------------------------------
    final trendPct = monthlyTrend.length >= 2 && monthlyTrend[4] > 0
        ? (monthlyTrend[5] - monthlyTrend[4]) / monthlyTrend[4] * 100
        : null;

    final turnarounds = monthRows
        .where((r) => r.timeIn != null && r.timeOut != null)
        .map((r) => r.timeOut!.difference(r.timeIn!).inMinutes / 60)
        .where((h) => h >= 0 && h < 72)
        .toList();
    final avgTurnaround = turnarounds.isEmpty
        ? null
        : turnarounds.reduce((a, b) => a + b) / turnarounds.length;

    // ---- headline split ----------------------------------------------------
    final headlineScaled = (tons * 10).round();

    return OverviewData(
      fleet: FleetDistribution(
        slices: slices,
        totalLabel: '$fleetTotal total',
        utilisedPercent: utilisedPct,
      ),
      tons: TonsMoved(
        value: mlThousands(headlineScaled ~/ 10),
        valueSuffix: '.${(headlineScaled % 10).abs()} t',
        contextLine: ['Combined organizations', periodLabel],
        delta: deltaPct == null
            ? null
            : OvBadge(
                '${deltaPct < 0 ? '▼' : '▲'} '
                    '${(deltaPct.abs() * 10).round() / 10}%',
                deltaPct < 0 ? OvTone.warn : OvTone.good,
              ),
        deltaLine: deltaTons == null
            ? null
            : '${deltaTons < 0 ? '▼' : '▲'} '
                '${mlThousands(deltaTons.abs().round())} t '
                'vs. ${_months[lastMonth.month - 1]}',
        deltaLineTone: (deltaTons ?? 0) < 0 ? OvTone.warn : OvTone.good,
        series: series,
        compareSeries: compare,
        targetY: targetY,
        targetLabel: targetPace == null
            ? null
            : 'Target ${mlThousands(targetPace.round())} t/day',
        markerIndexes: markers,
        axisLabels: axis,
        calloutLabel: currentDaily.isEmpty || currentDaily.last == 0
            ? null
            : _tons(currentDaily.last),
        metrics: [
          MiniMetric(
            icon: Icons.local_shipping_rounded,
            tone: OvTone.accent,
            label: 'Peak day',
            value: peak == null ? '—' : mlThousands(peak.round()),
            unit: peak == null ? null : 't',
            trailing: peakDay == null ? null : '· $monthName $peakDay',
          ),
          MiniMetric(
            icon: Icons.schedule_rounded,
            tone: OvTone.warn,
            label: 'Avg / day',
            value: avgPerDay == null ? '—' : mlThousands(avgPerDay.round()),
            unit: avgPerDay == null ? null : 't',
          ),
          // The drop's third slot was a forecast. Nothing forecasts here, so
          // it carries the movement the fleet actually saw.
          MiniMetric(
            icon: Icons.insights_rounded,
            tone: OvTone.violet,
            label: 'Trucks active',
            value: '${activeTrucks.length}',
            trailing: fleetTotal > 0 ? '· of $fleetTotal on file' : null,
          ),
        ],
        footer: [
          OvStatCell(label: 'Trips', value: mlThousands(trips)),
          OvStatCell(label: 'Waybills done', value: mlThousands(wbDone)),
          OvStatCell(
            label: 'Waybills open',
            value: mlThousands(wbOpen),
            tone: wbOpen > 0 ? OvTone.warn : OvTone.ink,
          ),
          // Not "reliability" — this is the closed-out share of waybills.
          // There is no scheduled-vs-actual data to compute reliability from.
          OvStatCell(
            label: 'Waybills closed',
            value: wbTotal > 0 ? '${(wbDone / wbTotal * 100).round()}' : '—',
            suffix: wbTotal > 0 ? '%' : null,
          ),
        ],
        legend: [
          const OvLegendKey(
              label: 'This period', tone: OvTone.accent, dashed: false),
          OvLegendKey(
            label: '${_months[lastMonth.month - 1]} ${lastMonth.year}',
            tone: OvTone.ink,
            dashed: true,
            muted: true,
          ),
          // Only explained when a line is actually drawn.
          if (targetY != null)
            const OvLegendKey(
                label: 'Target pace', tone: OvTone.sky, dashed: true),
        ],
      ),
      transporters: transporters,
      trend: MonthlyTrend(
        headline: trendPct == null
            ? null
            : '${trendPct < 0 ? '-' : '+'}${trendPct.abs().round()}%',
        caption: trendPct == null
            ? 'No prior month to compare against'
            : trendPct < 0
                ? '▼ Down on last month'
                : '▲ Up on last month',
        captionTone: trendPct == null
            ? OvTone.slate
            : trendPct < 0
                ? OvTone.warn
                : OvTone.good,
        series: _normalise(
          monthlyTrend,
          monthlyTrend.fold<double>(0, (a, b) => b > a ? b : a),
        ),
        stats: [
          TrendStat(
            value: avgTurnaround == null
                ? '—'
                : avgTurnaround.toStringAsFixed(1),
            unit: avgTurnaround == null ? null : 'h',
            label: 'Avg turnaround',
          ),
          TrendStat(
            value: '${bundle.aggregate.companyCount}',
            label: 'Transporters',
          ),
          TrendStat(value: mlThousands(loads), label: 'Loads', tone: OvTone.sky),
          TrendStat(
            value: '$variance',
            label: 'Weight variances',
            tone: variance > 0 ? OvTone.warn : OvTone.ink,
          ),
          TrendStat(
            value: '$noPod',
            label: 'PODs missing',
            tone: noPod > 0 ? OvTone.warn : OvTone.ink,
          ),
          TrendStat(value: mlThousands(fleetTotal), label: 'Fleet on file'),
        ],
      ),
      leaderboard: Leaderboard(
        totalLabel: _tons(boardTotal),
        entries: board,
      ),
      alerts: alerts,
      topTransportersSubtitle: 'Ranked by tons moved · $periodLabel',
    );
  }

  static DateTime? _lastActive(List<RawReconRow> rows, String company) {
    DateTime? latest;
    for (final r in rows) {
      if (r.transporterName != company) continue;
      for (final t in [r.timeOut, r.timeIn, r.tripDate]) {
        if (t != null && (latest == null || t.isAfter(latest))) latest = t;
      }
    }
    return latest;
  }
}
