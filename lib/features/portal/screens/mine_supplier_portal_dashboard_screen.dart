import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/operations/models/operations_models.dart';
import 'package:flutter_application_1/features/portal/models/mine_trip.dart';
import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_entry.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/features/portal/widgets/available_routes_section.dart';
import 'package:flutter_application_1/features/portal/widgets/dashboard/portal_dashboard_kit.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/super_admin/data/models/target_scope.dart';
import 'package:flutter_application_1/features/super_admin/providers/targets_provider.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_charts.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// The Mine / Supplier dashboard (P7-20, P7-21, P7-24, P7-25).
///
/// Six bands, in the order the mine actually works: what moved (KPIs), the
/// shape of it (trend + stockpile ring), what is waiting (action queue), what
/// is on the ground right now (live strip), and what was captured (recent
/// waybills). Every tile opens the screen that produced its number.
///
/// Two things this rebuild deliberately removed:
///
/// * **The second dashboard.** A user setting (`mineAppearanceProvider`)
///   swapped the whole page for `PremiumMineDashboard` — 1,596 lines of a
///   fourth dashboard, DELETED 2026-08-14 (S5-16). It was already unreachable:
///   no file imported it. Kept in git history if it is ever wanted back.
///   parallel mine dashboard matching neither this page nor the console. One
///   product cannot have two dashboards chosen by a theme picker; they drift,
///   and only one of them ever gets a fix.
/// * **The "Live operational records" coming-soon card** (P8-06/P7-25).
///
/// Nothing here is hardcoded. Where a figure is genuinely unavailable the tile
/// renders a dash and says why — never a zero, and never an invented series.
class MineSupplierPortalDashboardScreen extends ConsumerStatefulWidget {
  const MineSupplierPortalDashboardScreen({super.key});

  @override
  ConsumerState<MineSupplierPortalDashboardScreen> createState() =>
      _MineSupplierPortalDashboardScreenState();
}

class _MineSupplierPortalDashboardScreenState
    extends ConsumerState<MineSupplierPortalDashboardScreen> {
  PortalPeriod _period = PortalPeriod.week;

  @override
  Widget build(BuildContext context) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const MlEmptyState(
        icon: Icons.domain_disabled_outlined,
        title: 'Company not loaded',
        message: 'Your account is not linked to a mine yet, so there is '
            'nothing to report on.',
      );
    }

    final logistics = ref.watch(logisticsSnapshotProvider(companyId));

    return logistics.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load the dashboard',
        message: friendlyError(e),
        action: MlButton.tonal(
          label: 'Try again',
          icon: Icons.refresh_rounded,
          onPressed: () =>
              ref.invalidate(logisticsSnapshotProvider(companyId)),
        ),
      ),
      data: (snap) => _body(context, companyId, snap),
    );
  }

  Widget _body(
    BuildContext context,
    String companyId,
    LogisticsSnapshot snap,
  ) {
    // The pit clock, not the reader's laptop — every figure below
    // is bucketed against this.
    final now = MlTime.now();
    final mirror = portalMirrorActive(ref);

    // ---- the figures, all from live rows -----------------------------------
    final tonsByDay = _tonsByDay(snap.waybills, now);
    final current = _window(tonsByDay, now, _period.days, 0);
    final previous = _window(tonsByDay, now, _period.days, _period.days);
    final tons = current.fold<double>(0, (a, b) => a + b);
    final priorTons = previous.fold<double>(0, (a, b) => a + b);

    final stockpiles =
        ref.watch(stockpilesProvider(companyId)).valueOrNull;
    // The AsyncValue is kept, not just its value: the action queue has to tell
    // "still reading" from "could not read", and `valueOrNull` collapses both
    // to null. See `PortalQueueItem.loading`.
    final inboundAsync = ref.watch(mineInboundTripsProvider(companyId));
    final requestsAsync = ref.watch(companyRequestsProvider(companyId));
    final disputesAsync = ref.watch(reconDisputesProvider(companyId));
    final inbound = inboundAsync.valueOrNull;
    final requests = requestsAsync.valueOrNull;
    final disputes = disputesAsync.valueOrNull;

    // Total tons on the ground, every pile — the honest headline figure.
    final balance = stockpiles?.fold<double>(0, (a, s) => a + s.tons);

    // Capacity only counts piles that HAVE a cap — a production pile has none,
    // and folding it in as zero would report the mine as over capacity.
    final capped = stockpiles?.where((s) => s.maxCapTons != null).toList();
    final capacity = capped == null || capped.isEmpty
        ? null
        : capped.fold<double>(0, (a, s) => a + s.maxCapTons!);

    // The NUMERATOR has to be scoped the same way the denominator above
    // already is, and it was not. `balance` sums every pile, including ROM
    // production piles, and it was being divided by a cap that counts only
    // order piles — so a mine with a 400 t ROM pile against a 200 t order read
    // "300% of ordered cap". The comment three lines up shows the exclusion was
    // understood; it was applied to one side of the ratio only.
    //
    // Found by rendering the screen. It was invisible for as long as the
    // capture produced an error card, and it is invisible in production TODAY
    // only because no live pile has `max_cap_tons` set (checked 2026-08-15:
    // 3 piles across 2 mines, every cap null) — so the ratio never runs. It
    // fires the first time an order is dispatched, since `link_and_dispatch_
    // request` mints the pile WITH a cap.
    final cappedBalance = capped == null || capped.isEmpty
        ? null
        : capped.fold<double>(0, (a, s) => a + s.tons);

    final arrivals = inbound?.where((t) => t.isInbound).length;
    final awaitingWeigh = inbound?.where((t) => t.isOnSite).length;

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PortalDashboardHeader(
            title: 'Mine overview',
            subtitle: 'Tons out, stockpile cover and the mine floor — live, '
                'over the last ${_period.label.toLowerCase()}.',
            period: _period,
            onPeriodChanged: (p) => setState(() => _period = p),
            actions: [
              MlButton.tonal(
                label: 'Recon tables',
                icon: Icons.table_chart_outlined,
                compact: true,
                onPressed: () => context.go('/portal/mine/tons-out'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ---- band 1: KPI row -------------------------------------------
          PortalKpiRow(
            kpis: [
              PortalKpi(
                label: 'Tons out',
                value: _tons(tons),
                unit: 't',
                sublabel: 'Weighbridge net, ${_period.label.toLowerCase()}',
                icon: Icons.scale_outlined,
                tone: MlTone.accent,
                route: '/portal/mine/tons-out',
                delta: priorTons == 0 && tons == 0 ? null : tons - priorTons,
              ),
              PortalKpi(
                label: 'Stockpile balance',
                value: balance == null ? null : _tons(balance),
                unit: 't',
                sublabel: capacity == null || capacity <= 0
                    ? 'No capped order piles'
                    : '${_tons(cappedBalance ?? 0)} of ${_tons(capacity)} t '
                        'ordered · ${((cappedBalance ?? 0) / capacity * 100).round()}%',
                icon: Icons.inventory_2_outlined,
                tone: MlTone.atMine,
                route: '/portal/mine/stockpiles',
                emptyReason: 'stockpiles unavailable',
              ),
              PortalKpi(
                label: 'Trucks inbound',
                value: arrivals?.toString(),
                sublabel: 'Scheduled or on the way to the gate',
                icon: Icons.login_rounded,
                tone: MlTone.transit,
                route: '/portal/mine/security',
                deltaGoodWhenUp: false,
                emptyReason: 'inbound queue unavailable',
              ),
              PortalKpi(
                label: 'Loads awaiting weigh',
                value: awaitingWeigh?.toString(),
                sublabel: 'Checked in, not yet loaded',
                icon: Icons.pending_actions_outlined,
                tone: MlTone.warn,
                route: '/portal/mine/weighbridge',
                deltaGoodWhenUp: false,
                emptyReason: 'weighbridge queue unavailable',
              ),
            ],
          ),
          const SizedBox(height: 26),

          // ---- band 2 + 3: trend and stockpile ring ----------------------
          LayoutBuilder(
            builder: (context, c) {
              final trend = _trendBand(context, companyId, current, previous);
              // The ring measures ORDER COVER, so it takes the capped subset —
              // the same numerator the KPI's percentage uses. It previously
              // took the all-piles `balance` and then clamped it to the cap,
              // so the ring read a tidy 100% while the card above it read
              // 193% of the same quantity: two widgets on one screen
              // disagreeing, with the clamp hiding which was wrong.
              final ring = _stockpileBand(
                  context, stockpiles, cappedBalance, capacity,
                  totalOnGround: balance);
              if (c.maxWidth < 980) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [trend, const SizedBox(height: 26), ring],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: trend),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: ring),
                ],
              );
            },
          ),
          const SizedBox(height: 26),

          // ---- band 4: action queue --------------------------------------
          PortalActionQueue(
            items: [
              PortalQueueItem(
                label: 'Arrivals to check in',
                count: arrivals,
                route: '/portal/mine/security',
                icon: Icons.login_rounded,
                tone: MlTone.transit,
                clearedMessage: 'No trucks waiting at the gate',
                loading: inboundAsync.isFirstLoad,
              ),
              PortalQueueItem(
                label: 'Loads to weigh',
                count: awaitingWeigh,
                route: '/portal/mine/weighbridge',
                icon: Icons.scale_outlined,
                tone: MlTone.atMine,
                clearedMessage: 'Nothing on the weighbridge queue',
                loading: inboundAsync.isFirstLoad,
              ),
              PortalQueueItem(
                label: 'Requests sent back for revision',
                // Only `sent_back` is this org's to act on — `requested` and
                // `resubmitted` are sitting with the platform admin. Same
                // predicate as the rail badge, on purpose.
                count: requests
                    ?.where((r) => r.status == RequestStatus.sentBack)
                    .length,
                route: '/portal/mine/requests',
                icon: Icons.assignment_return_outlined,
                tone: MlTone.warn,
                clearedMessage: 'No requests awaiting your revision',
                loading: requestsAsync.isFirstLoad,
              ),
              PortalQueueItem(
                label: 'Open reconciliation disputes',
                count: disputes
                    ?.where((d) =>
                        d.status == DisputeStatus.open ||
                        d.status == DisputeStatus.underReview)
                    .length,
                route: '/portal/mine/reconciliations',
                icon: Icons.gavel_outlined,
                tone: MlTone.error,
                clearedMessage: 'No disputes open against your loads',
                loading: disputesAsync.isFirstLoad,
              ),
            ],
          ),
          const SizedBox(height: 26),

          // ---- band 5: live strip ----------------------------------------
          PortalDashboardSection(
            title: 'On the mine floor',
            subtitle: 'Every truck between the gate and the weighbridge.',
            meta: inbound == null
                ? null
                : '${inbound.where((t) => t.isInbound || t.isOnSite).length} '
                    'active',
            viewRoute: '/portal/mine/truck-locations',
            viewLabel: 'Truck locations',
            child: PortalLiveStrip(
              trucks: _liveTrucks(inbound),
              emptyMessage: inbound == null
                  ? 'The inbound queue could not be read.'
                  : 'No trucks are inbound or on site right now.',
            ),
          ),
          const SizedBox(height: 26),

          // ---- band 6: recent waybills -----------------------------------
          //
          // Reads `rawReconRowsProvider` — the SAME source as the recon table
          // this band's "View →" opens. It used to read raw `transactions`
          // rows, and the TRUCK column was a dash on every row ever rendered:
          // it looked for `truck_reg` / `vehicle_reg` / `reg` in transaction
          // metadata, and NOTHING writes any of those keys. Measured on
          // production: 0 of 43 transactions carry one, while 41 of 43 can
          // reach a plate through their trip. The comment beside it said the
          // field was "genuinely absent on older loads" — it is absent on all
          // of them, permanently, and would have stayed a dash forever.
          //
          // `list_raw_recon_rows` already resolves it the right way,
          // `coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_
          // number)`, exactly as `list_load_quality` does. A waybill is also
          // per TRIP rather than per transaction, which is what that RPC
          // returns — so this band and the table it links to can no longer
          // report different last-tens, which its own subtitle already assumed.
          _recentWaybillsBand(context, companyId),

          if (!mirror) ...[
            const SizedBox(height: 26),
            AvailableRoutesSection(companyId: companyId, enabled: true),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Bands
  // -------------------------------------------------------------------------

  Widget _trendBand(
    BuildContext context,
    String companyId,
    List<double> current,
    List<double> previous,
  ) {
    // The company's own monthly target, if anyone has set one. `null` draws NO
    // line and NO caption — the rule the whole targets system was rewritten
    // around: a target nobody chose must not render like one somebody did.
    //
    // `currentMonthDailyPace` is the shared rule (`MlTargetsData`), so this
    // band and the console cannot disagree about which month is being read or
    // what a month's target is worth per day.
    final targets = ref.watch(targetsProvider(TargetScope.company(companyId)));
    final pace = targets.valueOrNull?.currentMonthDailyPace;

    // A FAILED read must not render as 'No target set'. Until
    // `20260816110000_targets_company_self_read.sql` this call returned 42501
    // for every company user, and this caption said 'No target set' with total
    // confidence — a sentence that would have gone on saying exactly the same
    // thing after somebody set a target. Absence and refusal are different
    // facts and now read differently.
    final String targetMeta;
    if (targets.hasError) {
      targetMeta = 'Target unavailable';
    } else if (targets.isLoading && !targets.hasValue) {
      targetMeta = 'Checking target…';
    } else {
      targetMeta = pace == null ? 'No target set' : 'Target ${pace.round()} t/day';
    }

    return PortalDashboardSection(
      title: 'Tons out',
      subtitle: 'Daily weighbridge net mass against the previous '
          '${_period.label.toLowerCase()}.',
      meta: targetMeta,
      viewRoute: '/portal/mine/tons-out',
      child: MlCard(
        child: MlFlagshipTrend(
          current: current,
          previous: previous,
          tokens: portalGlass(context),
          target: pace,
          targetLabel: pace == null ? null : 'TARGET ${pace.round()} T/DAY',
          latestLabel: _period.label,
          priorLabel: 'Previous ${_period.label.toLowerCase()}',
          unitCaption: 'Daily · Tons',
          xLabels: const {},
        ),
      ),
    );
  }

  /// [balance] is the tonnage on the **capped order piles** — the numerator the
  /// ring is measuring cover against. [totalOnGround] is every pile including
  /// ROM production, used only for the no-order-pile message, where "how much
  /// is on the ground" is the useful thing to say.
  Widget _stockpileBand(
    BuildContext context,
    List<StockpileEntry>? stockpiles,
    double? balance,
    double? capacity, {
    double? totalOnGround,
  }) {
    final s = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;

    Widget body;
    if (stockpiles == null) {
      body = const MlEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'Stockpiles unavailable',
        message: 'The stockpile balances could not be read.',
      );
    } else if (capacity == null || capacity <= 0) {
      body = MlEmptyState(
        icon: Icons.inventory_2_outlined,
        title: totalOnGround == null || totalOnGround == 0
            ? 'No product on the ground'
            : '${_tons(totalOnGround)} t on the ground',
        message: 'No order stockpile has been created yet. One is minted '
            'automatically when the platform links an order to this mine.',
      );
    } else {
      // The clamp stays — a ring cannot draw past full — but it is no longer
      // load-bearing, because the numerator is now scoped to the same piles as
      // `capacity`. It only guards the genuine over-fill case, which
      // `stockpile_add_tons` rejects server-side anyway.
      final filled = (balance ?? 0).clamp(0, capacity).toDouble();
      final pct = (filled / capacity * 100).round();
      body = Center(
        child: MlDonut(
          segments: [
            MlDonutSegment(
              'Filled',
              filled,
              MlTone.done.colors(brightness).fg,
            ),
            MlDonutSegment(
              'Remaining',
              (capacity - filled).clamp(0, capacity).toDouble(),
              MlTone.neutral.colors(brightness).fg.withValues(alpha: 0.35),
            ),
          ],
          trackColor: s.surfaceSunken,
          centre: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$pct%',
                style: context.mlText.figure(color: s.textStrong, size: 30),
              ),
              Text(
                '${_tons(filled)} / ${_tons(capacity)} t',
                style: context.mlText.code(
                  color: s.textMuted,
                  size: 11,
                  weight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PortalDashboardSection(
      title: 'Stockpile cover',
      subtitle: 'How full the capped order piles are.',
      meta: stockpiles == null ? null : '${stockpiles.length} pile(s)',
      viewRoute: '/portal/mine/stockpiles',
      child: MlCard(child: SizedBox(height: 232, child: body)),
    );
  }

  /// The band wrapper, so the meta line counts the same rows the table draws
  /// rather than a second query's total.
  Widget _recentWaybillsBand(BuildContext context, String companyId) {
    final async = ref.watch(rawReconRowsProvider(companyId));
    final rows = async.valueOrNull;
    final String meta;
    if (async.hasError) {
      meta = 'Could not read waybills';
    } else if (rows == null) {
      meta = 'Loading…';
    } else {
      meta = '${rows.length} all time';
    }
    return PortalDashboardSection(
      title: 'Recent waybills',
      subtitle: 'The last ten loads captured at the weighbridge.',
      meta: meta,
      viewRoute: '/portal/mine/tons-out',
      child: _recentWaybills(context, async),
    );
  }

  Widget _recentWaybills(
    BuildContext context,
    AsyncValue<List<RawReconRow>> async,
  ) {
    final s = MlSemantic.of(context);

    if (async.hasError) {
      return MlCard(
        child: MlEmptyState(
          icon: Icons.error_outline,
          title: 'Could not load waybills',
          message: friendlyError(async.error!),
        ),
      );
    }
    final waybills = async.valueOrNull;
    if (waybills == null) {
      return const MlCard(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 28),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (waybills.isEmpty) {
      return MlCard(
        child: MlEmptyState(
          icon: Icons.receipt_long_outlined,
          title: 'No waybills yet',
          message: 'A waybill is generated automatically the moment the load '
              'controller records a gross weigh.',
        ),
      );
    }

    // Cancellations are not loads that shipped. `list_raw_recon_rows` already
    // excludes anything without a trip, so this is the only status to drop.
    final recent = waybills
        .where((w) => w.tripStatus != TripStatus.cancelled.wire)
        .toList()
      ..sort((a, b) => b.tripDate.compareTo(a.tripDate));
    final rows = recent.take(10).toList();

    Widget text(String v, {bool mono = false, bool strong = false}) => Text(
          v,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: mono ? MlTokens.fontMono : MlTokens.fontSans,
            fontSize: MlTokens.fsBodySm,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            color: strong ? s.textStrong : s.textBody,
          ),
        );

    return MlCard(
      padding: EdgeInsets.zero,
      child: MlDataTable(
        columns: const [
          MlColumn('Date'),
          MlColumn('Waybill'),
          MlColumn('Truck'),
          MlColumn('Product'),
          MlColumn('Net', align: TextAlign.right),
        ],
        rows: [
          for (final w in rows)
            [
              text(_date(w.tripDate)),
              // The waybill NUMBER is the transaction reference (TRP-…) —
              // the same value the recon table's WAYBILL NUMBER column shows,
              // now literally from the same column of the same RPC.
              text(w.waybillNumber ?? '—', mono: true),
              text(w.truckReg ?? '—', mono: true),
              text(w.product ?? '—'),
              text(
                w.netMass == null ? '—' : _tons(w.netMass!),
                mono: true,
                strong: true,
              ),
            ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Derivations
  // -------------------------------------------------------------------------

  /// Net tons per calendar day, keyed by days-ago. Built once and windowed,
  /// so the current and previous periods cannot drift apart.
  Map<int, double> _tonsByDay(
    List<OperationTransaction> waybills,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day);
    final byDay = <int, double>{};
    for (final w in waybills) {
      final at = MlTime.sast(w.updatedAt);
      final day = DateTime(at.year, at.month, at.day);
      final ago = today.difference(day).inDays;
      if (ago < 0) continue;
      byDay[ago] = (byDay[ago] ?? 0) + w.netTonsOut;
    }
    return byDay;
  }

  /// [days] of tonnage ending [offset] days ago, oldest first.
  List<double> _window(
    Map<int, double> byDay,
    DateTime now,
    int days,
    int offset,
  ) =>
      [
        for (var i = days - 1; i >= 0; i--) byDay[i + offset] ?? 0.0,
      ];

  List<PortalLiveTruck> _liveTrucks(List<MineTrip>? trips) {
    if (trips == null) return const [];
    final live = trips.where((t) => t.isInbound || t.isOnSite).toList()
      ..sort((a, b) => a.status.step.compareTo(b.status.step));
    return [
      for (final t in live)
        PortalLiveTruck(
          registration: t.truckReg ?? 'Unassigned truck',
          status: t.status.label,
          tone: switch (t.status) {
            TripStatus.arrivedAtMine || TripStatus.loading => MlTone.atMine,
            TripStatus.loaded => MlTone.done,
            _ => MlTone.transit,
          },
          // The destination, not an ETA: a straight-line ETA is only computable
          // for a `?q=lat,lng` destination, and a made-up one on the mine floor
          // is worse than none.
          detail: t.commodity,
          route: '/portal/mine/trips/${t.tripId}',
        ),
    ];
  }

  static String _tons(double v) => v >= 1000
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);

  static String _date(DateTime d) {
    final local = MlTime.sast(d);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${local.day.toString().padLeft(2, '0')} '
        '${months[local.month - 1]}';
  }
}
