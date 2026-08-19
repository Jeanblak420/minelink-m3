import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/features/super_admin/data/models/company_monthly_ops_stats.dart';
import 'package:flutter_application_1/features/super_admin/data/models/insights_period.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart'
    show mlThousands;
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/leaderboard_board_body.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/leaderboard_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// The full-screen transporter leaderboard, opened from the accent card on the
/// transporters overview.
///
/// Every figure comes from `super_admin_monthly_insights_bundle` over the
/// selected [InsightsPeriod], plus the same bundle over the period before it
/// for the delta column. Nothing is derived from a second source: the board and
/// the overview read the same RPC with the same definitions, so they cannot
/// disagree about a month.
class TransporterLeaderboardScreen extends ConsumerStatefulWidget {
  const TransporterLeaderboardScreen({super.key});

  @override
  ConsumerState<TransporterLeaderboardScreen> createState() =>
      _TransporterLeaderboardScreenState();
}

class _TransporterLeaderboardScreenState
    extends ConsumerState<TransporterLeaderboardScreen> {
  InsightsPeriod _period = InsightsPeriod.monthToDate;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      // Deep-linked straight here: there is no overview to pop back to, so
      // send them to the one this board belongs to.
      context.go('/super-admin/insights/transporter');
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = MlOv.of(context);
    final current = ref.watch(
      periodInsightsBundleProvider(('transporter', _period)),
    );
    // The comparison window. A failure here must not take the board down — the
    // delta column simply reports nothing to compare against.
    final previous = ref
        .watch(periodInsightsBundleProvider(('transporter', _previousOf(_period))))
        .valueOrNull;

    return current.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Error(
        tokens: t,
        message: friendlyError(e),
        onRetry: () => ref.invalidate(
          periodInsightsBundleProvider(('transporter', _period)),
        ),
        onBack: _back,
      ),
      data: (bundle) {
        final board = TransporterLeaderboardMapper.build(
          bundle: bundle,
          previous: previous,
          period: _period,
        );
        return OvLeaderboardBoardBody(
          tokens: t,
          data: board,
          onBack: _back,
          onPeriodSelected: (i) => setState(
            () => _period = InsightsPeriod.values[i],
          ),
          onExport: () => _export(board),
        );
      },
    );
  }

  /// Export the ranking exactly as it stands on screen — same rows, same
  /// window, same figures — through the console's existing Excel / CSV / PDF
  /// exporter and its native Save As.
  Future<void> _export(OvLeaderboardBoard board) async {
    await ReconExporter.pickFormatAndExport(
      context,
      title: 'Transporter leaderboard — ${_period.periodLabel()}',
      filenameBase: 'transporter_leaderboard_${_period.name}',
      headers: TransporterLeaderboardMapper.exportHeaders(board),
      rows: TransporterLeaderboardMapper.exportRows(board),
      filters: {
        'Period': '${_period.chipLabel} · ${_period.periodLabel()} '
            '(${_period.phrase})',
      },
      summary: {
        for (final k in board.kpis) k.label: '${k.value}${k.unit ?? ''}',
        // The dash caveat travels with the file. A spreadsheet outlives the
        // screen it came from, and a reader who never saw the footnote would
        // otherwise have no way to tell "—" from a bad score.
        'Note': board.footnote,
      },
      noTotalColumns: TransporterLeaderboardMapper.exportNoTotalColumns,
    );
  }

  /// Which window the previous-period bundle should cover. [InsightsPeriod]
  /// owns the arithmetic; this only has to name a period whose `window()` is
  /// that range, so the provider family key stays an enum.
  static InsightsPeriod _previousOf(InsightsPeriod p) =>
      p == InsightsPeriod.monthToDate ? InsightsPeriod.lastMonth : p;
}

class _Error extends StatelessWidget {
  const _Error({
    required this.tokens,
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final MlOv tokens;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      color: t.canvas,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.leaderboard_outlined, size: 26, color: t.inkLo),
          const SizedBox(height: 12),
          Text(
            'Could not load the leaderboard',
            style: t.s(size: 14, weight: FontWeight.w600, color: t.inkHi),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: t.s(size: 12, color: t.inkMid),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: [
              OutlinedButton(onPressed: onBack, child: const Text('Back')),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ],
      ),
    );
  }
}

/// Turns two windows of the insights bundle into the board's view-model.
///
/// Formatting rules match the rest of the console: tonnage carries a thousands
/// separator and one decimal, percentages one decimal on this screen, and a
/// figure with nothing behind it is an EM DASH — never a zero. The drop's
/// dataset had an On-time column filled with 96/93/88 and a footnote claiming
/// ranks were held "by registration date"; both are replaced here by what the
/// database can actually answer, and the footnote says what the table did.
abstract final class TransporterLeaderboardMapper {
  static const String _dash = '—';

  // ---- export projection --------------------------------------------------
  //
  // The file is the table, not a second rendering of the data: it is built
  // from the same [OvLeaderboardBoard] the screen is showing, so a figure
  // cannot differ between what an admin reads and what they send on. The meta
  // line is split into its own column because "42 fleet · 9 routes" is two
  // facts, and a spreadsheet should be able to sort on either.

  static List<String> exportHeaders(OvLeaderboardBoard board) => [
        'Rank',
        'Transporter',
        'Fleet / routes',
        'Share',
        'Tons',
        'Trips',
        'Avg / trip',
        'On-time',
        'Waybills open',
        board.deltaColumnLabel,
      ];

  static List<List<String>> exportRows(OvLeaderboardBoard board) => [
        for (final r in board.rows)
          [
            '${r.rank}',
            r.name,
            r.meta,
            r.shareLabel,
            r.tons,
            r.trips,
            r.avgPerTrip,
            r.onTime,
            r.waybillsOpen,
            r.delta,
          ],
      ];

  /// Avg / trip. Tons, trips and open waybills all total to something true;
  /// the sum of per-trip averages is not a number that means anything, and a
  /// TOTAL row is read as authoritative.
  static const Set<int> exportNoTotalColumns = {6};

  static String _tons(double v) {
    final scaled = (v * 10).round();
    return '${mlThousands(scaled ~/ 10)}.${(scaled % 10).abs()}';
  }

  static String _pct(double v) => '${v.toStringAsFixed(1)}%';

  /// on-time ≥90 good · 85–89 warn · below that bad. Nothing judgeable is
  /// muted, because "no measure" is not a bad score.
  static OvTone _onTimeTone(int? pct) {
    if (pct == null) return OvTone.muted;
    if (pct >= 90) return OvTone.good;
    if (pct >= 85) return OvTone.warn;
    return OvTone.bad;
  }

  /// The open-waybill ladder already used on the transporter cards.
  static OvTone _openTone(int open) {
    if (open >= 6) return OvTone.bad;
    if (open >= 4) return OvTone.warn;
    return OvTone.ink;
  }

  static OvLeaderboardBoard build({
    required MonthlyInsightsBundle bundle,
    required InsightsPeriod period,
    MonthlyInsightsBundle? previous,
    DateTime? now,
  }) {
    final today = now ?? MlTime.now();
    final periodLabel = period.periodLabel(today);

    // Movers first, by tonnage. Everyone who moved nothing keeps a place in the
    // table — a transporter on the platform that hauled nothing this period is
    // a fact worth seeing — ordered by name, which is what the footnote says.
    final companies = [...bundle.companies]..sort((a, b) {
        final byTons = b.tonsMoved.compareTo(a.tonsMoved);
        if (byTons != 0) return byTons;
        return a.companyName.toLowerCase().compareTo(
              b.companyName.toLowerCase(),
            );
      });

    final networkTons = companies.fold<double>(0, (s, c) => s + c.tonsMoved);
    final leaderTons = companies.isEmpty ? 0.0 : companies.first.tonsMoved;
    final active = companies.where((c) => c.trips > 0).length;

    final prevByName = <String, double>{
      for (final c in previous?.companies ?? const <CompanyMonthlyOpsStats>[])
        c.companyName: c.tonsMoved,
    };

    String deltaFor(CompanyMonthlyOpsStats c) {
      final was = prevByName[c.companyName];
      // No prior figure, or a prior of zero, gives no percentage to state.
      // "▲ ∞%" and "▲ 0.0%" would both be inventions.
      if (was == null || was <= 0) return _dash;
      final pct = (c.tonsMoved - was) / was * 100;
      return '${pct < 0 ? '▼' : '▲'} ${_pct(pct.abs())}';
    }

    OvTone deltaToneFor(String delta) => delta == _dash
        ? OvTone.muted
        : delta.startsWith('▼')
            ? OvTone.bad
            : OvTone.good;

    // ---- KPI row ----------------------------------------------------------
    final leadOverSecond = companies.length < 2
        ? null
        : companies.first.tonsMoved - companies[1].tonsMoved;

    final kpis = <OvBoardKpi>[
      OvBoardKpi(label: 'Network tons', value: _tons(networkTons), unit: ' t'),
      OvBoardKpi(
        label: 'Active haulers',
        value: '$active',
        unit: ' of ${companies.length}',
      ),
      OvBoardKpi(
        label: 'Avg per active hauler',
        value: active == 0 ? _dash : _tons(networkTons / active),
        unit: active == 0 ? null : ' t',
      ),
      OvBoardKpi(
        label: 'Lead over #2',
        value: leadOverSecond == null ? _dash : _tons(leadOverSecond),
        unit: leadOverSecond == null ? null : ' t',
        tone: OvTone.sky,
      ),
    ];

    // ---- podium -----------------------------------------------------------
    // Only whoever actually moved product stands on it. A podium of three
    // zeroes would dress "nothing happened" up as a race.
    final podium = <OvPodiumEntry>[];
    for (var i = 0; i < companies.length && i < 3; i++) {
      final c = companies[i];
      if (c.tonsMoved <= 0) break;
      final delta = deltaFor(c);
      final share = networkTons <= 0 ? 0.0 : c.tonsMoved / networkTons * 100;
      podium.add(
        OvPodiumEntry(
          rank: i + 1,
          name: c.companyName,
          tons: _tons(c.tonsMoved),
          shareLabel: '${_pct(share)} of network',
          metaSuffix: i == 0
              ? '· ${c.trips} trip${c.trips == 1 ? '' : 's'}'
              : null,
          barFraction: leaderTons <= 0 ? 0 : c.tonsMoved / leaderTons,
          delta: delta == _dash ? null : delta,
          deltaUp: !delta.startsWith('▼'),
        ),
      );
    }

    // ---- ranking table ----------------------------------------------------
    final rows = <OvRankRow>[];
    for (var i = 0; i < companies.length; i++) {
      final c = companies[i];
      final inactive = c.trips == 0;
      final share = networkTons <= 0 ? 0.0 : c.tonsMoved / networkTons * 100;
      final delta = deltaFor(c);
      final onTime = c.onTimePercent;

      rows.add(
        OvRankRow(
          rank: i + 1,
          name: c.companyName,
          meta: [
            '${c.fleetVehicles} fleet',
            if (c.routesDistinct > 0)
              '${c.routesDistinct} route${c.routesDistinct == 1 ? '' : 's'}'
            else
              'no active route',
          ].join(' · '),
          shareLabel: _pct(share),
          barFraction: leaderTons <= 0 ? 0 : c.tonsMoved / leaderTons,
          tons: _tons(c.tonsMoved),
          trips: '${c.trips}',
          avgPerTrip: c.trips == 0 ? _dash : _tons(c.tonsMoved / c.trips),
          // A dash here means the route carried no agreed transit time, or no
          // trip both left the mine and offloaded. It is not a zero score.
          onTime: onTime == null ? _dash : '$onTime%',
          onTimeTone: _onTimeTone(onTime),
          waybillsOpen: '${c.pendingWaybills}',
          waybillsOpenTone:
              inactive ? OvTone.muted : _openTone(c.pendingWaybills),
          delta: delta,
          deltaTone: deltaToneFor(delta),
          inactive: inactive,
        ),
      );
    }

    // ---- footnote ---------------------------------------------------------
    // A claim about the data, so it is written from the same figures the table
    // shows. The on-time sentence appears only when a dash is actually on
    // screen, so it explains something the reader can see.
    final anyUnjudged = companies.any((c) => c.dueTrips == 0);
    final footnote = [
      'Share is measured against ${_tons(networkTons)} t moved '
          'network-wide in $periodLabel.',
      if (anyUnjudged)
        'On-time counts only trips on a route with an agreed transit time '
            'that both left the mine and offloaded — a dash means there was '
            'nothing to measure, not a missed delivery.',
      'Transporters with no recorded trips are listed alphabetically after '
          'those that moved product.',
    ].join(' ');

    return OvLeaderboardBoard(
      eyebrow: 'Transporter league',
      titleLead: 'Leaderboard — ',
      titleAccent: 'Tons',
      subtitle: 'All transporters ranked by tonnage moved · $periodLabel · '
          '${period.phrase}',
      periods: [for (final p in InsightsPeriod.values) p.chipLabel],
      activePeriod: InsightsPeriod.values.indexOf(period),
      kpis: kpis,
      podium: podium,
      tableTitle: 'Full ranking',
      tableSubtitle: 'Every registered transporter · $periodLabel',
      countLabel:
          '${companies.length} transporter${companies.length == 1 ? '' : 's'}',
      rows: rows,
      deltaColumnLabel: 'vs. ${period.previousLabel(today)}',
      footnote: footnote,
    );
  }
}
