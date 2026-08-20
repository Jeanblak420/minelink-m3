import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/core/widgets/app_navigation_back_button.dart';
import 'package:flutter_application_1/core/widgets/osm_tile_layer.dart';
import 'package:flutter_application_1/features/portal/models/live_trip_position.dart';
import 'package:flutter_application_1/features/portal/providers/live_tracking_provider.dart';
import 'package:flutter_application_1/features/portal/widgets/map_fit.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/operations/screens/operations_hub_screen.dart';
import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/portal_navigation.dart';
import 'package:flutter_application_1/features/portal/providers/mirror_company_context_provider.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/features/super_admin/data/models/company_monthly_ops_stats.dart';
import 'package:flutter_application_1/features/super_admin/screens/company_employee_register_screen.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/utils/super_admin_insights_export.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/tokens/ml_control_room_palette.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

final _log = LoggerFactory.getLogger('SuperAdminCompanyMirror');

/// One row in the header search dropdown.
class _SearchHit {
  final IconData icon;
  final String kind; // 'User' | 'Vehicle' | 'Load'
  final String title;
  final String sub;

  /// Keyword used to find the tab a tap should open.
  final String tabKeyword;
  const _SearchHit(this.icon, this.kind, this.title, this.sub, this.tabKeyword);
}

/// Searchable index for one company: employees (users), fleet vehicles
/// (assets) and captured loads (routes). Loaded once per mirror visit;
/// each source is best-effort so a missing table never kills the search.
final _mirrorSearchIndexProvider = FutureProvider.autoDispose
    .family<List<_SearchHit>, String>((ref, companyId) async {
      final db = SupabaseConfig.client;
      final hits = <_SearchHit>[];

      try {
        final emps = await db
            .from('employees')
            .select('first_name, last_name, role, status')
            .eq('company_id', companyId);
        for (final e in emps as List) {
          final m = Map<String, dynamic>.from(e as Map);
          final name = [
            m['first_name'],
            m['last_name'],
          ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
          hits.add(
            _SearchHit(
              Icons.person_outline,
              'User',
              name.isEmpty ? 'Employee' : name,
              (m['role'] as String?) ?? 'Team member',
              'admin',
            ),
          );
        }
      } catch (e) {
        // One search source failing must not empty the whole result set.
        // Logged, never swallowed (P0-11 / S1-7).
        _log.d('company-mirror search: employees source unavailable: $e');
      }

      try {
        final vs = await db
            .from('fleet_vehicles')
            .select(
              'vehicle_registration_number, driver_first_name, driver_last_name',
            )
            .eq('company_id', companyId);
        for (final v in vs as List) {
          final m = Map<String, dynamic>.from(v as Map);
          final reg =
              (m['vehicle_registration_number'] as String?) ?? 'Vehicle';
          final driver = [
            m['driver_first_name'],
            m['driver_last_name'],
          ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' ');
          hits.add(
            _SearchHit(
              Icons.local_shipping_outlined,
              'Vehicle',
              reg,
              driver.isEmpty ? 'No driver assigned' : driver,
              'fleet',
            ),
          );
        }
      } catch (e) {
        // One search source failing must not empty the whole result set.
        // Logged, never swallowed (P0-11 / S1-7).
        _log.d('company-mirror search: fleet_vehicles source unavailable: $e');
      }

      try {
        final rows = await ref.watch(rawReconRowsProvider(companyId).future);
        for (final r in rows) {
          hits.add(
            _SearchHit(
              Icons.route_outlined,
              'Load',
              r.waybillNumber ?? r.truckReg ?? 'Load',
              [
                if (r.product != null) r.product!,
                if (r.destination != null) '→ ${r.destination}',
              ].join(' '),
              'reconcil',
            ),
          );
        }
      } catch (e) {
        // One search source failing must not empty the whole result set.
        // Logged, never swallowed (P0-11 / S1-7).
        _log.d('company-mirror search: recon rows source unavailable: $e');
      }

      return hits;
    });

/// The mock's "Search assets, routes, users" field — a working autocomplete
/// over this company's employees, vehicles and loads. Picking a result jumps
/// to the tab where that record lives.
class _MirrorSearchBox extends ConsumerWidget {
  final String companyId;
  final List<String> tabLabels;
  const _MirrorSearchBox({required this.companyId, required this.tabLabels});

  int? _tabIndexFor(String keyword) {
    int? find(String kw) {
      for (var i = 0; i < tabLabels.length; i++) {
        if (tabLabels[i].toLowerCase().contains(kw)) return i;
      }
      return null;
    }

    return switch (keyword) {
      'fleet' => find('fleet') ?? find('truck'),
      'admin' => find('admin') ?? find('management') ?? find('workspace'),
      _ => find('reconcil'),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hits =
        ref.watch(_mirrorSearchIndexProvider(companyId)).valueOrNull ??
        const <_SearchHit>[];

    return SizedBox(
      width: 300,
      child: RawAutocomplete<_SearchHit>(
        displayStringForOption: (h) => h.title,
        optionsBuilder: (t) {
          final q = t.text.trim().toLowerCase();
          if (q.length < 2) return const Iterable<_SearchHit>.empty();
          return hits
              .where(
                (h) =>
                    h.title.toLowerCase().contains(q) ||
                    h.sub.toLowerCase().contains(q) ||
                    h.kind.toLowerCase().contains(q),
              )
              .take(12);
        },
        onSelected: (h) {
          final idx = _tabIndexFor(h.tabKeyword);
          if (idx != null) DefaultTabController.of(context).animateTo(idx);
        },
        fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
          controller: controller,
          focusNode: focus,
          style: TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: 13,
            color: MlControlRoom.textStrong,
          ),
          cursorColor: MlControlRoom.blue,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search assets, routes, users',
            hintStyle: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontSize: 13,
              color: MlControlRoom.textMuted,
            ),
            prefixIcon: Icon(Icons.search, size: 18, color: MlControlRoom.textMuted),
            filled: true,
            fillColor: MlControlRoom.surfaceCard,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: MlShape.pill,
              borderSide: BorderSide(color: MlControlRoom.borderCard),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: MlShape.pill,
              borderSide: BorderSide(color: MlControlRoom.blue.withValues(alpha: 0.55)),
            ),
          ),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              width: 340,
              constraints: const BoxConstraints(maxHeight: 320),
              decoration: BoxDecoration(
                color: MlControlRoom.surfaceCard,
                borderRadius: MlShape.radiusLarge,
                border: Border.all(color: MlControlRoom.borderCard),
                boxShadow: const [
                  BoxShadow(
                    color: MlControlRoom.scrim,
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(6),
                children: [
                  for (final h in options)
                    InkWell(
                      borderRadius: MlShape.radiusMedium,
                      onTap: () => onSelected(h),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        child: Row(
                          children: [
                            Icon(h.icon, size: 17, color: MlControlRoom.blue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: MlTokens.fontSans,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: MlControlRoom.textStrong,
                                    ),
                                  ),
                                  if (h.sub.isNotEmpty)
                                    Text(
                                      h.sub,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: MlTokens.fontSans,
                                        fontSize: 12,
                                        color: MlControlRoom.textMuted,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: MlShape.pill,
                                border: Border.all(color: MlControlRoom.borderCard),
                                color: MlControlRoom.surfaceTile,
                              ),
                              child: Text(
                                h.kind,
                                style: TextStyle(
                                  fontFamily: MlTokens.fontSans,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: MlControlRoom.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Same portal tabs as the company’s workspace, scoped by [companyId],
/// read-only (mirror context) — presented as a full-screen "control-room"
/// insights dashboard: hero header, pill tabs, and a Dashboard landing tab
/// built from the company's real monthly rollup + recon records.
class SuperAdminCompanyMirrorScreen extends ConsumerStatefulWidget {
  final String companyId;

  const SuperAdminCompanyMirrorScreen({super.key, required this.companyId});

  @override
  ConsumerState<SuperAdminCompanyMirrorScreen> createState() =>
      _SuperAdminCompanyMirrorScreenState();
}

class _SuperAdminCompanyMirrorScreenState
    extends ConsumerState<SuperAdminCompanyMirrorScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The frame callback can fire after a fast navigate-away has already
      // disposed this screen — using ref then throws.
      if (!mounted) return;
      ref.read(mirrorCompanyIdProvider.notifier).state = widget.companyId;
    });
  }

  @override
  void dispose() {
    // Defer the reset — mutating a provider synchronously while the tree is
    // mid-navigation rebuild throws ("cannot use ref after disposed").
    final notifier = ref.read(mirrorCompanyIdProvider.notifier);
    Future.microtask(() => notifier.state = null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(organizationDetailProvider(widget.companyId));
    final canExport = ref.watch(superAdminCanExportDownloadsProvider);

    return orgAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load company',
        message: friendlyError(e),
      ),
      data: (raw) {
        if (raw == null) {
          return const MlEmptyState(
            icon: Icons.domain_disabled_outlined,
            title: 'Company not found',
            message: 'This organization could not be located.',
          );
        }
        final company = Company.fromJson(raw);
        final baseTabs = PortalNavigation.companyTabs(company.orgType);
        final tabs = [
          PortalTabItem(
            'Dashboard',
            Icons.grid_view_rounded,
            _MirrorDashboardTab(company: company),
          ),
          ...baseTabs,
          PortalTabItem(
            'Operations Hub',
            Icons.precision_manufacturing_outlined,
            OperationsHubScreen(observedCompany: company),
          ),
        ];

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            backgroundColor: MlControlRoom.pageBg,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroHeader(
                  company: company,
                  tabLabels: [for (final t in tabs) t.label],
                  canExport: canExport,
                  onExport: () => _exportMonthlyInsightsCsv(context, company),
                ),
                const _ReadOnlyBanner(),
                _PillTabBar(tabs: tabs),
                Expanded(
                  child: TabBarView(
                    children: tabs.map((t) => t.screen).toList(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Shares one CSV row for this company’s monthly rollup (same window as Insights layer 2).
  Future<void> _exportMonthlyInsightsCsv(
    BuildContext context,
    Company company,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(superAdminRepositoryProvider);
    final orgTypeKey = company.orgType.name;

    try {
      final bundle = await repo.getMonthlyInsightsBundle(orgTypeKey);
      CompanyMonthlyOpsStats? row;
      for (final c in bundle.companies) {
        if (c.companyId == company.id) {
          row = c;
          break;
        }
      }
      if (row == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'No monthly rollup row for this company in the current calendar month.',
            ),
          ),
        );
        return;
      }

      try {
        await repo.logInsightsCsvExport(
          organizationId: company.id,
          companyName: company.companyName,
        );
      } catch (_) {
        // Audit logging is best-effort; export should still proceed.
      }

      await shareCompanyMonthlyStatsCsv(
        stats: row,
        orgTypeLabel: company.orgType.label,
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed. ${friendlyError(e)}')));
    }
  }
}

// ---------------------------------------------------------------------------
// Header / banner / tab chrome
// ---------------------------------------------------------------------------

class _HeroHeader extends StatelessWidget {
  final Company company;
  final List<String> tabLabels;
  final bool canExport;
  final VoidCallback onExport;
  const _HeroHeader({
    required this.company,
    required this.tabLabels,
    required this.canExport,
    required this.onExport,
  });

  Color _orgChipColor(Brightness b) => switch (company.orgType) {
    OrgType.transporter => MlControlRoom.green,
    OrgType.buyer => MlControlRoom.blue,
    OrgType.mineSupplier => MlControlRoom.amber,
  };

  @override
  Widget build(BuildContext context) {
    final chip = _orgChipColor(Theme.of(context).brightness);
    final narrow = MediaQuery.sizeOf(context).width < 900;

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ORGANIZATION INSIGHTS',
          style: TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
            color: MlControlRoom.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              company.companyName,
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontWeight: FontWeight.w800,
                fontSize: narrow ? 24 : 32,
                letterSpacing: -0.5,
                height: 1.05,
                color: MlControlRoom.textStrong,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: chip.withValues(alpha: 0.14),
                borderRadius: MlShape.pill,
                border: Border.all(color: chip.withValues(alpha: 0.45)),
              ),
              child: Text(
                company.orgType.label,
                style: TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: chip,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Full-screen read-only mirror of this organization\'s workspace — '
          'live operational data, recon records and positions.',
          style: TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: 13,
            color: MlControlRoom.textMuted,
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _MirrorSearchBox(companyId: company.id, tabLabels: tabLabels),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: MlShape.pill,
            border: Border.all(color: MlControlRoom.borderCard),
          ),
          child: Text(
            'Read-only mirror',
            style: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MlControlRoom.textMuted,
            ),
          ),
        ),
        if (canExport)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MlTokens.accent,
              foregroundColor: MlTokens.inkOnFill,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: MlShape.pill,
              ),
              textStyle: const TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            onPressed: onExport,
            child: const Text('Export monthly insights'),
          ),
      ],
    );

    // The whole header lives in its own rounded card, inset from the page
    // edges — every region in the mock is a contained card.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 16, 20, 16),
        decoration: BoxDecoration(
          color: MlControlRoom.surfaceCard,
          borderRadius: BorderRadius.circular(MlControlRoom.rCard),
          border: Border.all(color: MlControlRoom.borderCard),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: AppNavigationBackButton(),
            ),
            const SizedBox(width: 4),
            Expanded(child: identity),
            const SizedBox(width: 16),
            actions,
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          color: MlControlRoom.surfaceCard,
          borderRadius: BorderRadius.circular(MlControlRoom.rCard),
          border: Border.all(color: MlControlRoom.borderCard),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, size: 17, color: MlControlRoom.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: 13,
                    color: MlControlRoom.textMuted,
                  ),
                  children: [
                    TextSpan(
                      text: 'Read-only mode. ',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: MlControlRoom.textStrong,
                      ),
                    ),
                    const TextSpan(
                      text:
                          'Edits, deletes, and moves are disabled. You can '
                          'still inspect activity and export data where allowed.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: MlShape.pill,
                border: Border.all(color: MlControlRoom.borderCard),
                color: MlControlRoom.surfaceTile,
              ),
              child: Text(
                'Permissions active',
                style: TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MlControlRoom.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PillTabBar extends StatelessWidget {
  final List<PortalTabItem> tabs;
  const _PillTabBar({required this.tabs});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MlControlRoom.pageBg,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            borderRadius: MlShape.pill,
            color: MlControlRoom.blue.withValues(alpha: 0.16),
            border: Border.all(color: MlControlRoom.blue.withValues(alpha: 0.5)),
          ),
          labelColor: MlControlRoom.textStrong,
          unselectedLabelColor: MlControlRoom.textMuted,
          labelStyle: const TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          labelPadding: const EdgeInsets.symmetric(horizontal: 4),
          tabs: [
            for (final t in tabs)
              Tab(
                height: 40,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(t.label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dashboard landing tab — real data only (monthly rollup + recon records)
// ---------------------------------------------------------------------------

class _MirrorDashboardTab extends ConsumerWidget {
  final Company company;
  const _MirrorDashboardTab({required this.company});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleAsync = ref.watch(
      monthlyInsightsBundleProvider(company.orgType.name),
    );
    final rowsAsync = ref.watch(rawReconRowsProvider(company.id));

    return bundleAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load insights',
        message: friendlyError(e),
      ),
      data: (bundle) {
        CompanyMonthlyOpsStats? stats;
        for (final c in bundle.companies) {
          if (c.companyId == company.id) {
            stats = c;
            break;
          }
        }
        final rows = rowsAsync.valueOrNull ?? const <RawReconRow>[];
        return _DashboardBody(
          company: company,
          stats: stats,
          rows: rows,
          rowsLoading: rowsAsync.isLoading,
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final Company company;
  final CompanyMonthlyOpsStats? stats;
  final List<RawReconRow> rows;
  final bool rowsLoading;
  const _DashboardBody({
    required this.company,
    required this.stats,
    required this.rows,
    required this.rowsLoading,
  });

  static final _tons = NumberFormat('#,##0.0');
  static final _int = NumberFormat('#,##0');

  int get _waybillsDone => stats?.completedWaybills ?? 0;
  int get _waybillsOpen => stats?.pendingWaybills ?? 0;

  double? get _completion {
    final total = _waybillsDone + _waybillsOpen;
    if (total == 0) return null;
    return _waybillsDone / total;
  }

  /// Average time-in → time-out across recon rows that carry both stamps.
  double? get _avgTurnaroundHours {
    var total = Duration.zero;
    var n = 0;
    for (final r in rows) {
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

  /// Net tons per day for the last 7 calendar days (device-local), oldest first.
  List<({DateTime day, double tons})> get _last7Days {
    final today = MlTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 6));
    final byDay = <DateTime, double>{
      for (var i = 0; i < 7; i++) start.add(Duration(days: i)): 0.0,
    };
    for (final r in rows) {
      final d = DateTime(r.tripDate.year, r.tripDate.month, r.tripDate.day);
      if (byDay.containsKey(d)) {
        byDay[d] = byDay[d]! + (r.netMass ?? 0);
      }
    }
    return [for (final e in byDay.entries) (day: e.key, tons: e.value)];
  }

  List<RawReconRow> get _recentRows {
    final sorted = [...rows]
      ..sort((a, b) {
        final ta = a.timeIn ?? a.tripDate;
        final tb = b.timeIn ?? b.tripDate;
        return tb.compareTo(ta);
      });
    return sorted.take(5).toList();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1180;
        final content = wide
            ? _wideLayout(context, constraints.maxWidth)
            : _narrowLayout(context, constraints.maxWidth);
        // Full-bleed control-room layout: the cards own the whole viewport
        // width instead of huddling in a centered column.
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: content,
        );
      },
    );
  }

  Widget _wideLayout(BuildContext context, double maxWidth) {
    // Snapshot card width = viewport minus the scroll padding (16 + 16), the
    // 340px progress column and the 16px gap. Passed down because the card
    // sits inside IntrinsicHeight, where a LayoutBuilder is not allowed.
    final snapshotWidth = maxWidth - 32 - 16 - 340;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _snapshotCard(context, snapshotWidth)),
              const SizedBox(width: 16),
              SizedBox(width: 340, child: _progressColumn(context)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: _tonsChartCard(context)),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: _thisMonthCard(context)),
              const SizedBox(width: 16),
              SizedBox(width: 340, child: _timelineCard(context)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _mapCard(context)),
              const SizedBox(width: 16),
              Expanded(child: _alertsCard(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _narrowLayout(BuildContext context, double maxWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _snapshotCard(context, maxWidth - 32),
        const SizedBox(height: 16),
        _progressColumn(context),
        const SizedBox(height: 16),
        _tonsChartCard(context),
        const SizedBox(height: 16),
        _thisMonthCard(context),
        const SizedBox(height: 16),
        _timelineCard(context),
        const SizedBox(height: 16),
        _mapCard(context),
        const SizedBox(height: 16),
        _alertsCard(context),
      ],
    );
  }

  // ---- shared card scaffold ----

  Widget _card(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MlControlRoom.surfaceCard,
        borderRadius: BorderRadius.circular(MlControlRoom.rCard),
        border: Border.all(color: MlControlRoom.borderCard),
      ),
      child: child,
    );
  }

  Widget _cardTitle(BuildContext context, String title, {String? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: MlControlRoom.textStrong,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: TextStyle(
              fontFamily: MlTokens.fontSans,
              fontSize: 12,
              color: MlControlRoom.textMuted,
            ),
          ),
      ],
    );
  }

  /// Resolves the mirrored tab a snapshot tile should open: the first tab
  /// whose label contains one of [keywords] (checked in keyword order), as
  /// (index, label) into this screen's tab strip — Dashboard first, then the
  /// org's own tabs, then Operations Hub. Null when no tab matches, in which
  /// case the tile renders non-interactive.
  ({int index, String label})? _tabTarget(List<String> keywords) {
    final labels = [
      'Dashboard',
      for (final t in PortalNavigation.companyTabs(company.orgType)) t.label,
      'Operations Hub',
    ];
    for (final kw in keywords) {
      for (var i = 0; i < labels.length; i++) {
        if (labels[i].toLowerCase().contains(kw)) {
          return (index: i, label: labels[i]);
        }
      }
    }
    return null;
  }

  // ---- operational snapshot ----

  Widget _snapshotCard(BuildContext context, double width) {
    final s = stats;
    final completion = _completion;
    // Inner width available to the KPI tiles (card padding is 18 a side).
    // Computed from the passed-down viewport width instead of a
    // LayoutBuilder: this card renders inside IntrinsicHeight, which cannot
    // measure a LayoutBuilder (throws "does not support returning intrinsic
    // dimensions").
    final tilesWidth = width - 36;

    // Each tile is a tap target: Employees opens the dedicated Employee
    // Register screen; the rest jump to the mirrored tab owning their data
    // (resolved per org type — first keyword that matches a tab label).
    final tripsTarget = _tabTarget(
      const ['trucks on route', 'loads & value', 'reconcil'],
    );
    final tonsTarget = _tabTarget(const ['reconcil']);
    final fleetTarget = _tabTarget(
      const ['fleet', 'truck locations', 'live map'],
    );

    Widget kpi(
      IconData icon,
      String label,
      String value,
      String sub,
      ({int index, String label})? target,
    ) {
      return _KpiTile(
        icon: icon,
        label: label,
        value: value,
        sub: sub,
        hint: target == null ? null : 'Open ${target.label}',
        onTap: target == null
            ? null
            : () => DefaultTabController.of(context).animateTo(target.index),
      );
    }

    Widget chipPill(String label, Color color) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: MlShape.pill,
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: MlTokens.fontSans,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      );
    }

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operational snapshot',
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: MlControlRoom.textStrong,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'This calendar month, from the company\'s live records',
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 12,
                        color: MlControlRoom.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  if ((s?.drivers ?? 0) > 0)
                    chipPill(
                      '${s!.drivers} driver${s.drivers == 1 ? '' : 's'}',
                      MlControlRoom.blue,
                    ),
                  if (completion != null)
                    chipPill(
                      '${(completion * 100).round()}% waybills done',
                      MlControlRoom.green,
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Tiles reflow 4-across → 2×2 → stacked as the card narrows.
          // IntrinsicHeight bounds each row so `stretch` can equalize tile
          // heights — without it the shrink-wrapping Column hands the tiles
          // an unbounded height constraint (renders nothing, spams asserts).
          Builder(
            builder: (context) {
              final tiles = [
                _KpiTile(
                  icon: Icons.people_outline,
                  label: 'Employees',
                  value: _int.format(s?.employees ?? 0),
                  sub: 'Active roster',
                  hint: 'Open Employee register',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          CompanyEmployeeRegisterScreen(company: company),
                    ),
                  ),
                ),
                kpi(
                  Icons.swap_horiz_rounded,
                  'Trips this month',
                  _int.format(s?.trips ?? 0),
                  '${_int.format(s?.loadsCount ?? 0)} loads captured',
                  tripsTarget,
                ),
                kpi(
                  Icons.scale_outlined,
                  'Tons moved',
                  '${_tons.format(s?.tonsMoved ?? 0)}t',
                  'Primary throughput metric',
                  tonsTarget,
                ),
                kpi(
                  Icons.local_shipping_outlined,
                  'Fleet',
                  _int.format(s?.fleetVehicles ?? 0),
                  '${_int.format(s?.drivers ?? 0)} drivers registered',
                  fleetTarget,
                ),
              ];

              Widget row(List<Widget> kids) => IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < kids.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(child: kids[i]),
                    ],
                  ],
                ),
              );

              if (tilesWidth < 460) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      tiles[i],
                    ],
                  ],
                );
              }
              if (tilesWidth < 860) {
                return Column(
                  children: [
                    row(tiles.sublist(0, 2)),
                    const SizedBox(height: 12),
                    row(tiles.sublist(2)),
                  ],
                );
              }
              return row(tiles);
            },
          ),
        ],
      ),
    );
  }

  // ---- progress + tiles column ----

  Widget _progressColumn(BuildContext context) {
    final completion = _completion;
    final turnaround = _avgTurnaroundHours;

    Widget miniTile(String value, String label) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: MlControlRoom.surfaceCard,
          borderRadius: BorderRadius.circular(MlControlRoom.rTile),
          border: Border.all(color: MlControlRoom.borderCard),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: MlControlRoom.textStrong,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 11,
                color: MlControlRoom.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    final pct = completion == null ? null : (completion * 100).round();
    final pace = pct == null
        ? 'No waybills yet'
        : pct >= 75
        ? 'Good pace'
        : pct >= 40
        ? 'Steady'
        : 'Needs attention';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            // Blue-washed panel like the mock's monthly-progress card.
            color: MlControlRoom.surfaceTintedCard,
            borderRadius: BorderRadius.circular(MlControlRoom.rCard),
            border: Border.all(color: MlControlRoom.borderTinted),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: CustomPaint(
                  painter: _DonutPainter(
                    progress: completion ?? 0,
                    track: MlControlRoom.blue.withValues(alpha: 0.18),
                    fill: MlControlRoom.blue,
                  ),
                  child: Center(
                    child: Text(
                      pct == null ? '—' : '$pct%',
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: MlControlRoom.textStrong,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Waybill completion',
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 12,
                        color: MlControlRoom.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pace,
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: MlControlRoom.textStrong,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'This month\'s done vs open',
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 11,
                        color: MlControlRoom.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: miniTile(_int.format(_waybillsDone), 'Waybills done'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: miniTile(_int.format(_waybillsOpen), 'Waybills open'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: miniTile(
                _int.format(stats?.routesDistinct ?? 0),
                'Routes active',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: miniTile(
                turnaround == null ? '—' : '${turnaround.toStringAsFixed(1)}h',
                'Avg turnaround',
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---- last 7 days bar chart ----

  Widget _tonsChartCard(BuildContext context) {
    final days = _last7Days;
    final maxTons = days.fold<double>(0, (m, d) => math.max(m, d.tons));

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(
            context,
            'Tons moved · last 7 days',
            trailing: 'Daily net mass from recon records',
          ),
          const SizedBox(height: 16),
          if (rowsLoading)
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SizedBox(
              height: 230,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final d in days)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              d.tons == 0 ? '0' : _tons.format(d.tons),
                              style: TextStyle(
                                fontFamily: MlTokens.fontMono,
                                fontSize: 11,
                                color: d.tons == 0
                                    ? MlControlRoom.textMuted.withValues(alpha: 0.6)
                                    : MlControlRoom.textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              height: maxTons == 0
                                  ? 3
                                  : math.max(4, 160 * d.tons / maxTons),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(MlShape.small),
                                ),
                                color: d.tons == 0
                                    ? MlControlRoom.borderCard
                                    : MlControlRoom.blueDeep,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              DateFormat('EE').format(d.day).substring(0, 2),
                              style: TextStyle(
                                fontFamily: MlTokens.fontSans,
                                fontSize: 11,
                                color: MlControlRoom.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---- this-month quick totals ----

  Widget _thisMonthCard(BuildContext context) {
    final s = stats;

    Widget row(String label, String value, {bool last = false}) {
      return Container(
        margin: EdgeInsets.only(bottom: last ? 0 : 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: MlControlRoom.surfaceTile,
          borderRadius: BorderRadius.circular(MlControlRoom.rTile),
          border: Border.all(color: MlControlRoom.borderCard),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontSize: 13,
                  color: MlControlRoom.textMuted,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: MlControlRoom.textStrong,
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(context, 'This month', trailing: 'Quick totals'),
          const SizedBox(height: 4),
          row('Trips', _int.format(s?.trips ?? 0)),
          row('Loads', _int.format(s?.loadsCount ?? 0)),
          row('Routes', _int.format(s?.routesDistinct ?? 0)),
          row('Waybills done', _int.format(s?.completedWaybills ?? 0)),
          row(
            'Waybills open',
            _int.format(s?.pendingWaybills ?? 0),
            last: true,
          ),
        ],
      ),
    );
  }

  // ---- operations timeline (latest captured loads) ----

  Widget _timelineCard(BuildContext context) {
    final recent = _recentRows;

    Widget entry(RawReconRow r, {required bool last}) {
      final t = r.timeIn ?? r.tripDate;
      final today = MlTime.now();
      final sameDay =
          t.year == today.year && t.month == today.month && t.day == today.day;
      final stamp = sameDay
          ? DateFormat('HH:mm').format(t)
          : DateFormat('d MMM').format(t);
      final who = r.truckReg ?? r.waybillNumber ?? 'Load';
      final tons = r.netMass == null ? '' : ' · ${_tons.format(r.netMass!)} t';
      final route = [
        if (r.product != null) r.product,
        if (r.destination != null) '→ ${r.destination}',
      ].join(' ');

      return Container(
        margin: EdgeInsets.only(bottom: last ? 0 : 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MlControlRoom.surfaceTile,
          borderRadius: BorderRadius.circular(MlControlRoom.rTile),
          border: Border.all(color: MlControlRoom.borderCard),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: MlControlRoom.blue,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$stamp — $who$tons',
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MlControlRoom.textStrong,
                    ),
                  ),
                  if (route.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      route,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 12,
                        color: MlControlRoom.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(
            context,
            'Operations timeline',
            trailing: 'Latest captured loads',
          ),
          const SizedBox(height: 14),
          if (recent.isEmpty)
            Text(
              rowsLoading ? 'Loading records…' : 'No captured loads yet.',
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 13,
                color: MlControlRoom.textMuted,
              ),
            )
          else
            for (var i = 0; i < recent.length; i++)
              entry(recent[i], last: i == recent.length - 1),
        ],
      ),
    );
  }

  // ---- live-map shortcut ----

  Widget _mapCard(BuildContext context) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MlControlRoom.rTile),
                  color: MlControlRoom.blue.withValues(alpha: 0.12),
                  border: Border.all(color: MlControlRoom.blue.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.map_outlined, color: MlControlRoom.blue, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fleet activity map',
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: MlControlRoom.textStrong,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Live GPS positions for every vehicle on this '
                      'organization\'s active trips.',
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 12,
                        color: MlControlRoom.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(
                onPressed: () => _openLiveMapTab(context),
                child: const Text('Open live map'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _MirrorLiveMapPreview(
            companyId: company.id,
            onOpen: () => _openLiveMapTab(context),
          ),
        ],
      ),
    );
  }

  /// Jumps to the mirrored Live map tab when this org type has one.
  void _openLiveMapTab(BuildContext context) {
    final controller = DefaultTabController.maybeOf(context);
    // Tab labels live in the same order as the TabBarView pages.
    final idx = _liveMapTabIndex(company);
    if (controller != null && idx != null) controller.animateTo(idx);
  }

  /// Index of the "Live map" tab in this screen's tab list (Dashboard first,
  /// then the org's own tabs, then Operations Hub). Null when the org type has
  /// no live-map tab.
  static int? _liveMapTabIndex(Company company) {
    final base = PortalNavigation.companyTabs(company.orgType);
    for (var i = 0; i < base.length; i++) {
      if (base[i].label.toLowerCase().contains('live map')) return i + 1;
    }
    return null;
  }

  // ---- derived alerts ----

  Widget _alertsCard(BuildContext context) {
    final active = rows
        .where(
          (r) =>
              r.tripStatus != null &&
              r.tripStatus != 'completed' &&
              r.tripStatus != 'cancelled',
        )
        .length;
    final weekTons = _last7Days.fold<double>(0, (sum, d) => sum + d.tons);

    final alerts = <({IconData icon, Color color, String title, String sub})>[
      if (_waybillsOpen > 0)
        (
          icon: Icons.error_outline,
          color: MlControlRoom.amber,
          title: 'Open waybills require review',
          sub:
              '$_waybillsOpen document${_waybillsOpen == 1 ? '' : 's'} still open this month',
        ),
      if (active > 0)
        (
          icon: Icons.local_shipping_outlined,
          color: MlControlRoom.blue,
          title: 'Trips in progress',
          sub: '$active trip${active == 1 ? '' : 's'} currently on the road',
        ),
      if (weekTons == 0 && !rowsLoading)
        (
          icon: Icons.hourglass_empty_rounded,
          color: MlControlRoom.textMuted,
          title: 'No tonnage in the last 7 days',
          sub: 'No net mass has been captured this week',
        ),
      if (_waybillsDone > 0)
        (
          icon: Icons.check_circle_outline,
          color: MlControlRoom.green,
          title: 'Reconciliation records up to date',
          sub:
              '$_waybillsDone waybill${_waybillsDone == 1 ? '' : 's'} completed this month',
        ),
    ];

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _cardTitle(context, 'Recent alerts', trailing: 'Operational signals'),
          const SizedBox(height: 10),
          if (alerts.isEmpty)
            Text(
              'Nothing to report yet.',
              style: TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: 13,
                color: MlControlRoom.textMuted,
              ),
            )
          else
            for (var i = 0; i < alerts.length; i++)
              Container(
                margin: EdgeInsets.only(bottom: i == alerts.length - 1 ? 0 : 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: MlControlRoom.surfaceTile,
                  borderRadius: BorderRadius.circular(MlControlRoom.rTile),
                  border: Border.all(color: MlControlRoom.borderCard),
                ),
                child: Row(
                  children: [
                    Icon(alerts[i].icon, size: 18, color: alerts[i].color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alerts[i].title,
                            style: TextStyle(
                              fontFamily: MlTokens.fontSans,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: MlControlRoom.textStrong,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            alerts[i].sub,
                            style: TextStyle(
                              fontFamily: MlTokens.fontSans,
                              fontSize: 12,
                              color: MlControlRoom.textMuted,
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
}

/// Simple ring-progress painter for the monthly completion donut.
/// One Operational-snapshot stat tile. When [onTap] is set the tile is a
/// live control: pointer cursor, hover lift (blue wash + border), ripple,
/// a corner jump-arrow, and a tooltip naming the tab it opens.
/// Live mini-map inside the dashboard's fleet-activity card: this company's
/// active-trip GPS positions on real tiles, realtime-refreshed through the
/// same [liveTripPositionsProvider] feed the full Live map tab watches.
/// View-only — panning/zooming is disabled and tapping anywhere opens the
/// full map. Fixed-height because the card renders inside IntrinsicHeight,
/// which cannot measure FlutterMap's internal LayoutBuilder.
class _MirrorLiveMapPreview extends ConsumerWidget {
  final String companyId;
  final VoidCallback? onOpen;

  const _MirrorLiveMapPreview({required this.companyId, this.onOpen});

  static const double _height = 260;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(liveTripPositionsProvider(companyId));
    return SizedBox(
      height: _height,
      child: async.when(
        loading: () => _frame(
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: MlControlRoom.blue,
              ),
            ),
          ),
        ),
        error: (_, _) => _placeholder(
          icon: Icons.wifi_off_rounded,
          title: 'Live map unavailable',
          message: 'Vehicle positions could not be loaded right now.',
        ),
        data: (trips) {
          final withFix = trips.where((t) => t.hasFix).toList();
          if (trips.isEmpty) {
            return _placeholder(
              icon: Icons.local_shipping_outlined,
              title: 'No active trips right now',
              message: 'Trucks appear here the moment a trip is scheduled; '
                  'positions go live once drivers share GPS.',
            );
          }
          if (withFix.isEmpty) {
            return _placeholder(
              icon: Icons.gps_off_outlined,
              title:
                  '${trips.length} active trip${trips.length == 1 ? '' : 's'} — '
                  'no GPS fixes yet',
              message: 'Positions appear as soon as a driver turns on live '
                  'location sharing.',
            );
          }
          return _map(context, trips, withFix);
        },
      ),
    );
  }

  /// The rounded tile the loading/empty states render in, matching the
  /// nested-tile styling used across this screen.
  Widget _frame({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: MlControlRoom.surfaceTile,
        borderRadius: BorderRadius.circular(MlControlRoom.rTile),
        border: Border.all(color: MlControlRoom.borderCard),
      ),
      child: child,
    );
  }

  Widget _placeholder({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return _frame(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 30, color: MlControlRoom.textMuted),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: MlControlRoom.textStrong,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontSize: 12,
                  color: MlControlRoom.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _map(
    BuildContext context,
    List<LiveTripPosition> trips,
    List<LiveTripPosition> withFix,
  ) {
    final live = withFix.length;
    return MouseRegion(
      cursor: onOpen == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onOpen,
        child: Stack(
          children: [
            // View-only: gestures fall through to the open-map tap above.
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(MlControlRoom.rTile),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCameraFit: safeCoordinatesFit(
                        [for (final t in withFix) t.point!],
                        padding: const EdgeInsets.all(36),
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      mlOsmTileLayer(),
                      MarkerLayer(
                        markers: [
                          for (final t in withFix)
                            Marker(
                              point: t.point!,
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: MlControlRoom.blueDeep,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: MlTokens.inkOnFill,
                                    width: 2,
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: MlControlRoom.scrim,
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.local_shipping_rounded,
                                  color: MlTokens.inkOnFill,
                                  size: 15,
                                ),
                              ),
                            ),
                        ],
                      ),
                      mlMapAttribution(),
                    ],
                  ),
                ),
              ),
            ),
            // Live count chip.
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: MlControlRoom.surfaceCardFloating,
                  borderRadius: MlShape.pill,
                  border: Border.all(color: MlControlRoom.borderCard),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: MlControlRoom.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      live == trips.length
                          ? '$live live'
                          : '$live of ${trips.length} live',
                      style: TextStyle(
                        fontFamily: MlTokens.fontSans,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: MlControlRoom.textStrong,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KpiTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final String sub;
  final String? hint;
  final VoidCallback? onTap;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.hint,
    this.onTap,
  });

  @override
  State<_KpiTile> createState() => _KpiTileState();
}

class _KpiTileState extends State<_KpiTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final hovered = _hover && interactive;

    Widget tile = AnimatedContainer(
      duration: MlTokens.durFast,
      curve: MlTokens.easeOutCubic,
      decoration: BoxDecoration(
        color: hovered ? MlControlRoom.blue.withValues(alpha: 0.08) : MlControlRoom.surfaceTile,
        borderRadius: BorderRadius.circular(MlControlRoom.rTile),
        border: Border.all(
          color: hovered ? MlControlRoom.blue.withValues(alpha: 0.55) : MlControlRoom.borderCard,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(MlControlRoom.rTile),
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(MlControlRoom.rTile),
          hoverColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(widget.icon, size: 15, color: MlControlRoom.textMuted),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontSize: 12,
                          color: MlControlRoom.textMuted,
                        ),
                      ),
                    ),
                    if (interactive)
                      AnimatedOpacity(
                        duration: MlTokens.durFast,
                        opacity: hovered ? 1 : 0.35,
                        child: Icon(
                          Icons.north_east_rounded,
                          size: 13,
                          color: hovered ? MlControlRoom.blue : MlControlRoom.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.value,
                  style: TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: MlControlRoom.textStrong,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: 12,
                    color: MlControlRoom.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (interactive && widget.hint != null) {
      tile = Tooltip(
        message: widget.hint!,
        waitDuration: const Duration(milliseconds: 400),
        child: tile,
      );
    }

    return MouseRegion(
      cursor: interactive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Semantics(button: interactive, child: tile),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color fill;
  const _DonutPainter({
    required this.progress,
    required this.track,
    required this.fill,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 9.0;
    final rect = Offset.zero & size;
    final r = rect.deflate(stroke / 2);
    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fillPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = fill;
    canvas.drawArc(r, 0, math.pi * 2, false, trackPaint);
    if (progress > 0) {
      canvas.drawArc(
        r,
        -math.pi / 2,
        math.pi * 2 * progress.clamp(0.0, 1.0),
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}
