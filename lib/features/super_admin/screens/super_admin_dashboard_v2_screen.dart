import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';
import 'package:flutter_application_1/features/portal/services/dispute_service.dart';
import 'package:flutter_application_1/core/design/shell/ml_window_class.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/features/super_admin/data/models/company_monthly_ops_stats.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_dashboard.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screens_core.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav_ids.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/tokens/ml_console_palettes.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/core/utils/ml_count.dart';

/// Super-admin dashboard — the v3 layout from the 2026-08-08 design drop,
/// fed from live data instead of the drop's sample constants.
///
/// **This is the console landing screen** — `/super-admin`, promoted
/// 2026-08-14 by client ruling. `/super-admin/dashboard-v2` now redirects here
/// so old bookmarks keep working, and the previous `SuperAdminDashboardScreen`
/// (1,762 lines) is deleted rather than left as unreachable dead code.
///
/// It had sat at `/super-admin/dashboard-v2` with no nav entry pointing at it
/// since the 2026-08-08 drop — reachable only by typing the URL, while every
/// admin landed on the old screen. It is also the design reference the rest of
/// the portal is being migrated onto; see `docs/design-reference.md`.
///
/// Where the drop showed a figure this system has no source for, the tile is
/// derived from something real or left blank rather than filled with a
/// plausible number; see [SuperAdminDashboardV2ViewModel].
class SuperAdminDashboardV2Screen extends ConsumerWidget {
  const SuperAdminDashboardV2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider);

    // Everything below the registry tiles degrades to an empty section rather
    // than blocking the whole page on a slow secondary query.
    final orgs = ref.watch(organizationsProvider).valueOrNull ??
        const <Map<String, dynamic>>[];
    final rows = ref.watch(rawReconRowsProvider(null)).valueOrNull ??
        const <RawReconRow>[];

    MonthlyInsightsBundle? bundle(String orgType) =>
        ref.watch(monthlyInsightsBundleProvider(orgType)).valueOrNull;

    int queue(String type) =>
        ref.watch(adminPendingRequestCountProvider(type)) ?? 0;

    final transportation =
        ref.watch(adminRequestQueueProvider('transportation')).valueOrNull ??
            const [];

    // The phone's "Needs your attention" list also counts open disputes.
    // Read only on a phone: the desktop dashboard does not show the list.
    final phone = MlWindowClass.of(context).usesBottomNav;
    final openDisputes = !phone
        ? 0
        : ref
                .watch(reconDisputesProvider(null))
                .valueOrNull
                ?.where((d) =>
                    d.status == DisputeStatus.open ||
                    d.status == DisputeStatus.underReview)
                .length ??
            0;

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _Error(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(dashboardStatsProvider),
      ),
      data: (stats) {
        final vm = SuperAdminDashboardV2ViewModel.from(
          stats: stats,
          organizations: orgs,
          rows: rows,
          transporters: bundle('transporter'),
          buyers: bundle('buyer'),
          mines: bundle('mineSupplier'),
          mineTransportCount:
              transportation.where((r) => r.isFromMine).length,
          buyerTransportCount:
              transportation.where((r) => !r.isFromMine).length,
          productCount: queue('product'),
          buyerRequestCount: queue('buyer'),
        );

        final mineTransport = transportation.where((r) => r.isFromMine).length;
        return MineLinkDashboardScreen(
          onNavigate: (id) => _navigate(context, id),
          attention: !phone
              ? null
              : dashboardAttentionItems(
                  expiredCompanies: SuperAdminDashboardV2ViewModel._int(stats['expiredCompanies']),
                  tokensExpiringSoon: SuperAdminDashboardV2ViewModel._int(stats['tokensExpiringSoon']),
                  openTokenRequests: SuperAdminDashboardV2ViewModel._int(stats['openTokenRequests']),
                  mineTransport: mineTransport,
                  buyerTransport: transportation.length - mineTransport,
                  productRequests: queue('product'),
                  buyerRequests: queue('buyer'),
                  openDisputes: openDisputes,
                  openWaybills:
                      bundle('transporter')?.aggregate.pendingWaybills ?? 0,
                ),
          orgAggregates: vm.orgAggregates,
          pendingRequests: vm.pendingRequests,
          registry: vm.registry,
          recentOrgs: vm.recentOrgs,
          // The view model already derives these three and puts two of them on
          // the registry tiles as deltas. The screen was drawing hardcoded
          // stand-ins beside them — see the fields' docs on
          // MineLinkDashboardScreen. Same `stats` map, same read helper.
          newCompanies24h: (stats['newCompanies24h'] as num?)?.toInt(),
          newUsers24h: (stats['newUsers24h'] as num?)?.toInt(),
          expiredCompanies: (stats['expiredCompanies'] as num?)?.toInt(),
        );
      },
    );
  }

  /// The screen emits sidebar-style nav ids. Most resolve through the sidebar's
  /// own map; the rest are dashboard-only ids with no nav row of their own.
  static void _navigate(BuildContext context, String id) {
    final path = dashboardNavRoute(id);
    if (path != null) context.go(path);
  }
}

/// Nav id → route for the ids this screen emits.
///
/// Falls through to [consoleNavRoutes] so a destination is never defined in
/// two places. Returns null for ids with no destination (`export` is an
/// action the drop drew but this build has no report generator behind).
String? dashboardNavRoute(String id) {
  switch (id) {
    // Registry tiles deep-link into the org list with a status pre-applied;
    // the route already accepts `?status=`.
    case 'orgs':
      return '/super-admin/organizations';
    case 'orgs.active':
      return '/super-admin/organizations?status=active';
    case 'orgs.expired':
      return '/super-admin/organizations?status=expired';
    case 'orgs.suspended':
      return '/super-admin/organizations?status=suspended';
    case 'users':
    case 'users.active':
      return '/super-admin/users';
    case 'register':
      return '/super-admin/register-company';
    // Group parent — open the first transport inbox.
    case 'requests':
      return '/super-admin/requests/transportation-mine';
    case 'export':
      return null;
    // "Needs your attention" rows (phone).
    case 'attention.expiring':
      return '/super-admin/organizations?status=active';
    case 'attention.waybills':
      return '/super-admin/recon-tables';
    case 'attention.disputes':
      return '/super-admin/disputes';
  }
  return consoleNavRoutes[id];
}

/// The dashboard's "Needs your attention" list (admin phone audit,
/// 2026-10-24): every queue with something in it, most urgent first, and
/// nothing for a queue that is empty — so the first thing on the phone is
/// what to do, not a screen of zeros to scroll through.
///
/// Open waybills are counted on the transporter side: a load has one
/// transporter but also a mine and a buyer, so summing the sides would count
/// every open waybill three times.
List<MlAttentionItem> dashboardAttentionItems({
  required int expiredCompanies,
  required int tokensExpiringSoon,
  required int openTokenRequests,
  required int mineTransport,
  required int buyerTransport,
  required int productRequests,
  required int buyerRequests,
  required int openDisputes,
  required int openWaybills,
}) {
  MlAttentionItem? item(int n, String id, String label, String detail,
          IconData icon, MlChipTone tone) =>
      n <= 0
          ? null
          : MlAttentionItem(
              id: id, label: label, detail: detail, count: n, icon: icon, tone: tone);
  return [
    item(expiredCompanies, 'orgs.expired', 'Access expired',
        '${mlCount(expiredCompanies, 'company', 'companies')} cannot use the app',
        Icons.lock_clock_outlined, MlChipTone.red),
    item(openDisputes, 'attention.disputes', 'Open disputes',
        'Reconciliation disputes waiting on a decision',
        Icons.gavel_outlined, MlChipTone.red),
    item(openTokenRequests, 'tokens.requests', 'Token requests',
        'Waiting for approval', Icons.token_outlined, MlChipTone.amber),
    item(tokensExpiringSoon, 'attention.expiring', 'Tokens expiring',
        'Within 7 days', Icons.timer_outlined, MlChipTone.amber),
    item(mineTransport + buyerTransport, 'requests.mine-transport',
        'Requested routes',
        '$mineTransport from mines · $buyerTransport from buyers',
        Icons.alt_route_rounded, MlChipTone.cyan),
    item(productRequests, 'requests.product', 'Requested product',
        'Buyers asking for a product listing', Icons.inventory_2_outlined,
        MlChipTone.violet),
    item(buyerRequests, 'requests.buyers', 'Requested buyers',
        'Mines asking for buyer connections',
        Icons.person_add_alt_1_outlined, MlChipTone.amber),
    item(openWaybills, 'attention.waybills', 'Open waybills',
        'Loads this month without a closed-out waybill',
        Icons.receipt_long_outlined, MlChipTone.amber),
  ].whereType<MlAttentionItem>().toList();
}

// ===========================================================================
// View model — the only place raw data becomes screen figures
// ===========================================================================

/// Maps platform stats, the org list, the monthly bundles and weighbridge rows
/// onto the dashboard's props.
///
/// Kept public and free of Flutter context so it can be unit-tested without
/// pumping a widget.
@immutable
class SuperAdminDashboardV2ViewModel {
  const SuperAdminDashboardV2ViewModel({
    required this.orgAggregates,
    required this.pendingRequests,
    required this.registry,
    required this.recentOrgs,
  });

  final List<MlOrgAggregate> orgAggregates;
  final List<MlPendingRequest> pendingRequests;
  final List<MlRegistryStat> registry;
  final List<MlRecentOrg> recentOrgs;

  static const List<List<Color>> _avatarPalette =
      MlConsolePalettes.avatarRamp;

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static int _int(Object? v) => (v as num?)?.toInt() ?? 0;
  static double _double(Object? v) => (v as num?)?.toDouble() ?? 0;

  /// Tons per day over the trailing [days] window, oldest first.
  ///
  /// All-zero when nothing moved — a flat line is the honest render, and the
  /// sparkline's own range guard handles it.
  static List<double> _spark(
    List<RawReconRow> rows,
    bool Function(RawReconRow) keep,
    DateTime now, {
    int days = 10,
  }) {
    final out = List<double>.filled(days, 0);
    final start =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    for (final r in rows) {
      if (!keep(r)) continue;
      final d = DateTime(r.tripDate.year, r.tripDate.month, r.tripDate.day);
      final i = d.difference(start).inDays;
      if (i >= 0 && i < days) out[i] += r.netMass ?? 0;
    }
    return out;
  }

  static String _tons(double v) => '${mlThousands(v.round())} t';

  /// `mineSupplier` → the label the table's type tabs filter on. The tabs
  /// compare against these exact strings, so they are not free text.
  static String _typeLabel(String? orgType) {
    switch (orgType) {
      case 'mineSupplier':
        return 'Mine';
      case 'buyer':
        return 'Buyer';
      case 'transporter':
        return 'Transporter';
    }
    return 'Other';
  }

  static String _titleCase(String? s) {
    final v = (s ?? '').trim();
    if (v.isEmpty) return 'Unknown';
    return v[0].toUpperCase() + v.substring(1).toLowerCase();
  }

  /// The shortest useful part of a physical address — usually the suburb or
  /// town at the tail. Blank addresses show an em dash, not a guessed city.
  static String _location(Object? address) {
    final v = (address as String?)?.trim() ?? '';
    if (v.isEmpty) return '—';
    final parts = v
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '—';
    final tail = parts.length >= 2 ? parts[parts.length - 2] : parts.last;
    return tail.length > 22 ? '${tail.substring(0, 21)}…' : tail;
  }

  static String _shortDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} '${d.year % 100}";

  /// `42d 08 : 34 : 55`, matching the drop's countdown column.
  static String _countdown(Duration d) {
    final days = d.inDays;
    final h = d.inHours.remainder(24).toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "${days.toString().padLeft(2, '0')}d $h : $m : $s";
  }

  static MlOrgAggregate _aggregate({
    required String id,
    required String title,
    required IconData icon,
    required MlChipTone tone,
    required Color sparkColor,
    required OrgTypeAggregateStats? a,
    required List<double> spark,
    required List<MapEntry<String, String>> Function(OrgTypeAggregateStats)
        metrics,
    required String Function(OrgTypeAggregateStats) subtitle,
  }) {
    return MlOrgAggregate(
      id: id,
      title: title,
      subtitle: a == null ? 'Loading…' : subtitle(a),
      icon: icon,
      tone: tone,
      metrics: a == null
          ? const [MapEntry('—', '—')]
          : metrics(a),
      spark: spark,
      sparkColor: sparkColor,
    );
  }

  static SuperAdminDashboardV2ViewModel from({
    required Map<String, dynamic> stats,
    required List<Map<String, dynamic>> organizations,
    required List<RawReconRow> rows,
    required MonthlyInsightsBundle? transporters,
    required MonthlyInsightsBundle? buyers,
    required MonthlyInsightsBundle? mines,
    required int mineTransportCount,
    required int buyerTransportCount,
    required int productCount,
    required int buyerRequestCount,
    DateTime? now,
  }) {
    final today = now ?? MlTime.now();

    // ---- 1. org-type rollups ----------------------------------------------
    final orgAggregates = <MlOrgAggregate>[
      _aggregate(
        id: 'insights.transporters',
        title: 'Transporters',
        icon: Icons.local_shipping_outlined,
        tone: MlChipTone.cyan,
        sparkColor: MlConsolePalettes.sparkTransporter,
        a: transporters?.aggregate,
        spark: _spark(
            rows, (r) => (r.transporterName ?? '').isNotEmpty, today),
        subtitle: (a) =>
            '${mlCount(a.companyCount, 'organization')} · ${a.fleetVehiclesTotal} fleet',
        metrics: (a) => [
          MapEntry('Trips', mlThousands(a.activeTripsApprox)),
          MapEntry('Tons', _tons(a.tonsMoved)),
          MapEntry('Fleet', '${a.fleetVehiclesTotal}'),
        ],
      ),
      _aggregate(
        id: 'insights.buyers',
        title: 'Buyers',
        icon: Icons.shopping_cart_outlined,
        tone: MlChipTone.violet,
        sparkColor: MlConsolePalettes.sparkBuyer,
        a: buyers?.aggregate,
        spark: _spark(rows, (r) => (r.customerName ?? '').isNotEmpty, today),
        subtitle: (a) => mlCount(a.companyCount, 'organization'),
        metrics: (a) => [
          MapEntry('Orders', mlThousands(a.transactionsTotal)),
          MapEntry('Tons', _tons(a.tonsMoved)),
          MapEntry('Waybills', '${a.completedWaybills}'),
        ],
      ),
      _aggregate(
        id: 'insights.mines',
        title: 'Mines / Suppliers',
        icon: Icons.terrain_rounded,
        tone: MlChipTone.amber,
        sparkColor: MlConsolePalettes.sparkMine,
        a: mines?.aggregate,
        spark: _spark(rows, (r) => (r.sourceName ?? '').isNotEmpty, today),
        subtitle: (a) => mlCount(a.companyCount, 'organization'),
        metrics: (a) => [
          MapEntry('Tons', _tons(a.tonsMoved)),
          MapEntry('Loads', mlThousands(a.transactionsTotal)),
          MapEntry('Waybills', '${a.completedWaybills}'),
        ],
      ),
    ];

    // ---- 2. pending requests ----------------------------------------------
    // The drop drew three cards; the transport inbox is split by requesting-org
    // type, so card 1 carries the combined figure and opens the mine inbox.
    final transportTotal = mineTransportCount + buyerTransportCount;
    final pendingRequests = <MlPendingRequest>[
      MlPendingRequest(
        id: 'requests.mine-transport',
        label: 'Requested routes',
        icon: Icons.alt_route_rounded,
        count: transportTotal,
        sub: '$mineTransportCount from mines · $buyerTransportCount from '
            'buyers — awaiting review.',
        tone: MlChipTone.cyan,
      ),
      MlPendingRequest(
        id: 'requests.product',
        label: 'Requested product',
        icon: Icons.inventory_2_outlined,
        count: productCount,
        sub: 'Buyers requesting a new product listing.',
        tone: MlChipTone.violet,
      ),
      MlPendingRequest(
        id: 'requests.buyers',
        label: 'Requested buyers',
        icon: Icons.person_add_alt_1_outlined,
        count: buyerRequestCount,
        sub: 'Mines requesting buyer connections and roster access.',
        tone: MlChipTone.amber,
      ),
    ];

    // ---- 3. platform registry ---------------------------------------------
    final total = _int(stats['totalCompanies']);
    final active = _int(stats['activeCompanies']);
    final expired = _int(stats['expiredCompanies']);
    final suspended = _int(stats['suspendedCompanies']);
    final newCompanies = _int(stats['newCompanies24h']);
    final newUsers = _int(stats['newUsers24h']);
    final newTokenReqs = _int(stats['newTokenRequests24h']);
    final newExpired = _int(stats['newExpired24h']);
    final healthy = total > 0 ? (active / total * 100).round() : 0;
    final tonsManaged = _double(stats['totalTonsManaged']);

    final registry = <MlRegistryStat>[
      MlRegistryStat(
        id: 'orgs',
        label: 'Total companies',
        value: mlThousands(total),
        icon: Icons.apartment_rounded,
        tone: MlChipTone.cyan,
        sub: 'across all org types',
        delta: newCompanies > 0 ? '$newCompanies' : null,
        deltaTone: newCompanies > 0 ? MlDelta.up : MlDelta.none,
      ),
      MlRegistryStat(
        id: 'orgs.active',
        label: 'Active',
        value: mlThousands(active),
        icon: Icons.check_circle_outline_rounded,
        tone: MlChipTone.green,
        sub: 'tokens valid',
        delta: total > 0 ? '$healthy% healthy' : null,
        deltaTone: total > 0 ? MlDelta.good : MlDelta.none,
      ),
      MlRegistryStat(
        id: 'orgs.expired',
        label: 'Expired',
        value: mlThousands(expired),
        icon: Icons.timer_off_outlined,
        tone: MlChipTone.amber,
        sub: expired > 0 ? 'action needed' : 'none outstanding',
        delta: newExpired > 0 ? '$newExpired' : null,
        deltaTone: newExpired > 0 ? MlDelta.warn : MlDelta.none,
      ),
      MlRegistryStat(
        id: 'orgs.suspended',
        label: 'Suspended',
        value: mlThousands(suspended),
        icon: Icons.block_rounded,
        tone: MlChipTone.red,
        sub: 'manually held',
        deltaTone: MlDelta.none,
      ),
      MlRegistryStat(
        id: 'users',
        label: 'Total users',
        value: mlThousands(_int(stats['totalUsers'])),
        icon: Icons.groups_outlined,
        tone: MlChipTone.blue,
        sub: 'across all orgs',
        delta: newUsers > 0 ? '$newUsers' : null,
        deltaTone: newUsers > 0 ? MlDelta.up : MlDelta.none,
      ),
      MlRegistryStat(
        id: 'tokens.requests',
        label: 'Open token requests',
        value: mlThousands(_int(stats['openTokenRequests'])),
        icon: Icons.token_outlined,
        tone: MlChipTone.amber,
        sub: 'awaiting approval',
        delta: newTokenReqs > 0 ? '$newTokenReqs' : null,
        deltaTone: newTokenReqs > 0 ? MlDelta.warn : MlDelta.none,
      ),
      MlRegistryStat(
        id: 'users.active',
        label: 'Active users right now',
        value: mlThousands(_int(stats['activeUsersNow'])),
        icon: Icons.bolt_rounded,
        tone: MlChipTone.cyan,
        sub: 'using the app · last 2 min',
        delta: 'Live',
        deltaTone: MlDelta.live,
      ),
      MlRegistryStat(
        id: 'insights.mines',
        label: 'Total tons managed',
        value: mlThousands(tonsManaged.round()),
        unit: 't',
        icon: Icons.scale_rounded,
        tone: MlChipTone.green,
        sub: 'platform total',
        deltaTone: MlDelta.none,
      ),
    ];

    // ---- 4. recently active organizations ---------------------------------
    // Real per-company user counts come from the monthly bundles, which are the
    // only source that reports employees per company.
    final employeesById = <String, int>{};
    for (final b in [transporters, buyers, mines]) {
      for (final c in b?.companies ?? const <CompanyMonthlyOpsStats>[]) {
        employeesById[c.companyId] = c.employees;
      }
    }

    final sorted = [...organizations]..sort((a, b) {
        final at = DateTime.tryParse('${a['created_at']}');
        final bt = DateTime.tryParse('${b['created_at']}');
        if (at == null || bt == null) return 0;
        return bt.compareTo(at);
      });

    final recentOrgs = <MlRecentOrg>[];
    for (var i = 0; i < sorted.length && i < 6; i++) {
      final o = sorted[i];
      final id = '${o['id']}';
      final expiresAt = DateTime.tryParse('${o['token_expires_at']}');
      // `today` is a WALL CLOCK (`MlTime.now()`), `expiresAt` is an INSTANT
      // straight off `DateTime.parse`. Subtracting one from the other, or
      // handing the wall clock to `MlTime.ago`'s `asOf:`, mixes the two units
      // — and `MlTime.instant()`'s own doc says why that is only ever right in
      // South Africa: the wall clock's epoch depends on the reader's device
      // offset. So the comparison happens on ONE side of the boundary, in
      // instants, and the wall clock keeps the calendar work it is for.
      final nowInstant = MlTime.toServer(today);

      final MlExpiry state;
      final String expiry;
      if (expiresAt == null) {
        state = MlExpiry.warn;
        expiry = 'no token';
      } else if (expiresAt.isBefore(nowInstant)) {
        state = MlExpiry.expired;
        // "Expired · 5d ago", the reference's own wording — not the bare word.
        // How long ago it lapsed is the thing an admin acts on, this row
        // already holds the date, and `docs/design-reference` renders it that
        // way. Lower-case `expired` also read as a wire value beside the
        // title-cased `Active` / `Suspended` in the column to its left.
        // `MlTime.ago`, not a hand-rolled "Nd ago" — the guard
        // `one-vocabulary-for-time-ago` caught this the moment it was written,
        // which is what it is for. Past a week it falls back to the date,
        // which is the right thing for a token that lapsed months back.
        expiry = 'Expired · ${MlTime.ago(expiresAt, asOf: nowInstant)}';
      } else {
        final left = expiresAt.difference(nowInstant);
        state = left.inDays <= 14 ? MlExpiry.warn : MlExpiry.ok;
        expiry = _countdown(left);
      }

      recentOrgs.add(MlRecentOrg(
        id: id,
        name: '${o['company_name'] ?? 'Unnamed'}',
        type: _typeLabel(o['org_type'] as String?),
        status: _titleCase(o['status'] as String?),
        location: _location(o['physical_address']),
        users: employeesById[id] ?? 0,
        seatsUsed: _int(o['seats_used']),
        seats: _int(o['seat_limit']),
        expiry: expiry,
        // THE EXPIRY DATE, not the creation date.
        //
        // This cell sits under a column headed TOKEN EXPIRY, directly beside
        // the countdown, and it printed `created_at`. Photographed 2026-08-21:
        // four rows read "107d 22 : 30 : 00 · 01 Jul '26" — a token with 107
        // days left, next to a date four months in the past — and the expired
        // row read "expired · 01 Jul '26" for a token that lapsed on 1 August.
        // The only date this column can mean is the one it is named after.
        date: expiresAt == null ? '—' : _shortDate(expiresAt),
        expiryState: state,
        avatarColors: _avatarPalette[i % _avatarPalette.length],
      ));
    }

    return SuperAdminDashboardV2ViewModel(
      orgAggregates: orgAggregates,
      pendingRequests: pendingRequests,
      registry: registry,
      recentOrgs: recentOrgs,
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = MlGlass.of(context);
    return Container(
      color: t.bg0,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 34, color: t.bad),
          const SizedBox(height: 12),
          Text(
            "Couldn't load the platform dashboard",
            style: context.mlText.titleMedium.copyWith(
              color: t.inkHi,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.mlText.bodySmall.copyWith(color: t.inkMid),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
