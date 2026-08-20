import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/features/portal/models/fuel_models.dart';
import 'package:flutter_application_1/features/portal/models/trip_earning.dart';
import 'package:flutter_application_1/features/portal/services/earnings_service.dart';
import 'package:flutter_application_1/features/portal/services/fuel_service.dart';
import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Transporter earnings dashboard: turns rate/ton × net tons into revenue and
/// rolls it up by period, vehicle and route, netting off maintenance cost.
class EarningsScreen extends ConsumerWidget {
  const EarningsScreen({super.key});

  static final _num = NumberFormat('#,##0');
  static final _dateFmt = DateFormat('dd MMM yyyy');

  static String _money(double? v, String currency) {
    if (v == null) return '—';
    final sym = currency == 'ZAR' ? 'R' : '$currency ';
    return '$sym${_num.format(v)}';
  }

  static String _tons(double v) => '${v.toStringAsFixed(2)} t';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final earningsAsync = ref.watch(tripEarningsProvider(companyId));
    final costs =
        ref.watch(vehicleCostBreakdownProvider(companyId)).asData?.value ??
        const <VehicleCostBreakdown>[];

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions live in MlPageHeader's own `actions` slot, not a Row wrapped
          // around it. That slot makes the title and the actions siblings in one
          // Wrap, so an action drops under the title when the row runs out of
          // width -- which it does on a phone, and at an accessibility text size
          // on a tablet. A Row gives an unflexed button unbounded width instead
          // (CLAUDE.md 10.4), and a button cannot ellipsize its way out: clamping
          // one truncates its hit target, not merely its label.
          MlPageHeader(
            title: 'Earnings',
            meta: earningsAsync.valueOrNull == null
                ? null
                : '${mlCount(earningsAsync.value!.length, 'trip')} · '
                      '${mlCount(costs.length, 'vehicle')} costed',
            description:
                'Revenue from your delivered tons at your agreed rate, '
                'less maintenance — per period, vehicle and route.',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(tripEarningsProvider(companyId));
                  ref.invalidate(vehicleCostsProvider(companyId));
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          earningsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => MlLoadFailure(
              subject: 'the earnings',
              error: e,
              onRetry: () => ref.invalidate(tripEarningsProvider(companyId)),
            ),
            data: (trips) =>
                _EarningsBody(trips: trips, costs: costs, companyId: companyId),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _EarningsBody extends StatelessWidget {
  final List<TripEarning> trips;
  final List<VehicleCostBreakdown> costs;
  final String companyId;
  const _EarningsBody({
    required this.trips,
    required this.costs,
    required this.companyId,
  });

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return const MlEmptyState(
        icon: Icons.payments_outlined,
        title: 'No earnings yet',
        message:
            'Revenue appears here once your trucks are loaded on a dispatched '
            'route with a set rate. It is your net tons × your rate per ton.',
      );
    }

    final currency = trips.first.currency;
    String money(double? v) => EarningsScreen._money(v, currency);

    // Revenue windows, on the mine's clock. The boundaries came from the
    // device and were compared against raw UTC `updatedAt` — two frames, on
    // money.
    final now = MlTime.now();
    final dayAgo = now.subtract(const Duration(days: 1));
    final weekAgo = now.subtract(const Duration(days: 7));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    double revD = 0, revW = 0, revM = 0, revY = 0, revTotal = 0;
    for (final t in trips) {
      final r = t.revenue ?? 0;
      revTotal += r;
      final at = MlTime.sast(t.updatedAt);
      if (at.isAfter(yearStart)) revY += r;
      if (at.isAfter(monthStart)) revM += r;
      if (at.isAfter(weekAgo)) revW += r;
      if (at.isAfter(dayAgo)) revD += r;
    }
    final totalCosts = costs.fold<double>(0, (s, c) => s + c.totalCost);
    final totalFuel = costs.fold<double>(0, (s, c) => s + c.fuelCost);
    final net = revTotal - totalCosts;
    final unpriced = trips.where((t) => !t.isPriced).length;

    // Per-vehicle rollup (union of trips + cost-only vehicles).
    final costByVeh = {for (final c in costs) c.vehicleId: c};
    final byVehicle = <String, _VehAgg>{};
    for (final t in trips) {
      final vid = t.vehicleId ?? '—';
      final agg = byVehicle.putIfAbsent(
        vid,
        () => _VehAgg(reg: t.truckReg ?? 'Unassigned'),
      );
      agg.trips++;
      agg.tons += t.netTons ?? 0;
      agg.revenue += t.revenue ?? 0;
      if (t.truckReg != null) agg.reg = t.truckReg!;
    }
    for (final c in costs) {
      byVehicle.putIfAbsent(
        c.vehicleId,
        () => _VehAgg(reg: c.reg ?? 'Vehicle'),
      );
    }
    for (final entry in byVehicle.entries) {
      entry.value.cost = costByVeh[entry.key]?.totalCost ?? 0;
    }
    final vehicleRows = byVehicle.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    // Per-route rollup.
    final byRoute = <String, _RouteAgg>{};
    for (final t in trips) {
      final rid = t.routeId ?? t.tripId;
      final agg = byRoute.putIfAbsent(
        rid,
        () => _RouteAgg(
          label: '${t.commodity ?? 'Load'} → ${t.customerName ?? '—'}',
        ),
      );
      agg.trips++;
      agg.tons += t.netTons ?? 0;
      agg.revenue += t.revenue ?? 0;
    }
    final routeRows = byRoute.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // KPI cards
        LayoutBuilder(
          builder: (context, c) {
            final cols = c.maxWidth > 820 ? 4 : (c.maxWidth > 420 ? 2 : 1);
            const gap = 12.0;
            final w = (c.maxWidth - gap * (cols - 1)) / cols;
            final tiles = [
              MlStatCard(
                label: 'Total revenue',
                value: money(revTotal),
                icon: Icons.payments_outlined,
                tone: MlTone.accent,
              ),
              MlStatCard(
                label: 'This month',
                value: money(revM),
                icon: Icons.calendar_month_outlined,
                tone: MlTone.transit,
              ),
              MlStatCard(
                label: 'Costs (fuel + maint.)',
                value: money(totalCosts),
                icon: Icons.local_gas_station_outlined,
                tone: MlTone.warn,
              ),
              MlStatCard(
                label: 'Net profit',
                value: money(net),
                icon: Icons.trending_up_rounded,
                tone: net >= 0 ? MlTone.done : MlTone.error,
              ),
            ];
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [for (final t in tiles) SizedBox(width: w, child: t)],
            );
          },
        ),
        if (unpriced > 0) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 15,
                color: MlSemantic.of(context).textFaint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$unpriced delivered trip(s) have no rate set yet, so their '
                  'revenue is not counted. They show as "—" below.',
                  style: TextStyle(
                    fontSize: 13,
                    color: MlSemantic.of(context).textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        // Revenue period windows
        _SectionCard(
          title: 'Revenue by period',
          icon: Icons.timeline_outlined,
          meta: 'Total ${money(revTotal)}',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _PeriodTile('Day', money(revD)),
              _PeriodTile('Week', money(revW)),
              _PeriodTile('Month', money(revM)),
              _PeriodTile('Year', money(revY)),
              _PeriodTile('Total', money(revTotal), strong: true),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Per-vehicle
        _SectionCard(
          title: 'By vehicle',
          icon: Icons.local_shipping_outlined,
          meta: mlCount(vehicleRows.length, 'vehicle'),
          child: MlDataTable(
            columns: const [
              MlColumn('Vehicle', flex: 3),
              MlColumn('Trips', flex: 1, align: TextAlign.right),
              MlColumn('Tons', flex: 2, align: TextAlign.right),
              MlColumn('Revenue', flex: 2, align: TextAlign.right),
              MlColumn('Costs', flex: 2, align: TextAlign.right),
              MlColumn('Net', flex: 2, align: TextAlign.right),
            ],
            rows: [
              for (final v in vehicleRows)
                [
                  _plate(context, v.reg),
                  _mono(context, '${v.trips}'),
                  _mono(context, EarningsScreen._tons(v.tons)),
                  _mono(context, money(v.revenue)),
                  _mono(context, money(v.cost), muted: true),
                  _mono(context, money(v.revenue - v.cost), strong: true),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Per-route
        _SectionCard(
          title: 'By route',
          icon: Icons.alt_route_outlined,
          meta: mlCount(routeRows.length, 'route'),
          child: MlDataTable(
            columns: const [
              MlColumn('Route', flex: 4),
              MlColumn('Trips', flex: 1, align: TextAlign.right),
              MlColumn('Tons', flex: 2, align: TextAlign.right),
              MlColumn('Revenue', flex: 2, align: TextAlign.right),
            ],
            rows: [
              for (final r in routeRows)
                [
                  _text(context, r.label),
                  _mono(context, '${r.trips}'),
                  _mono(context, EarningsScreen._tons(r.tons)),
                  _mono(context, money(r.revenue)),
                ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Per-trip detail + export
        _SectionCard(
          title: 'Trips',
          icon: Icons.receipt_long_outlined,
          meta: mlCount(trips.length, 'trip'),
          trailing: MlButton.outline(
            label: 'Export',
            icon: Icons.download_outlined,
            compact: true,
            onPressed: () => ReconExporter.pickFormatAndExport(
              context,
              title: 'Transporter earnings',
              filenameBase: 'earnings',
              headers: const [
                'DATE',
                'REFERENCE',
                'TRUCK',
                'CUSTOMER',
                'PRODUCT',
                'NET TONS',
                'RATE/TON',
                'REVENUE',
                'DIRECT COST',
                'ALLOCATED COST',
                'TOTAL COST',
                'NET',
                'STATUS',
              ],
              rows: [
                for (final t in trips)
                  [
                    EarningsScreen._dateFmt.format(t.updatedAt),
                    t.reference ?? '',
                    t.truckReg ?? '',
                    t.customerName ?? '',
                    t.commodity ?? '',
                    t.netTons?.toStringAsFixed(2) ?? '',
                    t.ratePerTon?.toStringAsFixed(2) ?? '',
                    t.revenue?.toStringAsFixed(2) ?? '',
                    t.directCost.toStringAsFixed(2),
                    t.allocatedCost.toStringAsFixed(2),
                    t.totalCost.toStringAsFixed(2),
                    t.net?.toStringAsFixed(2) ?? '',
                    t.status ?? '',
                  ],
              ],
              summary: {
                'Total revenue': money(revTotal),
                'Fuel': money(totalFuel),
                'Total costs': money(totalCosts),
                'Net': money(net),
              },
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Net per trip = revenue − its share of costs. Costs tagged to a '
                'trip count directly; a vehicle\'s untagged fuel, tyres, tolls '
                'and maintenance are split across its trips by tonnage.',
                style: TextStyle(
                  fontSize: 13,
                  color: MlSemantic.of(context).textMuted,
                ),
              ),
              const SizedBox(height: 12),
              MlDataTable(
                columns: const [
                  MlColumn('Truck', flex: 2),
                  MlColumn('Customer', flex: 3),
                  MlColumn('Tons', flex: 2, align: TextAlign.right),
                  MlColumn('Revenue', flex: 2, align: TextAlign.right),
                  MlColumn('Cost', flex: 2, align: TextAlign.right),
                  MlColumn('Net', flex: 2, align: TextAlign.right),
                ],
                rows: [
                  for (final t in trips)
                    [
                      _plate(context, t.truckReg ?? '—'),
                      _text(context, t.customerName ?? '—'),
                      _mono(context, EarningsScreen._tons(t.netTons ?? 0)),
                      _mono(context, money(t.revenue)),
                      _mono(context, money(t.totalCost), muted: true),
                      _mono(context, money(t.net), strong: true),
                    ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _plate(BuildContext context, String reg) => Align(
    alignment: Alignment.centerLeft,
    child: MlPlatePill(reg, fontSize: 12),
  );

  Widget _text(BuildContext context, String s) => Text(
    s,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 14, color: MlSemantic.of(context).textBody),
  );

  Widget _mono(
    BuildContext context,
    String s, {
    bool muted = false,
    bool strong = false,
  }) => Text(
    s,
    textAlign: TextAlign.right,
    maxLines: 1,
    style: TextStyle(
      fontFamily: MlTokens.fontMono,
      fontSize: 13,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
      color: muted
          ? MlSemantic.of(context).textFaint
          : MlSemantic.of(context).textStrong,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

class _VehAgg {
  String reg;
  int trips = 0;
  double tons = 0;
  double revenue = 0;
  double cost = 0;
  _VehAgg({required this.reg});
}

class _RouteAgg {
  final String label;
  int trips = 0;
  double tons = 0;
  double revenue = 0;
  _RouteAgg({required this.label});
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  /// S5-22's meta line. Threaded through the wrapper rather than set on
  /// the four call sites' `MlSectionTitle`s directly, because the wrapper
  /// is the thing that owns the header — bypassing it would put two ways
  /// of heading a card back into one screen.
  final String? meta;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    return MlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The action goes in the header's own slot rather than a Row wrapped
          // around it: a Row hands an unflexed button UNBOUNDED width
          // (CLAUDE.md §10.4) and squeezes the Expanded title to whatever is
          // left, which on a phone is less than the title needs. The slot
          // drops the action under the title instead.
          //
          // `action` is nullable, so the caller's optional `trailing` passes
          // straight through — the old code guarded it with a collection-if
          // inside the Row's children.
          MlSectionTitle(
            title,
            icon: icon,
            meta: meta,
            margin: EdgeInsets.zero,
            action: trailing,
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _PeriodTile extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _PeriodTile(this.label, this.value, {this.strong = false});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final tone = (strong ? MlTone.accent : MlTone.neutral);
    return Container(
      width: 150,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: tone.well(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(MlTokens.rMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: semantic.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontFamily: MlTokens.fontMono,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: semantic.textStrong,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
