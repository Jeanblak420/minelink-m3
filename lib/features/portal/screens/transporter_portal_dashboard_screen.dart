import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/fleet/providers/maintenance_providers.dart';
import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/models/trip_earning.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/providers/portal_tab_index_provider.dart';
import 'package:flutter_application_1/features/portal/widgets/dispatch_route_widgets.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';
import 'package:flutter_application_1/features/portal/services/earnings_service.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/dashboard/portal_dashboard_kit.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_charts.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// The Transporter dashboard (P7-20, P7-23, P7-24, P7-25).
///
/// A haulier's dashboard is a fleet dashboard: what the trucks moved, what it
/// earned net of cost, and how much of the fleet is actually working. The three
/// fleet states are the ones the platform derives server-side — On Route from
/// an active trip, In Maintenance from an open out-of-service record, Available
/// as the remainder — so this page cannot disagree with the Fleet screen.
class TransporterPortalDashboardScreen extends ConsumerStatefulWidget {
  const TransporterPortalDashboardScreen({super.key});

  @override
  ConsumerState<TransporterPortalDashboardScreen> createState() =>
      _TransporterPortalDashboardScreenState();
}

class _TransporterPortalDashboardScreenState
    extends ConsumerState<TransporterPortalDashboardScreen> {
  PortalPeriod _period = PortalPeriod.week;

  /// The route id a deep link asked us to open, once handled — so the sheet is
  /// opened exactly once per link rather than on every rebuild.
  String? _focusHandled;

  /// Open the detail sheet for a route a deep link named
  /// (`/portal/transporter/accept-route/:routeId`).
  ///
  /// Before this the `:routeId` was parsed by the router and thrown away, so
  /// the link landed the transporter on the full list with no clue which route
  /// they had been sent to. If the id does not match anything they can see —
  /// already actioned, or another company's — nothing is opened and the
  /// dashboard simply renders, which is the honest outcome.
  void _handleRouteFocus(List<DispatchedRoute> dispatches, String companyId) {
    final focusId = ref.watch(pendingRouteFocusProvider);
    if (focusId == null || focusId == _focusHandled || dispatches.isEmpty) {
      return;
    }
    DispatchedRoute? match;
    for (final d in dispatches) {
      if (d.routeId == focusId || d.dispatchId == focusId) {
        match = d;
        break;
      }
    }
    _focusHandled = focusId;
    ref.read(pendingRouteFocusProvider.notifier).state = null;
    if (match == null) return;
    final route = match;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDispatchedRouteDetailSheet(
        context: context,
        ref: ref,
        route: route,
        companyId: companyId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const MlEmptyState(
        icon: Icons.domain_disabled_outlined,
        title: 'Company not loaded',
        message: 'Your account is not linked to a transporter yet, so there '
            'is nothing to report on.',
      );
    }

    // The pit clock, not the reader's laptop — every figure below
    // is bucketed against this.
    final now = MlTime.now();
    // The AsyncValue is kept, not just its value: the action queue has to tell
    // "still reading" from "could not read", and `valueOrNull` collapses both
    // to null. See `PortalQueueItem.loading`.
    final earnings = ref.watch(tripEarningsProvider(companyId)).valueOrNull;
    final fleetAsync = ref.watch(fleetStatusProvider(companyId));
    final fleet = fleetAsync.valueOrNull;
    final dispatchesAsync =
        ref.watch(transporterDispatchesProvider(companyId));
    final disputesAsync = ref.watch(reconDisputesProvider(companyId));
    final maintenanceAsync =
        ref.watch(fleetMaintenanceProvider(companyId));
    final dispatches = dispatchesAsync.valueOrNull;
    final disputes = disputesAsync.valueOrNull;
    final maintenance = maintenanceAsync.valueOrNull;

    _handleRouteFocus(dispatches ?? const [], companyId);

    final from = _period.startFrom(now);
    final priorFrom = from.subtract(Duration(days: _period.days));
    final inWindow =
        earnings?.where((e) => !MlTime.sast(e.updatedAt).isBefore(from)).toList();
    final inPrior = earnings?.where((e) {
      final at = MlTime.sast(e.updatedAt);
      return !at.isBefore(priorFrom) && at.isBefore(from);
    }).toList();

    double sum(List<TripEarning>? rows, double? Function(TripEarning) f) =>
        rows == null ? 0 : rows.fold(0, (a, e) => a + (f(e) ?? 0));

    final tons = inWindow == null ? null : sum(inWindow, (e) => e.netTons);
    final priorTons = sum(inPrior, (e) => e.netTons);
    final revenue = inWindow == null ? null : sum(inWindow, (e) => e.revenue);
    final priorRevenue = sum(inPrior, (e) => e.revenue);

    final onRoute = fleet?.where((v) => v.onRoute).toList();
    final inMaintenance = fleet?.where((v) => v.inMaintenance).toList();
    // Utilisation is over the ACTIVE fleet: a decommissioned truck is not idle
    // capacity, and counting it would understate a working fleet.
    final active = fleet?.where((v) => v.isActive).toList();
    final utilisation = active == null || active.isEmpty
        ? null
        : (onRoute!.where((v) => v.isActive).length / active.length * 100)
            .round();

    // Trucks that could be allocated to an accepted route right now.
    final allocatable = fleet
        ?.where((v) => v.isActive && !v.onRoute && !v.inMaintenance)
        .length;

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PortalDashboardHeader(
            title: 'Transporter overview',
            subtitle: 'Tonnage moved, earnings and fleet availability — live, '
                'over the last ${_period.label.toLowerCase()}.',
            period: _period,
            onPeriodChanged: (p) => setState(() => _period = p),
            actions: [
              MlButton.tonal(
                label: 'Earnings',
                icon: Icons.payments_outlined,
                compact: true,
                onPressed: () => context.go('/portal/transporter/earnings'),
              ),
            ],
          ),
          const SizedBox(height: 20),

          PortalKpiRow(
            kpis: [
              PortalKpi(
                label: 'Tons moved',
                value: tons == null ? null : _tons(tons),
                unit: 't',
                sublabel: 'Weighbridge net, ${_period.label.toLowerCase()}',
                icon: Icons.local_shipping_outlined,
                tone: MlTone.accent,
                route: '/portal/transporter/tons-out',
                delta: tons == null ? null : tons - priorTons,
                emptyReason: 'earnings feed unavailable',
              ),
              PortalKpi(
                label: 'Revenue',
                // `R` PREFIXES the figure and is not a unit.
                //
                // This passed `unit: 'R'`, which the tile renders after the
                // number in the small muted style it uses for "t" and "%" — so
                // the dashboard read "29 159 R" while the same file writes
                // "R29 159" for its peak-per-day caption and its table, and the
                // margin ledger writes "R 141,306.00". Three spellings of one
                // currency, one of them treating a currency symbol as a unit of
                // measure. Photographed 2026-08-20 on the phone dashboards.
                value: revenue == null ? null : 'R${_rand(revenue)}',
                sublabel: 'At your rate per ton, before costs',
                icon: Icons.account_balance_wallet_outlined,
                tone: MlTone.done,
                route: '/portal/transporter/earnings',
                delta: revenue == null ? null : revenue - priorRevenue,
                emptyReason: 'earnings feed unavailable',
              ),
              PortalKpi(
                label: 'Trucks on route',
                value: onRoute?.length.toString(),
                sublabel: active == null
                    ? 'Carrying an active trip'
                    : 'of ${active.length} active trucks',
                icon: Icons.route_outlined,
                tone: MlTone.transit,
                route: '/portal/transporter/trucks-on-route',
                emptyReason: 'fleet status unavailable',
              ),
              PortalKpi(
                label: 'Fleet utilisation',
                value: utilisation?.toString(),
                unit: '%',
                sublabel: 'Active trucks currently on a route',
                icon: Icons.speed_outlined,
                tone: MlTone.atMine,
                route: '/portal/transporter/fleet',
                emptyReason: active == null
                    ? 'fleet status unavailable'
                    : 'no active trucks registered',
              ),
            ],
          ),
          const SizedBox(height: 26),

          LayoutBuilder(
            builder: (context, c) {
              final trend = _earningsTrend(context, earnings, now);
              final ring = _fleetRing(context, fleet, onRoute, inMaintenance);
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

          PortalActionQueue(
            items: [
              PortalQueueItem(
                label: 'Dispatches to accept',
                count: dispatches
                    ?.where((d) => d.status == DispatchStatus.dispatched)
                    .length,
                route: '/portal/transporter/routes',
                icon: Icons.assignment_turned_in_outlined,
                tone: MlTone.transit,
                clearedMessage: 'No routes waiting on your acceptance',
                loading: dispatchesAsync.isFirstLoad,
              ),
              PortalQueueItem(
                label: 'Trucks available to allocate',
                count: allocatable,
                route: '/portal/transporter/fleet',
                icon: Icons.playlist_add_check_rounded,
                tone: MlTone.neutral,
                clearedMessage: 'Every active truck is on a route or in for '
                    'service',
                loading: fleetAsync.isFirstLoad,
              ),
              PortalQueueItem(
                label: 'Services due',
                // `dueSoon` mirrors the server-side `notify_service_due_job`
                // predicate, so this card, the Maintenance screen, the rail
                // badge and the nightly reminder all agree on what "due" means.
                count: maintenance?.schedules.where((s) => s.dueSoon).length,
                route: '/portal/transporter/maintenance',
                icon: Icons.build_outlined,
                tone: MlTone.warn,
                clearedMessage: 'Nothing due in the reminder window',
                loading: maintenanceAsync.isFirstLoad,
              ),
              PortalQueueItem(
                label: 'Open reconciliation disputes',
                count: disputes
                    ?.where((d) =>
                        d.status == DisputeStatus.open ||
                        d.status == DisputeStatus.underReview)
                    .length,
                route: '/portal/transporter/reconciliations',
                icon: Icons.gavel_outlined,
                tone: MlTone.error,
                clearedMessage: 'No disputes open on your loads',
                loading: disputesAsync.isFirstLoad,
              ),
            ],
          ),
          const SizedBox(height: 26),

          PortalDashboardSection(
            title: 'Trucks on route',
            subtitle: 'Every vehicle currently carrying a load.',
            meta: onRoute == null ? null : '${onRoute.length} moving',
            viewRoute: '/portal/transporter/truck-locations',
            viewLabel: 'Truck locations',
            child: PortalLiveStrip(
              trucks: [
                for (final v in onRoute ?? const <FleetVehicleStatus>[])
                  PortalLiveTruck(
                    registration: v.registration,
                    status: v.tripStatus == null
                        ? 'On route'
                        : TripStatus.parse(v.tripStatus!).label,
                    tone: MlTone.transit,
                    // Where it is going. An ETA needs a `?q=lat,lng`
                    // destination, and a guessed one on a haul is worse than
                    // none — the live map is one tap away and has the real
                    // position.
                    detail: v.offloadingPoint ?? v.commodity,
                    route: v.activeTripId == null
                        ? null
                        : '/portal/transporter/trips/${v.activeTripId}',
                  ),
              ],
              emptyMessage: onRoute == null
                  ? 'The fleet status could not be read.'
                  : 'None of your trucks is on a route right now.',
            ),
          ),
          const SizedBox(height: 26),

          PortalDashboardSection(
            title: 'Recent completed trips',
            subtitle: 'The last ten loads delivered, with what they earned.',
            meta: earnings == null ? null : '${earnings.length} all time',
            viewRoute: '/portal/transporter/earnings',
            child: _recentTrips(context, earnings),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _earningsTrend(
    BuildContext context,
    List<TripEarning>? earnings,
    DateTime now,
  ) {
    if (earnings == null) {
      return PortalDashboardSection(
        title: 'Tons and earnings',
        subtitle: 'Daily tonnage against what it earned.',
        viewRoute: '/portal/transporter/earnings',
        child: MlCard(
          child: SizedBox(
            height: 200,
            child: MlEmptyState(
              icon: Icons.show_chart_rounded,
              title: 'Earnings unavailable',
              message: 'The trip-earnings feed could not be read.',
            ),
          ),
        ),
      );
    }

    final today = DateTime(now.year, now.month, now.day);
    final tonsByDay = <int, double>{};
    final randByDay = <int, double>{};
    for (final e in earnings) {
      final at = MlTime.sast(e.updatedAt);
      final ago = today.difference(DateTime(at.year, at.month, at.day)).inDays;
      if (ago < 0) continue;
      tonsByDay[ago] = (tonsByDay[ago] ?? 0) + (e.netTons ?? 0);
      randByDay[ago] = (randByDay[ago] ?? 0) + (e.revenue ?? 0);
    }

    final days = _period.days;
    final tons = [for (var i = days - 1; i >= 0; i--) tonsByDay[i] ?? 0.0];
    final rand = [for (var i = days - 1; i >= 0; i--) randByDay[i] ?? 0.0];
    // Two series on one axis: revenue is 2–3 orders of magnitude larger than
    // tonnage, so plotting it raw would flatten the tonnage line onto the
    // floor. It is indexed to the tonnage range, and the legend says so — the
    // axis is tons, and the peak Rand figure is stated in the meta line so the
    // real magnitude is never lost.
    final maxTons = tons.fold<double>(0, (a, b) => a > b ? a : b);
    final maxRand = rand.fold<double>(0, (a, b) => a > b ? a : b);
    final scale = maxRand == 0 || maxTons == 0 ? 0.0 : maxTons / maxRand;

    return PortalDashboardSection(
      title: 'Tons and earnings',
      subtitle: 'Daily tonnage against what it earned, indexed to the same '
          'axis.',
      meta: maxRand == 0 ? 'No revenue yet' : 'Peak R${_rand(maxRand)}/day',
      viewRoute: '/portal/transporter/earnings',
      child: MlCard(
        child: MlFlagshipTrend(
          current: tons,
          previous: [for (final r in rand) r * scale],
          tokens: portalGlass(context),
          latestLabel: 'Tons moved',
          priorLabel: 'Revenue (indexed)',
          unitCaption: 'Daily · Tons',
          xLabels: const {},
        ),
      ),
    );
  }

  Widget _fleetRing(
    BuildContext context,
    List<FleetVehicleStatus>? fleet,
    List<FleetVehicleStatus>? onRoute,
    List<FleetVehicleStatus>? inMaintenance,
  ) {
    final s = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;

    Widget body;
    if (fleet == null) {
      body = const MlEmptyState(
        icon: Icons.pie_chart_outline,
        title: 'Fleet status unavailable',
        message: 'The vehicle availability feed could not be read.',
      );
    } else if (fleet.isEmpty) {
      body = const MlEmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No vehicles registered',
        message: 'Add a truck on the Fleet screen and it appears here with its '
            'live availability.',
      );
    } else {
      final route = onRoute!.length;
      final service = inMaintenance!.length;
      // The three states are mutually exclusive and derived server-side, so
      // the remainder is Available by construction — no separate query that
      // could disagree.
      final available = fleet.length - route - service;
      body = Center(
        child: MlDonut(
          segments: [
            MlDonutSegment('On route', route.toDouble(),
                MlTone.transit.colors(brightness).fg),
            MlDonutSegment('Available', available.toDouble(),
                MlTone.done.colors(brightness).fg),
            MlDonutSegment('In service', service.toDouble(),
                MlTone.warn.colors(brightness).fg),
          ],
          trackColor: s.surfaceSunken,
          centre: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${fleet.length}',
                style: context.mlText.figure(color: s.textStrong, size: 30),
              ),
              Text(
                'trucks',
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
      title: 'Fleet state',
      subtitle: 'On route, available and in for service.',
      meta: fleet == null ? null : mlCount(fleet.length, 'vehicle'),
      viewRoute: '/portal/transporter/fleet',
      child: MlCard(child: SizedBox(height: 232, child: body)),
    );
  }

  Widget _recentTrips(BuildContext context, List<TripEarning>? earnings) {
    final s = MlSemantic.of(context);
    if (earnings == null) {
      return MlCard(
        child: MlEmptyState(
          icon: Icons.error_outline,
          title: 'Trips unavailable',
          message: 'The trip-earnings feed could not be read.',
        ),
      );
    }
    final done = earnings
        .where((e) => TripStatus.parse(e.status ?? '') == TripStatus.completed)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (done.isEmpty) {
      return MlCard(
        child: MlEmptyState(
          icon: Icons.route_outlined,
          title: 'No completed trips yet',
          message: 'A trip lands here once its POD is uploaded and it closes.',
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
        columns: const [
          MlColumn('Date'),
          MlColumn('Truck'),
          MlColumn('Source'),
          MlColumn('Customer'),
          MlColumn('Net', align: TextAlign.right),
          MlColumn('Revenue', align: TextAlign.right),
        ],
        rows: [
          for (final e in done.take(10))
            [
              text(_date(e.updatedAt)),
              text(e.truckReg ?? '—', mono: true),
              text(e.sourceName ?? '—'),
              text(e.customerName ?? '—'),
              text(
                e.netTons == null ? '—' : '${_tons(e.netTons!)} t',
                mono: true,
              ),
              // A dash, not R0 — a trip whose rate has not been agreed is not
              // a trip that earned nothing.
              text(
                e.revenue == null ? '—' : 'R${_rand(e.revenue!)}',
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
