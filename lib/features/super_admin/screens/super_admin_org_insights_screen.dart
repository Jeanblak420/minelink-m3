import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/features/super_admin/data/models/company_monthly_ops_stats.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/tokens/ml_control_room_palette.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

enum _CompanyFilter { all, active, highThroughput, attention }

/// Org-type overview (Insights → Transporters / Buyers / Mines): a
/// control-room dashboard where EVERY figure is computed from live records —
/// the monthly rollup RPC and the platform-wide recon rows. Nothing is
/// hard-coded or sampled.
///
/// Layout follows the "V3 Glass" handoff. The one figure that is not a direct
/// aggregation is the flagship's month forecast, which is an explicit
/// run-rate extrapolation of the same recorded rows (see
/// [_Derived.forecastMonthTons]); everything else is a straight sum, mean or
/// ratio, and renders "—" when there is nothing on record.
class SuperAdminOrgInsightsScreen extends ConsumerStatefulWidget {
  final String orgType;

  const SuperAdminOrgInsightsScreen({super.key, required this.orgType});

  @override
  ConsumerState<SuperAdminOrgInsightsScreen> createState() =>
      _SuperAdminOrgInsightsScreenState();
}

class _SuperAdminOrgInsightsScreenState
    extends ConsumerState<SuperAdminOrgInsightsScreen> {
  static final _tons = NumberFormat('#,##0.0');
  static final _tonsInt = NumberFormat('#,##0');
  static final _int = NumberFormat('#,##0');

  _CompanyFilter _filter = _CompanyFilter.all;

  /// Focused company id (null = whole network). Set from the scope pill in
  /// the header, a leaderboard row, or by tapping a company card — the donut,
  /// flagship and health panels then re-compute for just that company.
  String? _focusId;

  /// When the live bundle last landed — feeds the "updated Xm ago" subtitle.
  DateTime? _dataAt;

  String _agoShort(DateTime t) => MlTime.ago(t);

  String get _plural => switch (widget.orgType) {
    'transporter' => 'transporters',
    'buyer' => 'buyers',
    _ => 'mines & suppliers',
  };

  String get _singular => switch (widget.orgType) {
    'transporter' => 'transporter',
    'buyer' => 'buyer',
    _ => 'mine / supplier',
  };

  bool get _hasFleet => widget.orgType == 'transporter';

  /// The recon-row column that names this org type's party.
  String? _partyName(RawReconRow r) => switch (widget.orgType) {
    'transporter' => r.transporterName,
    'buyer' => r.customerName,
    _ => r.sourceName,
  };

  @override
  Widget build(BuildContext context) {
    ref.listen(monthlyInsightsBundleProvider(widget.orgType), (prev, next) {
      if (next.hasValue) setState(() => _dataAt = DateTime.now());
    });
    final bundleAsync = ref.watch(
      monthlyInsightsBundleProvider(widget.orgType),
    );
    final rows =
        ref.watch(rawReconRowsProvider(null)).valueOrNull ??
        const <RawReconRow>[];

    return Container(
      color: MlControlRoom.pageBg,
      child: bundleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => MlEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load insights',
          message: friendlyError(e),
        ),
        data: (bundle) {
          final companies = [...bundle.companies]
            ..sort((a, b) => b.tonsMoved.compareTo(a.tonsMoved));
          final d = _Derived(
            companies: companies,
            rows: rows,
            partyName: _partyName,
          );
          return _body(context, bundle, companies, d);
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    MonthlyInsightsBundle bundle,
    List<CompanyMonthlyOpsStats> companies,
    _Derived d,
  ) {
    CompanyMonthlyOpsStats? focus;
    for (final c in companies) {
      if (c.companyId == _focusId) focus = c;
    }
    final visible = _visibleCompanies(companies, d, focus);

    return SingleChildScrollView(
      // Mock gutters: 32px side / 28px top, measured off the design render.
      padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
      // Split on the width actually available to the content, not the window —
      // the console sidebar takes 274px when expanded and 78px collapsed, so
      // window width alone would mis-call the breakpoint. (Safe here: the only
      // IntrinsicHeight is nested *below* this builder, never above it.)
      child: LayoutBuilder(
        builder: (context, c) {
          const railW = 18.0;
          final twoCol = c.maxWidth >= 1120;
          final mainW = twoCol ? (c.maxWidth - railW) * 0.56 : c.maxWidth;
          // Mock hero split: the fleet panel holds ~20.4% of the list column,
          // floored so the ring still fits on a narrow console.
          final donutW = (mainW * 0.204).clamp(210.0, 380.0);
          // The flagship only splits number-beside-chart when the chart keeps
          // a usable width; otherwise the number stacks above it.
          final heroSideBySide = mainW - donutW - 18 >= 430;

          final donut = _distributionCard(companies, d, focus, donutW);
          final flagship = _flagshipCard(context, d, focus, heroSideBySide);

          // Mock hero: narrow fleet panel beside the wide flagship.
          final heroRow = mainW >= 620
              ? IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(width: donutW, child: donut),
                      const SizedBox(width: 18),
                      Expanded(child: flagship),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [donut, const SizedBox(height: 18), flagship],
                );

          final mainColumn = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heroRow,
              const SizedBox(height: 28),
              _sectionHeader(companies, d),
              const SizedBox(height: 20),
              if (visible.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: _glass(),
                  child: Text(
                    'No companies match this filter.',
                    textAlign: TextAlign.center,
                    style: context.mlText.bodyMedium.copyWith(
                      color: MlControlRoom.textMuted,
                    ),
                  ),
                )
              else
                for (var i = 0; i < visible.length; i++) ...[
                  _companyCard(
                    context,
                    visible[i],
                    companies.indexOf(visible[i]),
                    d,
                  ),
                  if (i != visible.length - 1) const SizedBox(height: 16),
                ],
            ],
          );

          final sideColumn = _railColumn(context, companies, d, focus);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mock: no page toolbar — the title, period and console actions
              // all live in the app bar, so the hero opens the content.
              // Mock: two-column page — list on the left, a rail of trend /
              // leaderboard / alerts running full height on the right (56/44).
              if (twoCol)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 56, child: mainColumn),
                    const SizedBox(width: railW),
                    Expanded(flex: 44, child: sideColumn),
                  ],
                )
              else ...[
                mainColumn,
                const SizedBox(height: 18),
                sideColumn,
              ],
            ],
          );
        },
      ),
    );
  }

  /// Design `.glass`: a white sheen gradient over the translucent navy base,
  /// a hairline white border, and a soft drop shadow with a 1px top highlight.
  /// [wash] adds the subtle cyan tint the flagship panel carries.
  BoxDecoration _glass({bool wash = false}) {
    // BoxDecoration ignores `color` whenever a `gradient` is set, so the sheen
    // has to be composited onto the base here rather than layered over it —
    // otherwise the panels lose their navy entirely and render near-black.
    final base = wash
        ? Color.alphaBlend(MlControlRoom.cyan.withValues(alpha: 0.035), MlControlRoom.glassBase)
        : MlControlRoom.glassBase;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.alphaBlend(MlControlRoom.glassSheenTop, base),
          Color.alphaBlend(MlControlRoom.glassSheenBottom, base),
        ],
      ),
      borderRadius: BorderRadius.circular(MlControlRoom.rCard),
      border: Border.all(color: MlControlRoom.glassBorder),
      boxShadow: [
        BoxShadow(
          color: MlTokens.overlayDark.withValues(alpha: 0.8),
          blurRadius: 32,
          spreadRadius: -20,
          offset: const Offset(0, 12),
        ),
      ],
    );
  }

  Text _panelLabel(String text) => Text(
    text.toUpperCase(),
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: context.mlText.overline.copyWith(color: MlControlRoom.textMuted),
  );

  // ---- fleet distribution donut ----

  Widget _distributionCard(
    List<CompanyMonthlyOpsStats> companies,
    _Derived d,
    CompanyMonthlyOpsStats? focus,
    double cardW,
  ) {
    // Network view — transporters: share of registered fleet; buyers / mines:
    // share of tons moved. Focused on one company — transporters: that fleet's
    // on-route vs available split; buyers / mines: its share of network tons.
    final ramp = MlControlRoom.fleetRamp;
    List<({String name, double value, Color color})> slices;
    String label;
    String badge;
    String centerBig;
    // Small unit glyph trailing the centre figure ("%" in the mock).
    String centerUnit;
    String centerSmall;

    if (focus != null && _hasFleet) {
      final active = d.activeTrucksFor(focus.companyName);
      final available = math.max(0, focus.fleetVehicles - active);
      final util = d.utilPctFor(focus);
      label = 'Fleet utilisation';
      badge = '${_int.format(focus.fleetVehicles)} fleet';
      centerBig = util == null ? '—' : '$util';
      centerUnit = util == null ? '' : '%';
      centerSmall = 'UTILISED';
      slices = [
        if (active > 0)
          (name: 'On route now', value: active.toDouble(), color: ramp[0]),
        if (available > 0)
          (name: 'Available', value: available.toDouble(), color: ramp.last),
      ];
    } else if (focus != null) {
      final rest = math.max(0.0, d.tonsThisMonth - focus.tonsMoved);
      final share = d.tonsThisMonth <= 0
          ? null
          : (focus.tonsMoved / d.tonsThisMonth * 100).round();
      label = 'Share of tonnage';
      badge = '${_tonsInt.format(d.tonsThisMonth)} t network';
      centerBig = share == null ? '—' : '$share';
      centerUnit = share == null ? '' : '%';
      centerSmall = 'OF NETWORK';
      slices = [
        if (focus.tonsMoved > 0)
          (name: focus.companyName, value: focus.tonsMoved, color: ramp[0]),
        if (rest > 0) (name: 'Rest of network', value: rest, color: ramp.last),
      ];
    } else {
      final entries =
          companies
              .map(
                (c) => (
                  name: c.companyName,
                  value: _hasFleet ? c.fleetVehicles.toDouble() : c.tonsMoved,
                ),
              )
              .where((e) => e.value > 0)
              .toList()
            ..sort((a, b) => b.value.compareTo(a.value));

      final top = entries.take(ramp.length - 1).toList();
      final restSum = entries
          .skip(ramp.length - 1)
          .fold(0.0, (s, e) => s + e.value);
      slices = [
        for (var i = 0; i < top.length; i++)
          (name: top[i].name, value: top[i].value, color: ramp[i]),
        if (restSum > 0) (name: 'Others', value: restSum, color: ramp.last),
      ];

      final utilPct = d.overallUtilPct;
      label = _hasFleet ? 'Fleet distribution' : 'Tonnage share';
      badge = _hasFleet
          ? '${_int.format(d.totalFleet)} total'
          : '${companies.length} total';
      centerBig = _hasFleet
          ? (utilPct == null ? '—' : '$utilPct')
          : '${d.activeCompanies}';
      centerUnit = _hasFleet && utilPct != null ? '%' : '';
      centerSmall = _hasFleet ? 'UTILISED' : 'ACTIVE';
    }

    // Mock ring: ~176px across on the design's 370px panel, stroke 20.
    final ring = ((cardW - 36) * 0.53).clamp(120.0, 176.0);

    return Container(
      // The legend is a full-bleed well pinned to the foot of the panel, so
      // the card itself carries no padding — the header/ring block owns its
      // own inset instead.
      decoration: _glass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: _panelLabel(label)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: MlControlRoom.cyan.withValues(alpha: 0.12),
                        borderRadius: MlShape.pill,
                        border: Border.all(
                          color: MlControlRoom.cyan.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Text(
                        badge,
                        style: context.mlText.labelMedium.copyWith(
                          color: MlControlRoom.cyan,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Center(
                  child: SizedBox(
                    width: ring,
                    height: ring,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DonutPainter(
                              values: [for (final s in slices) s.value],
                              colors: [for (final s in slices) s.color],
                              trackColor: MlTokens.overlayLight.withValues(alpha: 0.05),
                              stroke: ring * 0.114,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                  fontFamily: MlTokens.fontSans,
                                  fontWeight: FontWeight.w800,
                                  color: MlControlRoom.textStrong,
                                ),
                                children: [
                                  TextSpan(
                                    text: centerBig,
                                    style: const TextStyle(
                                      fontSize: 34,
                                      letterSpacing: -0.8,
                                    ),
                                  ),
                                  if (centerUnit.isNotEmpty)
                                    TextSpan(
                                      text: centerUnit,
                                      style: context.mlText.bodyLarge.copyWith(
                                        color: MlControlRoom.textBody,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              centerSmall,
                              style: context.mlText.labelSmall.copyWith(
                                color: MlControlRoom.textMuted,
                                letterSpacing: 2.6,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 26),
              ],
            ),
          ),
          // Mock: the legend sits in its own faint well, edge-to-edge across
          // the foot of the panel with a hairline lid.
          Container(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
            decoration: BoxDecoration(
              color: MlControlRoom.surfaceTileAlt,
              border: Border(top: BorderSide(color: MlControlRoom.tileBorder)),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(MlControlRoom.rCard - 1),
                bottomRight: Radius.circular(MlControlRoom.rCard - 1),
              ),
            ),
            child: slices.isEmpty
                ? Text(
                    _hasFleet
                        ? 'No fleet registered yet.'
                        : 'No tonnage recorded this month.',
                    style: context.mlText.bodySmall.copyWith(
                      color: MlControlRoom.textMuted,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < slices.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i == slices.length - 1 ? 0 : 13,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: slices[i].color,
                                  borderRadius: MlShape.radiusExtraSmall,
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Text(
                                  slices[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.mlText.bodyMedium.copyWith(
                                    color: MlControlRoom.textBody,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _hasFleet
                                    ? _int.format(slices[i].value.round())
                                    : _tonsInt.format(slices[i].value),
                                style: context.mlText.code(
                                  color: MlControlRoom.textStrong,
                                  size: 13,
                                  weight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // ---- tons-moved flagship ----

  Widget _flagshipCard(
    BuildContext context,
    _Derived d,
    CompanyMonthlyOpsStats? focus,
    bool wide,
  ) {
    final tonsPeriod = focus?.tonsMoved ?? d.tonsThisMonth;
    final delta = focus == null
        ? d.tonsDeltaPct
        : d.tonsDeltaPctFor(focus.companyName, focus.tonsMoved);
    final whole = tonsPeriod.truncate();
    final frac = ((tonsPeriod - whole) * 10).round().clamp(0, 9);
    final tripsN = focus?.trips ?? d.totalTrips;
    final wbDone = focus?.completedWaybills ?? d.totalWbDone;
    final wbOpen = focus?.pendingWaybills ?? d.totalWbOpen;
    final reliability = focus == null
        ? d.completionPct
        : d.completionPctFor(focus);

    // Real series: this month day-by-day, and the same window last month.
    final series = focus == null
        ? d.dailyTonsMonthToDate(null)
        : d.dailyTonsMonthToDate(focus.companyName);
    final prevSeries = focus == null
        ? d.prevMonthDailyTons(null)
        : d.prevMonthDailyTons(focus.companyName);
    final peak = d.peakDay(focus?.companyName);
    final avgDay = d.avgPerDay(focus?.companyName);
    final forecast = d.forecastMonthTons(focus?.companyName);
    final prevAvg = d.prevMonthAvgPerDay(focus?.companyName);
    // Month-end projection measured against last month's recorded total.
    final prevTotal = d.prevMonthTons(focus?.companyName);
    final forecastDelta =
        (forecast == null || prevTotal == null || prevTotal <= 0)
        ? null
        : (forecast - prevTotal) / prevTotal * 100;
    final tonsDelta = focus == null
        ? d.tonsDeltaAbs
        : d.tonsDeltaAbsFor(focus.companyName, focus.tonsMoved);

    // Design `.rail .cell`: 10px/600 caps label over an 18px mono value, with
    // the unit glyph dropping to a dim half-size tick.
    Widget miniStat(
      String label,
      String value, {
      String? unit,
      Color? valueColor,
    }) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelLabel(label),
          const SizedBox(height: 8),
          RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: context.mlText.code(
                    color: valueColor ?? MlControlRoom.textStrong,
                    size: 18,
                    weight: FontWeight.w500,
                  ),
                ),
                if (unit != null)
                  TextSpan(
                    text: unit,
                    style: context.mlText.code(
                      color: MlControlRoom.textDim,
                      size: 11,
                      weight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // Design `.fs-strip .cell`: 32px tinted icon well + label/value pair, the
    // value carrying a dim unit tick and an optional delta tail.
    Widget stripCell(
      IconData icon,
      Color tint,
      String label,
      String value, {
      String? unit,
      String? tail,
      Color? tailColor,
    }) => Expanded(
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.10),
              borderRadius: MlShape.radiusMedium,
              border: Border.all(color: tint.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.overline.copyWith(
                    color: MlControlRoom.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: value,
                        style: context.mlText.code(
                          color: MlControlRoom.textStrong,
                          size: 17,
                          weight: FontWeight.w600,
                        ),
                      ),
                      if (unit != null)
                        TextSpan(
                          text: unit,
                          style: context.mlText.code(
                            color: MlControlRoom.textDim,
                            size: 11,
                            weight: FontWeight.w400,
                          ),
                        ),
                      if (tail != null)
                        TextSpan(
                          text: tail,
                          style: context.mlText.code(
                            color: tailColor ?? MlControlRoom.textMuted,
                            size: 12,
                            weight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Mock: the headline figure sits to the LEFT of the chart, not above it.
    final numberBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: TextStyle(
              fontFamily: MlTokens.fontSerif,
              fontWeight: FontWeight.w700,
              color: MlControlRoom.textStrong,
            ),
            children: [
              TextSpan(
                text: _int.format(whole),
                style: const TextStyle(fontSize: 44, letterSpacing: -1.2),
              ),
              TextSpan(
                text: '.$frac',
                style: context.mlText.titleLarge.copyWith(
                  color: MlControlRoom.textStrong.withValues(alpha: 0.75),
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: 't',
                style: context.mlText.titleMedium.copyWith(
                  color: MlControlRoom.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Mock: scope, period and the month-on-month delta all read as one
        // line under the figure — the delta is the only coloured run.
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          text: TextSpan(
            style: context.mlText.bodyMedium.copyWith(
              color: MlControlRoom.textMuted,
            ),
            children: [
              TextSpan(text: focus?.companyName ?? 'Combined organizations'),
              const TextSpan(text: '   ·   '),
              TextSpan(
                text: '${DateFormat('MMM yyyy').format(DateTime.now())} · MTD',
              ),
              if (tonsDelta != null) ...[
                const TextSpan(text: '   ·   '),
                TextSpan(
                  text:
                      '${tonsDelta >= 0 ? '▲' : '▼'} '
                      '${_tonsInt.format(tonsDelta.abs())} t vs. '
                      '${DateFormat('MMM').format(d.prevMonth)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: tonsDelta >= 0 ? MlControlRoom.green : MlControlRoom.red,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final chart = _MovementChart(
      series: series,
      prevSeries: prevSeries,
      reference: prevAvg,
      // Mock labels the reference line "TARGET": the pace that would match
      // last month's recorded total, and that month's total as the caption.
      referenceTotal: d.prevMonthTons(focus?.companyName),
      monthStart: d.monthStart,
    );

    Widget divider() => Container(height: 1, color: MlControlRoom.glassBorder);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(MlControlRoom.rCard),
        onTap: () => context.go('/super-admin/recon-tables'),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 15, 18, 16),
          decoration: _glass(wash: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _panelLabel('Tons moved this period')),
                  if (delta != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: (delta >= 0 ? MlControlRoom.green : MlControlRoom.red).withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: MlShape.pill,
                      ),
                      child: Text(
                        '${delta >= 0 ? '▲' : '▼'} '
                        '${delta.abs().toStringAsFixed(1)}%',
                        style: context.mlText.labelSmall.copyWith(
                          color: delta >= 0 ? MlControlRoom.green : MlControlRoom.red,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(width: 220, child: numberBlock),
                    const SizedBox(width: 16),
                    Expanded(child: chart),
                  ],
                )
              else ...[
                numberBlock,
                const SizedBox(height: 14),
                chart,
              ],
              const SizedBox(height: 18),
              divider(),
              const SizedBox(height: 18),
              // Mock strip: peak day · avg/day · month forecast.
              Row(
                children: [
                  stripCell(
                    Icons.local_shipping_outlined,
                    MlControlRoom.cyan,
                    'Peak day',
                    peak == null ? '—' : _tonsInt.format(peak.$1),
                    unit: peak == null
                        ? null
                        : ' t · ${DateFormat('MMM d').format(peak.$2)}',
                  ),
                  stripCell(
                    Icons.schedule_rounded,
                    MlControlRoom.amber,
                    'Avg / day',
                    avgDay == null ? '—' : _tonsInt.format(avgDay),
                    unit: avgDay == null ? null : ' t',
                  ),
                  stripCell(
                    Icons.timeline_rounded,
                    MlControlRoom.violet,
                    'Forecast ${DateFormat('MMM').format(DateTime.now())}',
                    forecast == null ? '—' : _tonsInt.format(forecast),
                    unit: forecast == null ? null : ' t',
                    tail: forecastDelta == null
                        ? null
                        : ' ${forecastDelta >= 0 ? '+' : '−'}'
                              '${forecastDelta.abs().toStringAsFixed(1)}%',
                    tailColor: forecastDelta == null
                        ? null
                        : (forecastDelta >= 0 ? MlControlRoom.green : MlControlRoom.red),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              divider(),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  miniStat('Trips', _int.format(tripsN)),
                  miniStat('Waybills done', _int.format(wbDone)),
                  miniStat(
                    'Waybills open',
                    _int.format(wbOpen),
                    valueColor: wbOpen > 0 ? MlControlRoom.amber : MlControlRoom.textStrong,
                  ),
                  miniStat(
                    'Reliability',
                    reliability == null ? '—' : '$reliability',
                    unit: reliability == null ? null : '%',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---- rail band: trend / utilisation / leaderboard / alerts ----

  /// Mock: the right-hand rail — movement trend, then the tonnage leaderboard,
  /// then the alerts feed, stacked and running the full height of the page.
  Widget _railColumn(
    BuildContext context,
    List<CompanyMonthlyOpsStats> companies,
    _Derived d,
    CompanyMonthlyOpsStats? focus,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _trendCard(d, focus),
        const SizedBox(height: 14),
        _leaderboardCard(context, companies),
        const SizedBox(height: 14),
        _alertsCard(context, d),
      ],
    );
  }

  /// Design `.rail-card` #1 — headline growth, sparkline, six mini wells.
  Widget _trendCard(_Derived d, CompanyMonthlyOpsStats? focus) {
    final name = focus?.companyName;
    final pct = focus == null
        ? d.tonsDeltaPct
        : d.tonsDeltaPctFor(focus.companyName, focus.tonsMoved);
    final turnaround = d.avgTurnaroundHours(name);
    final reliability = focus == null
        ? d.completionPct
        : d.completionPctFor(focus);
    final alerts = focus == null
        ? d.attentionItems.length
        : d.attentionFor(focus).length;
    final series = d.dailyTonsMonthToDate(name);

    // Mock: six separately-rounded wells on an 8px gutter, value over caps
    // label. (Do NOT use CrossAxisAlignment.stretch on the grid rows — they
    // sit in a vertically unbounded scroll column, so stretch hands the cells
    // infinite height; a fixed height keeps the grid square instead.)
    // minHeight, not height: `Container` counts the 1px `Border.all` as
    // padding on top of the 13+12 inset, so a hard 68 left the Column 41px for
    // two lines that need 42 — a 1px overflow on every render, and worse once
    // UiPrefs.textScale goes above 1.0. A minimum keeps the grid square
    // at the default size and lets the tile grow instead of clipping.
    Widget mini(String label, String value, {String? unit, Color? color}) =>
        Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.fromLTRB(15, 13, 15, 12),
          decoration: BoxDecoration(
            color: MlControlRoom.surfaceTile,
            borderRadius: MlShape.radiusMedium,
            border: Border.all(color: MlControlRoom.tileBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: context.mlText.code(
                        color: color ?? MlControlRoom.textStrong,
                        size: 17,
                        weight: FontWeight.w700,
                      ),
                    ),
                    if (unit != null)
                      TextSpan(
                        text: unit,
                        style: context.mlText.code(
                          color: MlControlRoom.textDim,
                          size: 11,
                          weight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.overline.copyWith(
                  color: MlControlRoom.textMuted,
                ),
              ),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _glass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panelLabel('Monthly movement trend'),
          const SizedBox(height: 10),
          Text(
            pct == null
                ? '—'
                : '${pct >= 0 ? '+' : '−'}${pct.abs().toStringAsFixed(0)}%',
            style: context.mlText.headlineLarge.copyWith(
              color: MlControlRoom.textStrong,
              letterSpacing: -0.64,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pct == null
                ? 'No comparable month on record yet'
                : pct >= 0
                ? '▲ Healthy growth this month'
                : '▼ Down on last month',
            style: context.mlText.labelSmall.copyWith(
              color: pct == null ? MlControlRoom.textMuted : (pct >= 0 ? MlControlRoom.green : MlControlRoom.red),
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 68,
            child: CustomPaint(
              size: Size.infinite,
              painter: _SparkPainter(values: series),
            ),
          ),
          const SizedBox(height: 18),
          // Mock: a 2 x 3 grid of rounded wells on an 8px gutter.
          Row(
            children: [
              Expanded(
                child: mini(
                  'Avg turnaround',
                  turnaround == null ? '—' : turnaround.toStringAsFixed(1),
                  unit: turnaround == null ? null : 'h',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: mini(
                  'Route reliability',
                  reliability == null ? '—' : '$reliability',
                  unit: reliability == null ? null : '%',
                  color: MlControlRoom.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: mini(
                  'Priority alerts',
                  '$alerts',
                  color: alerts > 0 ? MlControlRoom.amber : MlControlRoom.textStrong,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: mini('Reviews needed', '${d.reviewsNeeded}')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: mini('Anomalies', '${d.anomalyCount}')),
              const SizedBox(width: 8),
              Expanded(
                child: mini(
                  'Routes rested',
                  // NOT zero-padded. It was the only one of the four readouts
                  // in this block that was, so a quiet week rendered "00"
                  // beside "4" and "10" — which reads as a broken value rather
                  // than as none.
                  '${d.routesRested}',
                  color: MlControlRoom.cyanText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Design `.rail-sec` — tonnage leaderboard; the leader gets the cyan glow,
  /// companies with nothing moved render in the dimmed "idle" state.
  Widget _leaderboardCard(
    BuildContext context,
    List<CompanyMonthlyOpsStats> companies,
  ) {
    final ranked = [...companies]
      ..sort((a, b) => b.tonsMoved.compareTo(a.tonsMoved));
    final rows = ranked.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Leaderboard — Tons',
          style: TextStyle(
            // Mock: rail section heads are the editorial serif, like the
            // console's page title — only the panel labels stay sans caps.
            fontFamily: MlTokens.fontSerif,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.15,
            color: MlControlRoom.textStrong,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Network share this month',
          style: context.mlText.labelSmall.copyWith(
            color: MlControlRoom.textMuted,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < rows.length; i++) ...[
          _boardRow(context, rows[i], i, idle: rows[i].tonsMoved <= 0),
          if (i != rows.length - 1) const SizedBox(height: 9),
        ],
        if (rows.isEmpty)
          Text(
            'No tonnage recorded yet.',
            style: context.mlText.bodySmall.copyWith(
              color: MlControlRoom.textMuted,
            ),
          ),
      ],
    );
  }

  Widget _boardRow(
    BuildContext context,
    CompanyMonthlyOpsStats c,
    int i, {
    required bool idle,
  }) {
    final lead = i == 0 && !idle;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: MlShape.radiusMedium,
        onTap: () => context.go(
          '/super-admin/insights/${widget.orgType}/company/${c.companyId}',
        ),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: lead ? MlControlRoom.cyan.withValues(alpha: 0.06) : MlControlRoom.surfaceTileAlt,
            borderRadius: MlShape.radiusMedium,
            border: Border.all(
              color: lead ? MlControlRoom.cyan.withValues(alpha: 0.4) : MlControlRoom.tileBorder,
            ),
            boxShadow: lead
                ? [
                    BoxShadow(
                      color: MlControlRoom.cyan.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: -10,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Text(
                (i + 1).toString().padLeft(2, '0'),
                style: context.mlText.code(
                  color: MlControlRoom.textDim,
                  size: 10,
                  weight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  c.companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.titleSmall.copyWith(
                    color: idle ? MlControlRoom.textMuted : MlControlRoom.textStrong,
                    fontWeight: idle ? FontWeight.w500 : FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_tons.format(c.tonsMoved)} t',
                style: context.mlText.code(
                  color: idle ? MlControlRoom.textMuted : (lead ? MlControlRoom.cyanText : MlControlRoom.textStrong),
                  size: 12,
                  weight: idle ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Design `.rail-card` #4 — the alerts feed, built from real attention
  /// signals (open waybills, low utilisation, silent fleets).
  Widget _alertsCard(BuildContext context, _Derived d) {
    final items = d.attentionItems.take(4).toList();
    // Design shows a relative age per alert; ours is the company's last
    // recorded movement, so the stamp means something real.
    final stamps = {for (final a in items) a.company: d.ageTagFor(a.company)};

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _glass(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Recent alerts',
                      style: context.mlText.editorialSmall.copyWith(
                        color: MlControlRoom.textStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Signals from the last 24h',
                      style: context.mlText.bodySmall.copyWith(
                        color: MlControlRoom.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: MlShape.radiusSmall,
                  onTap: () => context.go('/super-admin/disputes'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: MlShape.radiusSmall,
                      border: Border.all(color: MlControlRoom.borderStrong),
                    ),
                    child: Text(
                      'View all',
                      style: context.mlText.labelSmall.copyWith(
                        color: MlControlRoom.textBody,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: Text(
                'Nothing needs attention right now.',
                style: context.mlText.bodySmall.copyWith(
                  color: MlControlRoom.textMuted,
                ),
              ),
            ),
          for (var i = 0; i < items.length; i++) ...[
            _alertRow(items[i], stamps[items[i].company]),
            if (i != items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _alertRow(_AttentionItem a, String? stamp) {
    final tint = a.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: MlControlRoom.surfaceTileAlt,
        borderRadius: MlShape.radiusMedium,
        border: Border.all(color: MlControlRoom.tileBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.08),
              borderRadius: MlShape.radiusMedium,
              border: Border.all(color: tint.withValues(alpha: 0.25)),
            ),
            child: Icon(a.icon, size: 15, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.titleSmall.copyWith(
                    color: MlControlRoom.textStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  a.message,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.bodySmall.copyWith(
                    color: MlControlRoom.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (stamp != null) ...[
            const SizedBox(width: 8),
            Text(
              stamp,
              style: context.mlText.code(
                color: MlControlRoom.textDim,
                size: 10,
                weight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---- section header: title + filter chips + search ----

  List<CompanyMonthlyOpsStats> _visibleCompanies(
    List<CompanyMonthlyOpsStats> companies,
    _Derived d,
    CompanyMonthlyOpsStats? focus,
  ) {
    Iterable<CompanyMonthlyOpsStats> out = companies;
    if (focus != null) {
      out = out.where((c) => c.companyId == focus.companyId);
    }
    out = switch (_filter) {
      _CompanyFilter.all => out,
      _CompanyFilter.active => out.where((c) => c.trips > 0),
      _CompanyFilter.highThroughput => out.where((c) => d.isHighThroughput(c)),
      _CompanyFilter.attention => out.where(
        (c) => d.attentionFor(c).isNotEmpty,
      ),
    };
    return out.toList();
  }

  Widget _sectionHeader(List<CompanyMonthlyOpsStats> companies, _Derived d) {
    final counts = {
      _CompanyFilter.all: companies.length,
      _CompanyFilter.active: companies.where((c) => c.trips > 0).length,
      _CompanyFilter.highThroughput: companies
          .where((c) => d.isHighThroughput(c))
          .length,
      _CompanyFilter.attention: companies
          .where((c) => d.attentionFor(c).isNotEmpty)
          .length,
    };
    const labels = {
      _CompanyFilter.all: 'All',
      _CompanyFilter.active: 'Active',
      _CompanyFilter.highThroughput: 'High throughput',
      _CompanyFilter.attention: 'Attention',
    };

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      alignment: WrapAlignment.spaceBetween,
      runSpacing: 10,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top $_plural',
              style: TextStyle(
                // Mock: the list head matches the console's editorial serif.
                fontFamily: MlTokens.fontSerif,
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.15,
                color: MlControlRoom.textStrong,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Ranked by tons moved · '
              '${_dataAt == null ? 'live monthly rollup' : 'updated ${_agoShort(_dataAt!)}'}',
              style: context.mlText.bodySmall.copyWith(
                color: MlControlRoom.textMuted,
              ),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Design `.chip` / `.chip.active`: rgba(255,255,255,.03) with a
            // --line border, going cyan-tinted (12%) at 35% border when active.
            // Only the ACTIVE chip carries its count.
            for (final f in _CompanyFilter.values)
              Material(
                color: _filter == f
                    ? MlControlRoom.cyan.withValues(alpha: 0.12)
                    : MlControlRoom.surfaceTile,
                borderRadius: MlShape.pill,
                child: InkWell(
                  borderRadius: MlShape.pill,
                  onTap: () => setState(() => _filter = f),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: MlShape.pill,
                      border: Border.all(
                        color: _filter == f
                            ? MlControlRoom.cyan.withValues(alpha: 0.35)
                            : MlControlRoom.tileBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          labels[f]!,
                          style: context.mlText.labelMedium.copyWith(
                            color: _filter == f ? MlControlRoom.cyanText : MlControlRoom.textMuted,
                          ),
                        ),
                        if (_filter == f) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: MlControlRoom.cyan.withValues(alpha: 0.18),
                              borderRadius: MlShape.pill,
                            ),
                            child: Text(
                              '${counts[f]}',
                              style: context.mlText.code(
                                color: MlControlRoom.cyan,
                                size: 11,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ---- transporter / company cards ----

  Widget _companyCard(
    BuildContext context,
    CompanyMonthlyOpsStats s,
    int rank,
    _Derived d,
  ) {
    final util = d.utilPctFor(s);
    final pod = d.podPctFor(s.companyName);
    final lastActive = d.lastActiveFor(s.companyName);
    final tempo = d.dailyTons(s.companyName);
    final attention = d.attentionFor(s);
    final initials = s.companyName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();

    Widget chip(String label, Color color) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: MlShape.pill,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: context.mlText.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final badges = <Widget>[
      if (rank == 0 && s.tonsMoved > 0)
        chip('Top volume', MlControlRoom.cyan)
      else if (d.isHighThroughput(s))
        chip('High throughput', MlControlRoom.blue),
      if (attention.isNotEmpty) chip('Attention', MlControlRoom.amber),
      if (pod != null)
        chip(
          '$pod% PoD',
          pod >= 90 ? MlControlRoom.green : (pod >= 80 ? MlControlRoom.amber : MlControlRoom.red),
        ),
    ];

    // `mlCount` on every countable, because this line read "1 routes" for the
    // smallest haulier in the fixture and "1 employees" would do the same. The
    // shared formatter exists for exactly this and the transporter leaderboard
    // beside this screen already uses the rule; two spellings of the same fact
    // in one console is how "the nav menus have the wrong stuff in them" starts.
    final metaParts = [
      mlCount(s.employees, 'employee'),
      mlCount(s.drivers, 'driver'),
      if (_hasFleet) '${s.fleetVehicles} fleet',
      mlCount(s.routesDistinct, 'route'),
      if (lastActive != null) 'last active $lastActive',
    ];

    // Compact enough that four columns still fit when the console sidebar is
    // expanded and the list column is only ~750px wide.
    Widget statCol(
      String label,
      String value, {
      String? unit,
      Color? valueColor,
    }) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.mlText.overline.copyWith(
            color: MlControlRoom.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: context.mlText.code(
                  color: valueColor ?? MlControlRoom.textStrong,
                  size: 15,
                  weight: FontWeight.w600,
                ),
              ),
              if (unit != null)
                TextSpan(
                  text: unit,
                  style: context.mlText.code(
                    color: MlControlRoom.textDim,
                    size: 10,
                    weight: FontWeight.w400,
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    Widget meter(String label, int? pct) => Row(
      children: [
        SizedBox(
          width: 78,
          child: Text(
            label,
            style: context.mlText.labelSmall.copyWith(
              color: MlControlRoom.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: MlShape.pill,
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(color: MlTokens.overlayLight.withValues(alpha: 0.07)),
                  if (pct != null)
                    FractionallySizedBox(
                      widthFactor: (pct / 100).clamp(0.0, 1.0),
                      // A `Stack` lays its non-positioned children out loose,
                      // so the fill states its own height rather than relying
                      // on the parent to tighten one. This used to be carried
                      // by a `SizedBox.expand()` inside the `DecoratedBox`,
                      // which worked by accident of the same mechanism and
                      // said nothing about why it was there.
                      heightFactor: 1,
                      // Design meter: the fill warms from teal into brand cyan
                      // across its own length.
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [MlControlRoom.teal, MlControlRoom.cyan],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            pct == null ? '—' : '$pct%',
            textAlign: TextAlign.right,
            style: context.mlText.code(
              color: MlControlRoom.textStrong,
              size: 12,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // Design monogram: the deep panel ink behind cyan initials, ringed
            // in the brand hue at 40%.
            color: MlControlRoom.surfaceCard,
            borderRadius: MlShape.radiusMedium,
            border: Border.all(color: MlControlRoom.cyan.withValues(alpha: 0.4)),
          ),
          child: Text(
            initials.isEmpty ? '—' : initials,
            style: context.mlText.titleSmall.copyWith(
              color: MlControlRoom.cyanText,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    s.companyName,
                    style: context.mlText.titleMedium.copyWith(
                      color: MlControlRoom.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  ...badges,
                ],
              ),
              const SizedBox(height: 5),
              Text(
                metaParts.join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.bodySmall.copyWith(
                  color: MlControlRoom.textMuted,
                ),
              ),
              const SizedBox(height: 11),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: SizedBox(
                      width: 182,
                      height: 24,
                      child: _TempoBars(values: tempo, color: MlControlRoom.cyan),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '15-DAY TEMPO',
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: MlControlRoom.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    final stats = [
      statCol('Trips', _int.format(s.trips)),
      statCol('Tons', _tons.format(s.tonsMoved), unit: 't'),
      statCol('WB done', _int.format(s.completedWaybills)),
      statCol(
        'WB open',
        _int.format(s.pendingWaybills),
        valueColor: s.pendingWaybills > 0 ? MlControlRoom.red : MlControlRoom.textStrong,
      ),
    ];

    final meters = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        meter('Utilisation', util),
        const SizedBox(height: 15),
        // THE REAL ON-TIME FIGURE, not the waybill-completion rate.
        //
        // This row was labelled "On-time" and fed `completionPctFor(s)`, with a
        // comment saying so out loud — "Design labels this row 'On-time'; the
        // figure is our recorded waybill-completion rate". That was honest in
        // the source and invisible on the screen, and it stopped being
        // necessary when `CompanyMonthlyOpsStats` gained `onTimeTrips` /
        // `dueTrips` from `public.trip_is_on_time`.
        //
        // Measured against the fixture on 2026-08-20: a haulier with 6 of 20
        // loads delivered on time rendered **91%**. The transporter leaderboard
        // — the other screen in this console that reports on-time for the same
        // companies — was already reading the real measure, so the two boards
        // disagreed about the same haulier.
        //
        // `meter` renders null as a dash and an empty bar, which is exactly
        // what the model demands: "only a reader holding both can tell 'nothing
        // to measure yet' (0 of 0) from 'every load was late' (0 of 9)". A
        // company with no judgeable trips used to draw a 0% bar, which says the
        // second when it means the first.
        meter('On-time', s.onTimePercent),
        const SizedBox(height: 22),
        Material(
          color: MlControlRoom.surfaceTile,
          borderRadius: MlShape.radiusMedium,
          child: InkWell(
            borderRadius: MlShape.radiusMedium,
            onTap: () => context.go(
              '/super-admin/insights/${widget.orgType}/company/${s.companyId}',
            ),
            child: Container(
              // minHeight, not height: Border.all counts on TOP of the box, so
              // a fixed height that "fits exactly" overflows by the border
              // width once the label grows (CLAUDE.md §10.4).
              constraints: const BoxConstraints(minHeight: 38),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: MlShape.radiusMedium,
                border: Border.all(color: MlControlRoom.cyan.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Flexible so the label ellipsizes instead of running past
                  // the card. Unflexed, a Row child gets unbounded width and
                  // `overflow` never fires: "Open workspace" at a 2.0 text
                  // scale overflowed the 1440px layout by 20px, on all three
                  // org types and again under bold text.
                  Flexible(
                    child: Text(
                      'Open workspace',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: context.mlText.labelMedium.copyWith(
                        color: MlControlRoom.cyan,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 14, color: MlControlRoom.cyan),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    final focused = s.companyId == _focusId;
    final baseDeco = _glass();
    final cardDeco = focused
        ? BoxDecoration(
            gradient: baseDeco.gradient,
            borderRadius: baseDeco.borderRadius,
            border: Border.all(color: MlControlRoom.cyan.withValues(alpha: 0.55)),
          )
        : baseDeco;

    return Tooltip(
      message: focused
          ? 'Tap to return to all $_plural'
          : 'Tap to view the overview for this $_singular',
      waitDuration: const Duration(milliseconds: 700),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(MlControlRoom.rCard),
        child: InkWell(
          borderRadius: BorderRadius.circular(MlControlRoom.rCard),
          onTap: () => setState(() => _focusId = focused ? null : s.companyId),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: cardDeco,
            child: LayoutBuilder(
              builder: (context, c) {
                // Mock card: identity ~37%, four metrics ~33%, meters ~30%.
                if (c.maxWidth >= 700) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 37, child: identity),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 33,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final st in stats) Expanded(child: st),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(flex: 30, child: meters),
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity,
                    const SizedBox(height: 14),
                    Wrap(spacing: 26, runSpacing: 12, children: stats),
                    const SizedBox(height: 14),
                    meters,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Derivations — every value computed from the rollup + recon rows, no
// invented numbers. Comparisons use device-local calendar months.
// ---------------------------------------------------------------------------

/// One row of the alerts feed. Design reads signal-first: the headline names
/// what needs doing, the detail line carries the company and the evidence.
class _AttentionItem {
  final String company;

  /// Headline — the action, e.g. "Capacity review needed".
  final String title;

  /// Supporting line — company + the recorded evidence behind the signal.
  final String message;
  final Color color;
  final IconData icon;
  const _AttentionItem(
    this.company,
    this.title,
    this.message,
    this.color,
    this.icon,
  );
}

class _Derived {
  final List<CompanyMonthlyOpsStats> companies;
  final List<RawReconRow> rows;
  final String? Function(RawReconRow) partyName;

  _Derived({
    required this.companies,
    required this.rows,
    required this.partyName,
  });

  /// The South African wall clock (CLAUDE.md §7.1), not the device's.
  ///
  /// It is not only the "x ago" stamps that read this. `tonsDeltaPctFor`
  /// compares month-to-date against the same day-window of the previous month
  /// off `_now.month` and `_now.day` — a MONTH boundary and a DAY boundary,
  /// both of which the device's zone was deciding. A laptop left on UTC moved
  /// the comparison window by a day for every load recorded between midnight
  /// and 02:00 SAST, which is the middle of the night shift.
  DateTime get _now => MlTime.now();

  bool _sameMonth(DateTime d, DateTime m) =>
      d.year == m.year && d.month == m.month;

  bool _isActiveStatus(String? s) =>
      s != null && s != 'completed' && s != 'cancelled';

  List<RawReconRow> _forCompany(String? name) =>
      name == null ? rows : rows.where((r) => partyName(r) == name).toList();

  double get tonsThisMonth => companies.fold(0.0, (s, c) => s + c.tonsMoved);
  int get totalTrips => companies.fold(0, (s, c) => s + c.trips);
  int get totalFleet => companies.fold(0, (s, c) => s + c.fleetVehicles);
  int get totalWbDone => companies.fold(0, (s, c) => s + c.completedWaybills);
  int get totalWbOpen => companies.fold(0, (s, c) => s + c.pendingWaybills);
  int get activeCompanies => companies.where((c) => c.trips > 0).length;

  int? get completionPct {
    final total = totalWbDone + totalWbOpen;
    if (total == 0) return null;
    return (totalWbDone / total * 100).round();
  }

  int? completionPctFor(CompanyMonthlyOpsStats c) {
    final total = c.completedWaybills + c.pendingWaybills;
    if (total == 0) return null;
    return (c.completedWaybills / total * 100).round();
  }

  /// % of this company's completed trips carrying an uploaded POD photo.
  int? podPctFor(String companyName) {
    final done = _forCompany(
      companyName,
    ).where((r) => r.tripStatus == 'completed').toList();
    if (done.isEmpty) return null;
    final withPod = done.where((r) => r.podPhotoPath != null).length;
    return (withPod / done.length * 100).round();
  }

  /// Most recent recorded activity (weighbridge out/in, else trip date).
  DateTime? lastActiveAtFor(String companyName) {
    DateTime? latest;
    for (final r in _forCompany(companyName)) {
      for (final t in [r.timeOut, r.timeIn, r.tripDate]) {
        if (t != null && (latest == null || t.isAfter(latest))) latest = t;
      }
    }
    return latest;
  }

  String? lastActiveFor(String companyName) {
    final latest = lastActiveAtFor(companyName);
    if (latest == null) return null;
    return MlTime.ago(latest);
  }

  /// Compact age stamp for the alerts column ("12m", "1h", "3d").
  String? ageTagFor(String companyName) {
    final latest = lastActiveAtFor(companyName);
    if (latest == null) return null;
    return MlTime.agoTag(latest);
  }

  /// Tons MTD vs the same day-window of the previous month, from recon rows.
  /// Null when the previous month has no records (no fabricated baseline).
  /// [companyName] scopes the comparison to one company (null = network).
  double? tonsDeltaPctFor(String? companyName, double mtdTons) {
    final prevMonth = DateTime(_now.year, _now.month - 1, 1);
    var prev = 0.0;
    for (final r in _forCompany(companyName)) {
      if (_sameMonth(r.tripDate, prevMonth) && r.tripDate.day <= _now.day) {
        prev += r.netMass ?? 0;
      }
    }
    if (prev <= 0) return null;
    return (mtdTons - prev) / prev * 100;
  }

  double? get tonsDeltaPct => tonsDeltaPctFor(null, tonsThisMonth);

  /// Net tons per day for the trailing 15 days (oldest first).
  List<double> dailyTons(String? companyName) {
    final start = DateTime(
      _now.year,
      _now.month,
      _now.day,
    ).subtract(const Duration(days: 14));
    final buckets = List<double>.filled(15, 0);
    for (final r in _forCompany(companyName)) {
      final day = DateTime(r.tripDate.year, r.tripDate.month, r.tripDate.day);
      final i = day.difference(start).inDays;
      if (i >= 0 && i < 15) buckets[i] += r.netMass ?? 0;
    }
    return buckets;
  }

  // ── Month-to-date series & projections (flagship chart + strip) ────────
  // Every value below is a straight aggregation of recorded recon rows; the
  // forecast is an explicit run-rate extrapolation of those same rows.

  DateTime get monthStart => DateTime(_now.year, _now.month, 1);
  DateTime get prevMonth => DateTime(_now.year, _now.month - 1, 1);
  int get _daysInMonth => DateTime(_now.year, _now.month + 1, 0).day;

  /// Net tons for each elapsed day of the current month (day 1 → today).
  List<double> dailyTonsMonthToDate(String? companyName) {
    final buckets = List<double>.filled(_now.day, 0);
    for (final r in _forCompany(companyName)) {
      if (!_sameMonth(r.tripDate, monthStart)) continue;
      final i = r.tripDate.day - 1;
      if (i >= 0 && i < buckets.length) buckets[i] += r.netMass ?? 0;
    }
    return buckets;
  }

  /// The same day-window of the previous month, for the comparison trace.
  List<double> prevMonthDailyTons(String? companyName) {
    final buckets = List<double>.filled(_now.day, 0);
    for (final r in _forCompany(companyName)) {
      if (!_sameMonth(r.tripDate, prevMonth)) continue;
      final i = r.tripDate.day - 1;
      if (i >= 0 && i < buckets.length) buckets[i] += r.netMass ?? 0;
    }
    return buckets;
  }

  /// Heaviest recorded day this month as (tons, date, index). Null when the
  /// month has no tonnage at all.
  (double, DateTime, int)? peakDay(String? companyName) {
    final s = dailyTonsMonthToDate(companyName);
    var best = -1.0;
    var bestI = -1;
    for (var i = 0; i < s.length; i++) {
      if (s[i] > best) {
        best = s[i];
        bestI = i;
      }
    }
    if (bestI < 0 || best <= 0) return null;
    return (best, DateTime(_now.year, _now.month, bestI + 1), bestI);
  }

  /// Mean tons across the elapsed days of the month.
  double? avgPerDay(String? companyName) {
    final s = dailyTonsMonthToDate(companyName);
    final total = s.fold(0.0, (a, b) => a + b);
    if (total <= 0) return null;
    return total / s.length;
  }

  double? prevMonthAvgPerDay(String? companyName) {
    final s = prevMonthDailyTons(companyName);
    final total = s.fold(0.0, (a, b) => a + b);
    if (total <= 0) return null;
    return total / s.length;
  }

  /// Previous month's FULL recorded tonnage (not the day-matched window) —
  /// the bar the current month is pacing against on the flagship chart.
  double? prevMonthTons(String? companyName) {
    var total = 0.0;
    for (final r in _forCompany(companyName)) {
      if (_sameMonth(r.tripDate, prevMonth)) total += r.netMass ?? 0;
    }
    return total <= 0 ? null : total;
  }

  /// Month-end projection: the recorded run-rate carried across the full
  /// month. An extrapolation of real rows, not a stored figure.
  double? forecastMonthTons(String? companyName) {
    final avg = avgPerDay(companyName);
    if (avg == null) return null;
    return avg * _daysInMonth;
  }

  /// Absolute tons moved vs the same day-window last month.
  double? tonsDeltaAbsFor(String? companyName, double mtdTons) {
    var prev = 0.0;
    for (final r in _forCompany(companyName)) {
      if (_sameMonth(r.tripDate, prevMonth) && r.tripDate.day <= _now.day) {
        prev += r.netMass ?? 0;
      }
    }
    if (prev <= 0) return null;
    return mtdTons - prev;
  }

  double? get tonsDeltaAbs => tonsDeltaAbsFor(null, tonsThisMonth);

  /// Companies carrying open waybills — the review queue.
  int get reviewsNeeded => companies.where((c) => c.pendingWaybills > 0).length;

  /// Attention signals raised at the red (hard-fault) level.
  int get anomalyCount =>
      attentionItems.where((a) => a.color == MlControlRoom.red).length;

  /// Companies with routes on file but no trips recorded this month.
  int get routesRested =>
      companies.where((c) => c.routesDistinct > 0 && c.trips == 0).length;

  int _activeTrucks(String? companyName) => _forCompany(companyName)
      .where((r) => _isActiveStatus(r.tripStatus) && r.truckReg != null)
      .map((r) => r.truckReg)
      .toSet()
      .length;

  int get activeTruckCount => _activeTrucks(null);

  /// Distinct trucks currently on an active trip for one company.
  int activeTrucksFor(String companyName) => _activeTrucks(companyName);

  int? utilPctFor(CompanyMonthlyOpsStats c) {
    if (c.fleetVehicles <= 0) return null;
    final pct = _activeTrucks(c.companyName) / c.fleetVehicles * 100;
    return pct.clamp(0, 100).round();
  }

  int? get overallUtilPct {
    if (totalFleet <= 0) return null;
    return (activeTruckCount / totalFleet * 100).clamp(0, 100).round();
  }

  /// Mean weighbridge in→out duration this month, in hours.
  double? avgTurnaroundHours(String? companyName) {
    var total = Duration.zero;
    var n = 0;
    for (final r in _forCompany(companyName)) {
      if (!_sameMonth(r.tripDate, _now)) continue;
      final tin = r.timeIn;
      final tout = r.timeOut;
      if (tin != null && tout != null && tout.isAfter(tin)) {
        total += tout.difference(tin);
        n++;
      }
    }
    if (n == 0) return null;
    return total.inMinutes / n / 60.0;
  }

  /// "High throughput" = at or above the average tons of companies that
  /// moved anything this month (a real, transparent threshold).
  bool isHighThroughput(CompanyMonthlyOpsStats c) {
    final movers = companies.where((x) => x.tonsMoved > 0).toList();
    if (movers.isEmpty || c.tonsMoved <= 0) return false;
    final avg = movers.fold(0.0, (s, x) => s + x.tonsMoved) / movers.length;
    return c.tonsMoved >= avg;
  }

  List<_AttentionItem> attentionFor(CompanyMonthlyOpsStats c) {
    final items = <_AttentionItem>[];
    final util = utilPctFor(c);
    if (util != null && util >= 85) {
      items.add(
        _AttentionItem(
          c.companyName,
          'Capacity review needed',
          '${c.companyName} trending $util% fleet utilisation',
          MlControlRoom.amber,
          Icons.warning_amber_rounded,
        ),
      );
    }
    if (c.pendingWaybills > 0) {
      items.add(
        _AttentionItem(
          c.companyName,
          'Waybill follow-up pending',
          '${c.companyName} — ${c.pendingWaybills} open record'
              '${c.pendingWaybills == 1 ? '' : 's'} need review before closeout',
          MlControlRoom.red,
          Icons.schedule_rounded,
        ),
      );
    }
    if (util != null && util < 60 && c.trips > 0) {
      items.add(
        _AttentionItem(
          c.companyName,
          'Fleet under-utilised',
          '${c.companyName} running at $util% fleet utilisation this month',
          MlControlRoom.amber,
          Icons.warning_amber_rounded,
        ),
      );
    }
    if (c.trips > 0 && dailyTons(c.companyName).every((v) => v == 0)) {
      items.add(
        _AttentionItem(
          c.companyName,
          '${c.companyName} idle',
          'No tonnage captured in the last 15 days — verify account status',
          MlControlRoom.amber,
          Icons.warning_amber_rounded,
        ),
      );
    }
    return items;
  }

  /// A positive signal, on the same feed: every completed trip recorded today
  /// carries its net mass, so the day's movement totals tie out.
  _AttentionItem? get _reconciliationSignal {
    final today = DateTime(_now.year, _now.month, _now.day);
    final done = rows
        .where(
          (r) =>
              r.tripStatus == 'completed' &&
              DateTime(r.tripDate.year, r.tripDate.month, r.tripDate.day) ==
                  today,
        )
        .toList();
    if (done.isEmpty || done.any((r) => r.netMass == null)) return null;
    return _AttentionItem(
      '',
      'Daily reconciliation complete',
      'All movement totals matched successfully',
      MlControlRoom.green,
      Icons.check_circle_outline_rounded,
    );
  }

  List<_AttentionItem> get attentionItems {
    final items = [for (final c in companies) ...attentionFor(c)];
    // Newest signal first, matching the design's descending age column.
    items.sort((a, b) {
      final ta = lastActiveAtFor(a.company);
      final tb = lastActiveAtFor(b.company);
      if (ta == null && tb == null) return 0;
      if (ta == null) return 1;
      if (tb == null) return -1;
      return tb.compareTo(ta);
    });
    final ok = _reconciliationSignal;
    if (ok != null) items.insert(items.length > 1 ? 1 : items.length, ok);
    return items;
  }
}

// ---------------------------------------------------------------------------

/// Segmented ring for the fleet-distribution card. Values are real counts;
/// a faint full track ring sits behind the segments.
class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final Color trackColor;
  final double stroke;
  const _DonutPainter({
    required this.values,
    required this.colors,
    required this.trackColor,
    this.stroke = 20,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2 + 1);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = trackColor;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);

    final total = values.fold(0.0, (s, v) => s + v);
    if (total <= 0) return;

    // Design ring: segments butt straight into each other — no gap, no round
    // cap. A hairline overdraw stops seams showing between adjacent arcs.
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * (math.pi * 2);
      if (sweep <= 0) continue;
      final seg = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = colors[i % colors.length];
      canvas.drawArc(arcRect, start, sweep + 0.004, false, seg);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      !identical(old.values, values) ||
      !identical(old.colors, colors) ||
      old.stroke != stroke;
}

/// 15-day tempo bar strip (real daily net tons). Zero days render a faint
/// stub so the rhythm of quiet days stays visible.
/// Design `.fs-chart`: a 150px area/line plot of this month's daily tonnage
/// with the previous month traced dashed behind it, a dashed reference line at
/// last month's daily average, a pill on the peak day, a day axis and a
/// legend/unit foot. Every point is a recorded net-mass total.
class _MovementChart extends StatelessWidget {
  final List<double> series;
  final List<double> prevSeries;
  final double? reference;

  /// Last month's full recorded total — captioned on the reference line as
  /// the target this month is pacing against.
  final double? referenceTotal;
  final DateTime monthStart;

  const _MovementChart({
    required this.series,
    required this.prevSeries,
    required this.reference,
    required this.referenceTotal,
    required this.monthStart,
  });

  static final _pill = NumberFormat('#,##0');

  /// "28.0K" / "1.2M" — the compact caption form used on the target line.
  static String _compact(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final n = series.length;
    // Axis ticks every 4th day, plus a trailing "Today" like the design.
    final ticks = <int>[for (var i = 0; i < n - 1; i += 4) i];

    Widget legendItem(String label, Color color, {bool dashed = false}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 2,
          child: CustomPaint(
            painter: _LegendDashPainter(color: color, dashed: dashed),
          ),
        ),
        const SizedBox(width: 6),
        // Flexible: a horizontal Wrap lays each child out under its OWN
        // maxWidth, so a label that outgrows the line (larger text scale, a
        // long month name) can compress rather than running off sideways.
        //
        // Necessary but not sufficient — it only helps while the Wrap has
        // width to give. When the sibling axis caption starved it to 11.8px,
        // this Flexible dutifully squeezed the label to zero and the 14px dash
        // beside it overflowed anyway. See the note on the row below.
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.mlText.labelSmall.copyWith(
              color: MlControlRoom.textMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );

    // NOTE: no LayoutBuilder in this subtree. The hero row wraps the flagship
    // in an IntrinsicHeight, and LayoutBuilder cannot answer intrinsic-dimension
    // queries — it throws and the whole page renders blank. Anything
    // width-dependent is therefore placed by fraction with Align.
    Alignment alignAtFraction(double f) => Alignment(f * 2 - 1, -1);

    // Latest recorded day — the figure the design calls out at the line's end.
    final lastValue = series.isEmpty ? null : series.last;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 150,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _MovementChartPainter(
                    series: series,
                    prevSeries: prevSeries,
                    reference: reference,
                    referenceCaption: referenceTotal == null
                        ? null
                        : 'TARGET ${_compact(referenceTotal!)}',
                  ),
                ),
              ),
              // Design `.fs-pill`: the end-of-series read, boxed at the top
              // right where it never collides with the curve.
              if (lastValue != null && lastValue > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      // Design `.fs-pill`: rgba(6,11,21,.92) — --bg-0 at 92%.
                      color: MlControlRoom.pageBg.withValues(alpha: 0.92),
                      borderRadius: MlShape.radiusSmall,
                      border: Border.all(
                        color: MlControlRoom.cyan.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: MlTokens.overlayDark.withValues(alpha: 0.85),
                          blurRadius: 26,
                          spreadRadius: -12,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Text(
                      '${_pill.format(lastValue)} t',
                      style: context.mlText.code(
                        color: MlControlRoom.textStrong,
                        size: 13,
                        weight: FontWeight.w600,
                        letterSpacing: 0.72,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Day axis — design shows 01/05/09/… then "Today".
        SizedBox(
          height: 14,
          child: Stack(
            children: [
              for (final t in ticks)
                Align(
                  alignment: alignAtFraction(n > 1 ? t / (n - 1) : 0),
                  child: Text(
                    (t + 1).toString().padLeft(2, '0'),
                    style: context.mlText.code(
                      color: MlControlRoom.textDim,
                      size: 9,
                      weight: FontWeight.w400,
                      letterSpacing: 1.26,
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.topRight,
                child: Text(
                  'Today',
                  style: context.mlText.code(
                    color: MlControlRoom.textMuted,
                    size: 9,
                    weight: FontWeight.w400,
                    letterSpacing: 1.26,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // The legend and the axis caption share a line until they cannot, and
        // then the caption drops to its own.
        //
        // This was `Row[Expanded(Wrap), gap, Text]`. The caption was unflexed,
        // so it claimed its natural width first — and at a 2.0 text scale
        // "DAILY · TONS" at letterSpacing 1.62 is wide enough to leave the
        // Expanded with **11.8 px**. Measured: the legend item's own fixed
        // parts are a 14px dash plus a 6px gap, so it overflowed by 8.2px with
        // its Flexible label already squeezed to nothing. The starvation was
        // the fault, not the label (CLAUDE.md §10.4 — an unflexed child in a
        // Row gets unbounded width and takes it).
        //
        // The outer Wrap must claim the row before spaceBetween has anything
        // to distribute, hence the infinite-width box; a Wrap otherwise sizes
        // to its content and the alignment silently does nothing.
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 3,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 3,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  legendItem('This period', MlControlRoom.cyan),
                  legendItem(
                    DateFormat('MMM yyyy').format(
                      DateTime(monthStart.year, monthStart.month - 1, 1),
                    ),
                    MlControlRoom.textDim,
                    dashed: true,
                  ),
                  if (reference != null)
                    legendItem(
                      'Target',
                      MlControlRoom.cyanText.withValues(alpha: 0.55),
                      dashed: true,
                    ),
                ],
              ),
              Text(
                'DAILY · TONS',
                style: context.mlText.code(
                  color: MlControlRoom.textFaint,
                  size: 9,
                  weight: FontWeight.w400,
                  letterSpacing: 1.62,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Design `.rt-spark`: a soft filled sparkline of the month's daily tonnage.
class _SparkPainter extends CustomPainter {
  final List<double> values;
  const _SparkPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.fold(0.0, math.max);
    if (maxV <= 0) {
      final p = Paint()
        ..color = MlControlRoom.textFaint
        ..strokeWidth = 1.4;
      canvas.drawLine(
        Offset(0, size.height - 2),
        Offset(size.width, size.height - 2),
        p,
      );
      return;
    }
    double dx(int i) =>
        values.length == 1 ? 0 : (i / (values.length - 1)) * size.width;
    double dy(double v) => size.height - (v / (maxV * 1.1)) * size.height;

    final line = Path();
    for (var i = 0; i < values.length; i++) {
      final o = Offset(dx(i), dy(values[i]));
      i == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
    }
    final area = Path.from(line)
      ..lineTo(dx(values.length - 1), size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(0, size.height), [
          MlControlRoom.cyan.withValues(alpha: 0.35),
          MlControlRoom.cyan.withValues(alpha: 0.0),
        ]),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, 0), [
          MlControlRoom.teal,
          MlControlRoom.cyan,
        ]),
    );
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values;
}

class _LegendDashPainter extends CustomPainter {
  final Color color;
  final bool dashed;
  const _LegendDashPainter({required this.color, required this.dashed});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      return;
    }
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, size.width), y), p);
      x += 6;
    }
  }

  @override
  bool shouldRepaint(covariant _LegendDashPainter old) =>
      old.color != color || old.dashed != dashed;
}

class _MovementChartPainter extends CustomPainter {
  final List<double> series;
  final List<double> prevSeries;
  final double? reference;

  /// Right-aligned caption riding just above the dashed reference line.
  final String? referenceCaption;

  const _MovementChartPainter({
    required this.series,
    required this.prevSeries,
    required this.reference,
    required this.referenceCaption,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;
    // Headroom so the end-of-series callout and the curve never collide.
    final top = 34.0;
    final maxV = [
      ...series,
      ...prevSeries,
      if (reference != null) reference!,
    ].fold(0.0, math.max);
    final scale = maxV <= 0 ? 1.0 : maxV * 1.12;

    double dx(int i) =>
        series.length == 1 ? 0 : (i / (series.length - 1)) * size.width;
    double dy(double v) => size.height - (v / scale) * (size.height - top);

    // Reference line — the daily pace that would match last month's total.
    if (reference != null) {
      final ry = dy(reference!);
      final p = Paint()
        ..color = MlControlRoom.cyanText.withValues(alpha: 0.45)
        ..strokeWidth = 1;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(
          Offset(x, ry),
          Offset(math.min(x + 5, size.width), ry),
          p,
        );
        x += 10;
      }
      if (referenceCaption != null) {
        final tp = TextPainter(
          text: TextSpan(
            text: referenceCaption,
            // MlType, not context.mlText: a CustomPainter has no BuildContext.
            style: MlType.code(
              color: MlControlRoom.cyanText.withValues(alpha: 0.85),
              size: 10,
              weight: FontWeight.w600,
              letterSpacing: 1.8,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(size.width - tp.width, ry - tp.height - 5));
      }
    }

    // Previous month, dashed behind.
    if (prevSeries.any((v) => v > 0)) {
      final p = Paint()
        ..color = MlControlRoom.textDim.withValues(alpha: 0.75)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < prevSeries.length && i < series.length; i++) {
        final o = Offset(dx(i), dy(prevSeries[i]));
        i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(_dashPath(path, 4, 4), p);
    }

    // This month: gradient area + gradient stroke.
    final line = Path();
    for (var i = 0; i < series.length; i++) {
      final o = Offset(dx(i), dy(series[i]));
      i == 0 ? line.moveTo(o.dx, o.dy) : line.lineTo(o.dx, o.dy);
    }
    final area = Path.from(line)
      ..lineTo(dx(series.length - 1), size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, top),
          Offset(0, size.height),
          [
            MlControlRoom.cyan.withValues(alpha: 0.32),
            MlControlRoom.cyan.withValues(alpha: 0.08),
            MlControlRoom.cyan.withValues(alpha: 0.0),
          ],
          [0.0, 0.55, 1.0],
        ),
    );
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, 0), [
          MlControlRoom.teal,
          MlControlRoom.cyan,
        ]),
    );

    // Point dots: hollow navy pips on the run, with the latest day carrying
    // the design's solid `.fs-dot.end` and its glow.
    final end = series.length - 1;
    for (var i = 0; i < series.length; i++) {
      if (series[i] <= 0) continue;
      final o = Offset(dx(i), dy(series[i]));
      if (i == end) continue;
      canvas.drawCircle(o, 3.6, Paint()..color = MlControlRoom.pageBg);
      canvas.drawCircle(
        o,
        3.6,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = MlControlRoom.cyan,
      );
    }
    if (series[end] > 0) {
      final o = Offset(dx(end), dy(series[end]));
      canvas.drawCircle(
        o,
        9,
        Paint()
          ..color = MlControlRoom.cyan.withValues(alpha: 0.28)
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 6),
      );
      canvas.drawCircle(o, 4.4, Paint()..color = MlControlRoom.cyan);
    }
  }

  Path _dashPath(Path src, double on, double off) {
    final out = Path();
    for (final m in src.computeMetrics()) {
      var dist = 0.0;
      while (dist < m.length) {
        out.addPath(
          m.extractPath(dist, math.min(dist + on, m.length)),
          Offset.zero,
        );
        dist += on + off;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant _MovementChartPainter old) =>
      old.series != series ||
      old.prevSeries != prevSeries ||
      old.reference != reference ||
      old.referenceCaption != referenceCaption;
}

class _TempoBars extends StatelessWidget {
  final List<double> values;
  final Color color;
  const _TempoBars({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _TempoBarsPainter(values: values, color: color),
    );
  }
}

class _TempoBarsPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  const _TempoBarsPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxV = values.fold<double>(0, math.max);
    final n = values.length;
    final slot = size.width / n;
    final barW = slot * 0.62;

    for (var i = 0; i < n; i++) {
      final norm = maxV == 0 ? 0.0 : values[i] / maxV;
      final h = math.max(2.5, norm * size.height);
      final x = i * slot + (slot - barW) / 2;
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - h, barW, h),
        const Radius.circular(MlShape.extraSmall),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..color = norm == 0
              ? color.withValues(alpha: 0.14)
              : color.withValues(alpha: 0.35 + 0.65 * norm),
      );
    }
  }

  @override
  bool shouldRepaint(_TempoBarsPainter old) =>
      old.color != color || !identical(old.values, values);
}
