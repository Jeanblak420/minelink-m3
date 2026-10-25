import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/models/buyer_load_value.dart';
import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/services/buyer_value_service.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';
import 'package:flutter_application_1/features/portal/services/logistics_service.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/available_routes_section.dart';
import 'package:flutter_application_1/features/portal/widgets/dashboard/portal_dashboard_kit.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_charts.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/tour/widgets/tour_target.dart';
import 'package:flutter_application_1/features/tour/examples/buyer_dashboard_keys.dart';

/// The Buyer dashboard (P7-20, P7-22, P7-24, P7-25).
///
/// The buyer's question is not "how much moved" but "how much am I about to
/// pay, and does it match what I ordered". So the money band is first-class:
/// delivered tonnage, the payable Rand value the platform computed from the
/// agreed rate and the quality penalty, and the variance against what has
/// actually been invoiced.
///
/// Everything here comes from `list_buyer_trip_values`, which is buyer-private
/// server-side — it never returns the admin margin or the transporter's price.
class BuyerPortalDashboardScreen extends ConsumerStatefulWidget {
  const BuyerPortalDashboardScreen({super.key});

  @override
  ConsumerState<BuyerPortalDashboardScreen> createState() =>
      _BuyerPortalDashboardScreenState();
}

class _BuyerPortalDashboardScreenState
    extends ConsumerState<BuyerPortalDashboardScreen> {
  PortalPeriod _period = PortalPeriod.week;

  @override
  Widget build(BuildContext context) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const MlEmptyState(
        icon: Icons.domain_disabled_outlined,
        title: 'Company not loaded',
        message: 'Your account is not linked to a buyer organisation yet, so '
            'there is nothing to report on.',
      );
    }

    return ref.watch(logisticsSnapshotProvider(companyId)).when(
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

    // The AsyncValue is kept, not just its value: the action queue has to tell
    // "still reading" from "could not read", and `valueOrNull` collapses both
    // to null. See `PortalQueueItem.loading`.
    final valuesAsync = ref.watch(buyerTripValuesProvider(companyId));
    final requestsAsync = ref.watch(companyRequestsProvider(companyId));
    final disputesAsync = ref.watch(reconDisputesProvider(companyId));
    final values = valuesAsync.valueOrNull;
    final requests = requestsAsync.valueOrNull;
    final disputes = disputesAsync.valueOrNull;

    final from = _period.startFrom(now);
    final inWindow = values
        ?.where((v) => !MlTime.sast(v.updatedAt).isBefore(from))
        .toList();
    final priorFrom = from.subtract(Duration(days: _period.days));
    final inPrior = values?.where((v) {
      final at = MlTime.sast(v.updatedAt);
      return !at.isBefore(priorFrom) && at.isBefore(from);
    }).toList();

    double sum(List<BuyerLoadValue>? rows, double? Function(BuyerLoadValue) f) =>
        rows == null ? 0 : rows.fold(0, (a, v) => a + (f(v) ?? 0));

    final delivered = inWindow == null ? null : sum(inWindow, (v) => v.deliveredTons);
    final priorDelivered = sum(inPrior, (v) => v.deliveredTons);
    final payable = inWindow == null ? null : sum(inWindow, (v) => v.payableValue);
    final priorPayable = sum(inPrior, (v) => v.payableValue);

    // An "open order" is a linked request that still has trips running. Anything
    // else is either not yet linked (so not an order) or finished.
    final openOrders = requests
        ?.where((r) => r.status == RequestStatus.linked)
        .length;

    // Inbound = this buyer's loads that have left the mine and are not yet
    // offloaded — the ones a receiving yard needs to expect. `TripRecord.status`
    // is the raw wire string, so it goes through `TripStatus.parse` rather than
    // being compared as text: a legacy value like `draft` must land on the
    // canonical lifecycle, not silently miss every branch.
    final inbound = snap.trips.where((t) {
      final step = TripStatus.parse(t.status).step;
      return step >= TripStatus.leftMine.step &&
          step < TripStatus.offloaded.step;
    }).toList();

    // Loads delivered but with no invoice captured yet — the buyer's own
    // outstanding admin, and the reason the money band exists.
    final uninvoiced = values
        ?.where((v) => v.deliveredTons != null && v.invoiceId == null)
        .length;

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PortalDashboardHeader(
            title: 'Dashboard',
            subtitle: 'Deliveries, payable value and open orders — live, over '
                'the last ${_period.label.toLowerCase()}.',
            period: _period,
            onPeriodChanged: (p) => setState(() => _period = p),
            actions: [
              MlButton.tonal(
                label: 'Loads & value',
                icon: Icons.payments_outlined,
                compact: true,
                onPressed: () => context.go('/portal/buyer/loads-value'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          TourTarget(
            id: 'buyer.dashboard',
            targetKey: BuyerDashboardTourKeys.dashboard,
            child: PortalKpiRow(
              period: _period,
              kpis: [
              PortalKpi(
                label: 'Tons delivered',
                value: delivered == null ? null : _tons(delivered),
                unit: 't',
                sublabel: 'Offload weight, ${_period.label.toLowerCase()}',
                icon: Icons.local_shipping_outlined,
                tone: MlTone.accent,
                route: '/portal/buyer/loads-value',
                delta: delivered == null ? null : delivered - priorDelivered,
                emptyReason: 'delivery values unavailable',
                // A pending read is not a failed one -- see `PortalKpi.loading`.
                loading: valuesAsync.isFirstLoad,
              ),
              PortalKpi(
                label: 'Payable',
                // `R` PREFIXES the figure and is not a unit.
                //
                // This passed `unit: 'R'`, which the tile renders after the
                // number in the small muted style it uses for "t" and "%" — so
                // the dashboard read "29 159 R" while the same file writes
                // "R29 159" for its peak-per-day caption and its table, and the
                // margin ledger writes "R 141,306.00". Three spellings of one
                // currency, one of them treating a currency symbol as a unit of
                // measure. Photographed 2026-08-20 on the phone dashboards.
                value: payable == null ? null : 'R${_rand(payable)}',
                sublabel: 'At the agreed rate, after quality penalty',
                icon: Icons.account_balance_wallet_outlined,
                tone: MlTone.done,
                route: '/portal/buyer/loads-value',
                delta: payable == null ? null : payable - priorPayable,
                // Rand, like the value above it. Without this the badge read
                // a bare `-6351` beside `R49,710`.
                deltaPrefix: 'R',
                deltaGoodWhenUp: false,
                emptyReason: 'load values unavailable',
                loading: valuesAsync.isFirstLoad,
              ),
              PortalKpi(
                label: 'Open orders',
                value: openOrders?.toString(),
                sublabel: 'Linked to a mine and hauling',
                icon: Icons.inventory_outlined,
                tone: MlTone.transit,
                route: '/portal/buyer/orders',
                emptyReason: 'orders unavailable',
                loading: requestsAsync.isFirstLoad,
              ),
              PortalKpi(
                label: 'Trucks inbound',
                value: inbound.length.toString(),
                sublabel: 'Left the mine, not yet offloaded',
                icon: Icons.moving_rounded,
                // TRANSIT, not atMine. `inbound` is every trip at or past
                // `leftMine` and before `offloaded` — a truck on the road,
                // which is what the sublabel says. `MlTone.atMine` is the
                // amber that means AT THE MINE (CLAUDE.md §5), so this tile
                // said the opposite of its own caption. The live strip 80
                // lines below tones the SAME trips `transit`, and the mine
                // dashboard's identically-named KPI is `transit` too.
                tone: MlTone.transit,
                route: '/portal/buyer/truck-locations',
              ),
            ],
            ),
          ),
          const SizedBox(height: 26),

          LayoutBuilder(
            builder: (context, c) {
              final trend = _valueTrend(context, values, now,
                  pending: valuesAsync.isFirstLoad);
              final ring = _invoiceRing(context, values,
                  pending: valuesAsync.isFirstLoad);
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

          TourTarget(
            id: 'buyer.requests',
            targetKey: BuyerDashboardTourKeys.requests,
            child: PortalActionQueue(
              items: [
                PortalQueueItem(
                  label: 'Requests sent back for revision',
                  count: requests
                      ?.where((r) => r.status == RequestStatus.sentBack)
                      .length,
                  route: '/portal/buyer/requests',
                  icon: Icons.assignment_return_outlined,
                  tone: MlTone.warn,
                  clearedMessage: 'No requests awaiting your revision',
                  loading: requestsAsync.isFirstLoad,
                ),
              PortalQueueItem(
                label: 'Delivered loads to invoice',
                count: uninvoiced,
                route: '/portal/buyer/loads-value',
                icon: Icons.receipt_long_outlined,
                tone: MlTone.transit,
                clearedMessage: 'Every delivered load has an invoice captured',
                loading: valuesAsync.isFirstLoad,
              ),
              PortalQueueItem(
                label: 'Open reconciliation disputes',
                count: disputes
                    ?.where((d) =>
                        d.status == DisputeStatus.open ||
                        d.status == DisputeStatus.underReview)
                    .length,
                route: '/portal/buyer/reconciliations',
                icon: Icons.gavel_outlined,
                tone: MlTone.error,
                clearedMessage: 'No disputes open on your deliveries',
                loading: disputesAsync.isFirstLoad,
              ),
            ],
            ),
          ),
          const SizedBox(height: 26),

          TourTarget(
            id: 'buyer.orders',
            targetKey: BuyerDashboardTourKeys.orders,
            child: PortalDashboardSection(
              title: 'Inbound to you',
              subtitle: 'Loads that have left the mine and not yet offloaded.',
              meta: '${inbound.length} on the road',
              viewRoute: '/portal/buyer/truck-locations',
              viewLabel: 'Truck locations',
            child: PortalLiveStrip(
              trucks: [
                for (final t in inbound)
                  PortalLiveTruck(
                    registration: t.truckReg ?? 'Unassigned truck',
                    status: TripStatus.parse(t.status).label,
                    tone: MlTone.transit,
                    // Net tons where the mine has weighed it, and nothing
                    // where it has not. An ETA is only computable when the
                    // destination is a `?q=lat,lng` maps link, and a guessed
                    // arrival time on a delivery is worse than none.
                    detail: t.netTons == null
                        ? null
                        : '${_tons(t.netTons!)} t',
                    route: '/portal/buyer/trips/${t.id}',
                  ),
              ],
              emptyMessage: 'Nothing is on the road to you right now.',
            ),
            ),
          ),
          const SizedBox(height: 26),

          PortalDashboardSection(
            title: 'Recent deliveries',
            subtitle: 'The last ten loads offloaded, with their payable value.',
            meta: values == null ? null : '${values.length} all time',
            viewRoute: '/portal/buyer/loads-value',
            child: _recentDeliveries(context, values,
                pending: valuesAsync.isFirstLoad),
          ),

          if (!mirror) ...[
            const SizedBox(height: 26),
            AvailableRoutesSection(companyId: companyId, enabled: true),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _valueTrend(
    BuildContext context,
    List<BuyerLoadValue>? values,
    DateTime now, {
    required bool pending,
  }) {
    if (values == null) {
      return PortalDashboardSection(
        title: 'Delivered vs payable',
        subtitle: 'Daily delivered tonnage against its Rand value.',
        viewRoute: '/portal/buyer/loads-value',
        child: MlCard(
          child: SizedBox(
            height: 200,
            child: pending
                ? portalFeedPending('load values')
                : const MlEmptyState(
                    icon: Icons.show_chart_rounded,
                    title: 'Load values unavailable',
                    message: 'The delivered-value feed could not be read.',
                  ),
          ),
        ),
      );
    }

    final today = DateTime(now.year, now.month, now.day);
    final tonsByDay = <int, double>{};
    final randByDay = <int, double>{};
    for (final v in values) {
      final at = MlTime.sast(v.updatedAt);
      final ago = today.difference(DateTime(at.year, at.month, at.day)).inDays;
      if (ago < 0) continue;
      tonsByDay[ago] = (tonsByDay[ago] ?? 0) + (v.deliveredTons ?? 0);
      randByDay[ago] = (randByDay[ago] ?? 0) + (v.payableValue ?? 0);
    }

    final days = _period.days;
    final tons = [for (var i = days - 1; i >= 0; i--) tonsByDay[i] ?? 0.0];
    // Rand is plotted on the same axis as tons, so it is scaled to the tonnage
    // range rather than drawn at its own magnitude — an R-per-day series is
    // 2–3 orders of magnitude larger and would flatten the tonnage line into
    // the floor. The caption says which line is which; the axis is tons.
    final rand = [for (var i = days - 1; i >= 0; i--) randByDay[i] ?? 0.0];
    final maxTons = tons.fold<double>(0, (a, b) => a > b ? a : b);
    final maxRand = rand.fold<double>(0, (a, b) => a > b ? a : b);
    final scale = maxRand == 0 || maxTons == 0 ? 0.0 : maxTons / maxRand;
    final randScaled = [for (final r in rand) r * scale];

    return PortalDashboardSection(
      title: 'Delivered vs payable',
      subtitle: 'Daily delivered tonnage against its Rand value, indexed to '
          'the same axis.',
      meta: maxRand == 0 ? 'No payable value yet' : 'Peak R${_rand(maxRand)}/day',
      viewRoute: '/portal/buyer/loads-value',
      child: MlCard(
        child: MlFlagshipTrend(
          current: tons,
          previous: randScaled,
          tokens: portalGlass(context),
          latestLabel: 'Delivered tons',
          priorLabel: 'Payable value (indexed)',
          unitCaption: 'Daily · Tons',
          xLabels: const {},
        ),
      ),
    );
  }

  Widget _invoiceRing(BuildContext context, List<BuyerLoadValue>? values,
      {required bool pending}) {
    final s = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;

    Widget body;
    final delivered =
        values?.where((v) => v.deliveredTons != null).toList();
    if (values == null) {
      body = pending
          ? portalFeedPending('load values')
          : const MlEmptyState(
              icon: Icons.pie_chart_outline,
              title: 'Load values unavailable',
              message: 'The delivered-value feed could not be read.',
            );
    } else if (delivered == null || delivered.isEmpty) {
      body = const MlEmptyState(
        icon: Icons.pie_chart_outline,
        title: 'Nothing delivered yet',
        message: 'Invoice cover appears once the first load is offloaded.',
      );
    } else {
      final invoiced = delivered.where((v) => v.invoiceId != null).length;
      final open = delivered.length - invoiced;
      final pct = (invoiced / delivered.length * 100).round();
      body = Center(
        child: MlDonut(
          segments: [
            MlDonutSegment('Invoiced', invoiced.toDouble(),
                MlTone.done.colors(brightness).fg),
            MlDonutSegment('Awaiting', open.toDouble(),
                MlTone.warn.colors(brightness).fg),
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
                '$invoiced / ${mlCount(delivered.length, 'load')}',
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
      title: 'Invoice cover',
      subtitle: 'Delivered loads with an invoice captured against them.',
      viewRoute: '/portal/buyer/loads-value',
      child: MlCard(child: SizedBox(height: 232, child: body)),
    );
  }

  Widget _recentDeliveries(
    BuildContext context,
    List<BuyerLoadValue>? values, {
    required bool pending,
  }) {
    final s = MlSemantic.of(context);
    if (values == null) {
      return MlCard(
        child: pending
            ? portalFeedPending('load values')
            : const MlEmptyState(
                icon: Icons.error_outline,
                title: 'Deliveries unavailable',
                message: 'The delivered-value feed could not be read.',
              ),
      );
    }
    final delivered = values.where((v) => v.deliveredTons != null).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (delivered.isEmpty) {
      return MlCard(
        child: MlEmptyState(
          icon: Icons.local_shipping_outlined,
          title: 'No deliveries yet',
          message: 'A load appears here the moment its POD is uploaded.',
        ),
      );
    }

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
        cardsOnPhone: true,
        columns: const [
          MlColumn('Date'),
          // The truck column carries a plate. Six columns sharing the 560px
          // scroll floor left it 79px, so "JD 22 PL MP" and "CK 84 RT GP" were
          // both cut on the buyer's own dashboard.
          MlColumn('Truck', minWidth: kPlateColumnMinWidth),
          MlColumn('Source', flex: 2),
          MlColumn('Product'),
          MlColumn('Delivered', align: TextAlign.right),
          MlColumn('Payable', align: TextAlign.right),
        ],
        rows: [
          for (final v in delivered.take(10))
            [
              text(_date(v.updatedAt)),
              text(v.truckReg ?? '—', mono: true),
              text(v.sourceName ?? '—'),
              text(v.commodity ?? '—'),
              text(
                v.deliveredTons == null ? '—' : '${_tons(v.deliveredTons!)} t',
                mono: true,
              ),
              // A dash, not R0: an unpriced load is one whose rate has not been
              // agreed, which is not the same as a load worth nothing.
              text(
                v.payableValue == null ? '—' : 'R${_rand(v.payableValue!)}',
                mono: true,
                strong: true,
              ),
            ],
        ],
      ),
    );
  }

  static String _tons(double v) => v >= 1000
      ? v.toStringAsFixed(0)
      : v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);

  /// Rand, grouped by `NumberFormat` like every other money site in the product.
  ///
  /// This hand-rolled its own grouping loop with a SPACE separator, so the
  /// dashboards printed `R29 159` while the earnings screen one click away
  /// printed `R29,159` and the margin ledger printed `R 141,306.00` — both of
  /// those through `intl`. Two separators for one currency, and the outlier was
  /// the copy that did not use the shared formatter. Found 2026-08-20 by
  /// photographing the two screens side by side.
  ///
  /// If South African spacing (SANS 920: a thin space, not a comma) is wanted
  /// later, it is now ONE pattern in one place rather than three
  /// implementations to find.
  static final _randFmt = NumberFormat('#,##0');

  static String _rand(double v) => _randFmt.format(v.round());

  /// `MlTime.listDay`, not a private month table.
  ///
  /// This was one of FOUR identical copies of a hand-rolled `dd MMM` — and all
  /// four dropped the YEAR. The mine's "Recent waybills" card ended
  /// "28 Jan" then "10 Feb", which is correctly sorted (the second is 2025) and
  /// reads as a sorting fault. `listDay` prints the year exactly when the date
  /// is not in the current South African one, the same rule `MlTime.ago`
  /// already used.
  static String _date(DateTime d) => MlTime.listDay(d);
}
