import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/shell/workspace_canvas.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
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
              UserRole.labelFor(m['role'] as String?,
                  fallback: 'Team member'),
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

  /// Field width; the phone's search sheet passes `double.infinity`.
  final double width;

  /// Results list width — kept inside the screen on a narrow phone.
  final double optionsWidth;
  final bool autofocus;

  /// Opens a tab by index. Null means "the [DefaultTabController] above me",
  /// which the phone sheet does not have, being a route of its own.
  final ValueChanged<int>? onOpenTab;

  const _MirrorSearchBox({
    required this.companyId,
    required this.tabLabels,
    this.width = 300,
    this.optionsWidth = 340,
    this.autofocus = false,
    this.onOpenTab,
  });

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
      width: width,
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
          if (idx == null) return;
          final open = onOpenTab;
          if (open != null) {
            open(idx);
          } else {
            DefaultTabController.of(context).animateTo(idx);
          }
        },
        fieldViewBuilder: (context, controller, focus, onSubmit) => TextField(
          controller: controller,
          focusNode: focus,
          autofocus: autofocus,
          style: context.mlText.bodyMedium.copyWith(
            color: MlControlRoom.textStrong,
          ),
          cursorColor: MlControlRoom.cyan,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search assets, routes, users',
            hintStyle: context.mlText.bodyMedium.copyWith(
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
              borderSide: BorderSide(color: MlControlRoom.cyan.withValues(alpha: 0.55)),
            ),
          ),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 6),
              width: optionsWidth,
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
                            Icon(h.icon, size: 17, color: MlControlRoom.cyan),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    h.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.mlText.titleSmall.copyWith(
                                      color: MlControlRoom.textStrong,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (h.sub.isNotEmpty)
                                    Text(
                                      h.sub,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: context.mlText.bodySmall.copyWith(
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
                                style: context.mlText.labelSmall.copyWith(
                                  color: MlControlRoom.textMuted,
                                  fontWeight: FontWeight.w700,
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
  /// The notifier, CAPTURED while `ref` is still usable.
  ///
  /// `dispose()` used to call `ref.read(...)` to get it, and Riverpod refuses
  /// that outright: `dispose` runs from `Element.unmount`, by which point
  /// `ConsumerStatefulElement` throws *"Bad state: Cannot use `ref` after the
  /// widget was disposed"*. The old comment beside it shows the author had
  /// already met the problem once and deferred the MUTATION — but the
  /// `ref.read` that fetches the notifier is itself the forbidden call, so
  /// leaving the mirror threw every single time.
  ///
  /// It is not a cosmetic throw. The reset never ran, so `mirrorCompanyId`
  /// stayed pointing at the mirrored company after the admin navigated away —
  /// and `companyAccessProvider` watches it, so an admin who looked at a
  /// suspended customer kept seeing that customer's restriction notice over
  /// their own console. Found 2026-08-21, the first time this screen was
  /// rendered by anything.
  StateController<String?>? _mirrorId;

  @override
  void initState() {
    super.initState();
    _mirrorId = ref.read(mirrorCompanyIdProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // The frame callback can fire after a fast navigate-away has already
      // disposed this screen — using ref then throws.
      if (!mounted) return;
      ref.read(mirrorCompanyIdProvider.notifier).state = widget.companyId;
    });
  }

  @override
  void dispose() {
    // Still DEFERRED: mutating a provider synchronously while the tree is
    // mid-navigation rebuild throws for a different reason.
    final notifier = _mirrorId;
    if (notifier != null) {
      Future.microtask(() {
        // The container can outlive this screen or not; either way a disposed
        // notifier must not be written.
        try {
          notifier.state = null;
        } catch (_) {
          // Already gone with its container — nothing to reset.
        }
      });
    }
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
          // "Snapshot", not "Dashboard".
          //
          // `companyTabs` already opens with a tab called Dashboard for a
          // buyer and for a transporter, so the mirror's own summary made the
          // tab strip read `Dashboard · Dashboard · Routes & Mines · …` —
          // two adjacent tabs with the same name showing different things.
          // Photographed 2026-08-21. They are genuinely different views: this
          // one is the PLATFORM's read of the company (its own heading says
          // "Operational snapshot"), the next is the company's own dashboard
          // as its staff see it, and the mirror exists to show both.
          PortalTabItem(
            'Snapshot',
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

        // PHONES get their own arrangement (jean, 2026-10-22).
        //
        // The desktop chrome stacked on a 412×915 screen — a header card with
        // a sentence of description, a 300px search field, a pill and a
        // button, then a three-line read-only notice, then the tabs — was
        // ~490px of FIXED furniture, and the part that scrolls got the ~270px
        // left over: under a third of the screen, the tab content visible
        // through a letterbox. On a phone the header is one compact row and
        // scrolls away with the content; the tabs stay pinned at the top,
        // which is how every native app with tabs over a feed behaves.
        if (MediaQuery.sizeOf(context).width < _phoneBreakpoint) {
          return DefaultTabController(
            length: tabs.length,
            child: Scaffold(
              backgroundColor: mlWorkspaceGround(Theme.of(context).brightness),
              body: NestedScrollView(
                headerSliverBuilder: (context, _) => [
                  SliverToBoxAdapter(
                    child: _PhoneHeader(
                      company: company,
                      tabLabels: [for (final t in tabs) t.label],
                      canExport: canExport,
                      onExport: () =>
                          _exportMonthlyInsightsCsv(context, company),
                    ),
                  ),
                ],
                // The tabs are the top of the BODY, not a pinned header
                // sliver. Once the header has scrolled off, the body fills
                // the screen and the strip sits at its top — pinned in effect.
                // A pinned `SliverPersistentHeader` in the header list instead
                // let the body slide UNDER the strip by its own height, hiding
                // the top 60px of every tab (measured: the tab viewport began
                // at y=72, the strip's bottom at 110). The cure for that,
                // `SliverOverlapInjector`, would have to go inside every
                // mirrored screen; this needs none of them to change.
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PillTabBar(tabs: tabs),
                    Expanded(
                      child: TabBarView(
                        children: tabs.map((t) => t.screen).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            // The page ground, through the helper the shell's own painter
            // uses. It was `MlControlRoom.pageBg`, which happens to be the
            // same colour — a coincidence that held only while both tracked
            // `MlGlass.bg0`.
            backgroundColor: mlWorkspaceGround(Theme.of(context).brightness),
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

/// Below this width the mirror uses [_PhoneHeader] and a scroll-away header.
const double _phoneBreakpoint = 600;

/// The org-type tones from docs/design-reference.md §2 — shared by the
/// desktop [_HeroHeader] and the phone header so the two cannot drift.
Color _orgTone(OrgType t) => switch (t) {
      OrgType.transporter => MlControlRoom.cyan,
      OrgType.buyer => MlControlRoom.violet,
      OrgType.mineSupplier => MlControlRoom.amber,
    };

/// The phone header: one compact card that scrolls away with the content.
///
/// Identity on the left (an initial well in the org tone, the name, an org
/// chip and a Read-only chip), actions on the right as 44px round icon
/// buttons — search opens a sheet, export shares the CSV. The desktop header's
/// description sentence and the separate read-only notice are folded into the
/// Read-only chip, which explains itself when tapped.
class _PhoneHeader extends StatelessWidget {
  final Company company;
  final List<String> tabLabels;
  final bool canExport;
  final VoidCallback onExport;

  const _PhoneHeader({
    required this.company,
    required this.tabLabels,
    required this.canExport,
    required this.onExport,
  });

  String get _initials {
    final words = company.companyName
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && RegExp(r'[A-Za-z0-9]').hasMatch(w[0]))
        .toList();
    if (words.isEmpty) return '?';
    final first = words.first[0];
    final second = words.length > 1 ? words[1][0] : '';
    return (first + second).toUpperCase();
  }

  void _openSearch(BuildContext context) {
    // The sheet is its own route, so it cannot see the DefaultTabController;
    // take the controller now and hand the sheet a way to drive it.
    final tabs = DefaultTabController.of(context);
    final screenW = MediaQuery.sizeOf(context).width;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: MlControlRoom.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(MlControlRoom.rCard),
        ),
      ),
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          16 + MediaQuery.viewInsetsOf(sheet).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: MlControlRoom.borderCard,
                    borderRadius: MlShape.pill,
                  ),
                ),
              ),
              Text(
                'Search ${company.companyName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.titleMedium.copyWith(
                  color: MlControlRoom.textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Users, vehicles and loads. Picking one opens its tab.',
                style: context.mlText.bodySmall.copyWith(
                  color: MlControlRoom.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              _MirrorSearchBox(
                companyId: company.id,
                tabLabels: tabLabels,
                width: double.infinity,
                optionsWidth: math.min(340, screenW - 32),
                autofocus: true,
                onOpenTab: (i) {
                  Navigator.of(sheet).pop();
                  tabs.animateTo(i);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _explainReadOnly(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Read-only mirror of this organization\'s workspace. Edits, '
            'deletes and moves are disabled; you can inspect activity and '
            'export data where allowed.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final tone = _orgTone(company.orgType);

    Widget roundAction({
      required IconData icon,
      required String tooltip,
      required VoidCallback onTap,
      bool accent = false,
    }) =>
        Tooltip(
          message: tooltip,
          child: Material(
            color: accent ? MlTokens.accent : MlControlRoom.surfaceTile,
            shape: CircleBorder(
              side: accent
                  ? BorderSide.none
                  : BorderSide(color: MlControlRoom.borderCard),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  icon,
                  size: 20,
                  color: accent ? MlTokens.inkOnAccent : MlControlRoom.textStrong,
                ),
              ),
            ),
          ),
        );

    Widget chip({
      required String label,
      required Color color,
      IconData? icon,
      VoidCallback? onTap,
    }) {
      final body = Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: MlShape.pill,
          border: Border.all(color: color.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: context.mlText.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
      if (onTap == null) return body;
      return InkWell(borderRadius: MlShape.pill, onTap: onTap, child: body);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
        decoration: BoxDecoration(
          color: MlControlRoom.surfaceCard,
          borderRadius: BorderRadius.circular(MlControlRoom.rCard),
          border: Border.all(color: MlControlRoom.borderCard),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.16),
                borderRadius: MlShape.radiusMedium,
                border: Border.all(color: tone.withValues(alpha: 0.45)),
              ),
              child: Text(
                _initials,
                style: context.mlText.titleMedium.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    company.companyName,
                    // Three lines: a holding company's full legal name is the
                    // thing this header is for, and two cut most of them off.
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.editorialLarge.copyWith(
                      fontSize: 19,
                      height: 1.15,
                      color: MlControlRoom.textStrong,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      chip(label: company.orgType.label, color: tone),
                      chip(
                        label: 'Read-only',
                        icon: Icons.visibility_outlined,
                        color: MlControlRoom.textMuted,
                        onTap: () => _explainReadOnly(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                roundAction(
                  icon: Icons.search_rounded,
                  tooltip: 'Search assets, routes, users',
                  onTap: () => _openSearch(context),
                ),
                if (canExport) ...[
                  const SizedBox(height: 8),
                  roundAction(
                    icon: Icons.ios_share_rounded,
                    tooltip: 'Export monthly insights',
                    onTap: onExport,
                    accent: true,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}


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

  // The reference's badge tones (docs/design-reference.md §2): MINE amber,
  // BUYER violet, TRANSPORTER cyan. Buyer was sky blue here — the series hue
  // the mirror plots trips in — and the screen's interactive chrome (cursor,
  // focus ring, tab indicator, icon wells, spinner) used the same blue as a
  // second accent beside the console's cyan. One accent (§5 rule 2); the
  // blue stays for the tons series and the drivers chip. Phase 3 pass,
  // 2026-08-23.
  Color _orgChipColor(Brightness b) => _orgTone(company.orgType);

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
          style: context.mlText.overline.copyWith(
            color: MlControlRoom.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            // The display face, as every console page title (MlPageHeader,
            // docs/design-reference.md §3). This was 32px PlusJakartaSans
            // ExtraBold — the mirror's own mock, transcribed before the
            // reference was designated. Phase 3 pass, 2026-08-23.
            Text(
              company.companyName,
              style: context.mlText.editorialLarge.copyWith(
                fontSize: narrow ? 24 : 32,
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
                style: context.mlText.labelMedium.copyWith(
                  color: chip,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Full-screen read-only mirror of this organization\'s workspace — '
          'live operational data, recon records and positions.',
          style: context.mlText.bodyMedium.copyWith(
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
            style: context.mlText.titleSmall.copyWith(
              color: MlControlRoom.textMuted,
            ),
          ),
        ),
        if (canExport)
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: MlTokens.accent,
              foregroundColor: MlTokens.inkOnAccent,
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
        // BELOW 900 THE ACTIONS GO UNDER THE TITLE, they do not sit beside it.
        //
        // `actions` is a `Wrap`, and a `Wrap` in a `Row` is laid out against
        // UNBOUNDED width (CLAUDE.md §10.4) — so it claimed its natural 300px
        // search box plus a pill plus a button, and the `Expanded` identity
        // got what was left. At 412px that was 28px: the company name rendered
        // ONE CHARACTER PER LINE down the side of the card, under an eyebrow
        // reading O-R-G-A-N-I-Z-A-T-I-O-N vertically, beside 323px of
        // yellow-and-black overflow stripes. Photographed 2026-08-21, the
        // first time this screen was rendered at any width.
        //
        // `narrow` is the flag this method already computes for the title's
        // font size; it decides the arrangement too now.
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: AppNavigationBackButton(),
                      ),
                      const SizedBox(width: 4),
                      Expanded(child: identity),
                    ],
                  ),
                  const SizedBox(height: 14),
                  actions,
                ],
              )
            : Row(
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
                  style: context.mlText.bodyMedium.copyWith(
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
            // The pill only shares the row when there is room for both.
            //
            // At its natural ~150px beside an `Expanded` sentence, a phone
            // left the sentence a 110px column — five lines of "Edits,
            // deletes, and moves are disabled" next to a pill that says less.
            if (MediaQuery.sizeOf(context).width >= 560) ...[
              const SizedBox(width: 10),
              _permissionsPill(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _permissionsPill(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: MlShape.pill,
          border: Border.all(color: MlControlRoom.borderCard),
          color: MlControlRoom.surfaceTile,
        ),
        child: Text(
          'Permissions active',
          style: context.mlText.labelMedium.copyWith(
            color: MlControlRoom.textMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
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
            color: MlControlRoom.cyan.withValues(alpha: 0.16),
            border: Border.all(color: MlControlRoom.cyan.withValues(alpha: 0.5)),
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
              // Half the row, minus the scroll padding and the 16px gap —
              // the same arithmetic `_snapshotCard` above is given, and for
              // the same reason: this card is inside IntrinsicHeight and
              // nothing under it may ask for its own constraints.
              Expanded(child: _mapCard(context, (maxWidth - 32 - 16) / 2)),
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
        _mapCard(context, maxWidth - 32),
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
    // On a phone the note goes UNDER the heading. Beside it, the two shared a
    // ~340px row and both wrapped: "Tons moved · / last 7 days" next to a
    // two-line note, neither readable at a glance.
    if (trailing != null &&
        MediaQuery.sizeOf(context).width < _phoneBreakpoint) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.mlText.editorialMedium.copyWith(
              color: MlControlRoom.textStrong,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            trailing,
            style: context.mlText.bodySmall.copyWith(
              color: MlControlRoom.textMuted,
            ),
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            // The reference's section heading — Fraunces, as MlSectionTitle
            // draws it — not 16px sans ExtraBold.
            style: context.mlText.editorialMedium.copyWith(
              color: MlControlRoom.textStrong,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing,
            style: context.mlText.bodySmall.copyWith(
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
          style: context.mlText.labelMedium.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Words then pills, stacked — not words BESIDE pills in a Row.
          //
          // Two chips of natural width beside an `Expanded` column left the
          // heading about 110px on a phone: "Operational snapshot" over two
          // lines and its sentence over five, in a column narrower than the
          // pills next to it. Photographed on
          // `screen-company-mirror-phone-dark`.
          //
          // It reflows off `tilesWidth`, NOT off a `LayoutBuilder`. The fix
          // for the phone layout above originally used one, immediately below
          // the comment on this method saying a LayoutBuilder cannot live here
          // — and it produced 21 framework errors on the desktop render, led
          // by "LayoutBuilder does not support returning intrinsic
          // dimensions", every time this card was measured inside
          // `_wideLayout`'s `IntrinsicHeight`.
          //
          // Nobody saw them because the harness captures framework errors and
          // writes the picture anyway (which is the right call), and because
          // every reading of that output had been piped through `tail`. The
          // width is passed into this method precisely so no descendant has to
          // ask for it; use it.
          Builder(
            builder: (context) {
              final words = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Operational snapshot',
                    style: context.mlText.editorialMedium.copyWith(
                      color: MlControlRoom.textStrong,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'This calendar month, from the company\'s live records',
                    style: context.mlText.bodySmall.copyWith(
                      color: MlControlRoom.textMuted,
                    ),
                  ),
                ],
              );
              final pills = Wrap(
                spacing: 8,
                runSpacing: 8,
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
              );
              if (tilesWidth < 520) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [words, const SizedBox(height: 10), pills],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Expanded(child: words), pills],
              );
            },
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
                  '${mlCountText(_int.format(s?.loadsCount ?? 0), 'load')} captured',
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
                  '${mlCountText(_int.format(s?.drivers ?? 0), 'driver')} registered',
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

              // A phone gets the 2×2 grid too, in compact tiles. Stacked
              // one per row, each full-width tile was ~150px tall around one
              // number, and the four of them filled the whole screen.
              if (tilesWidth < 460) {
                final small = [
                  for (final t in tiles) (t as _KpiTile).asCompact(),
                ];
                Widget pair(List<Widget> kids) => IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: kids[0]),
                          const SizedBox(width: 10),
                          Expanded(child: kids[1]),
                        ],
                      ),
                    );
                return Column(
                  children: [
                    pair(small.sublist(0, 2)),
                    const SizedBox(height: 10),
                    pair(small.sublist(2)),
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
              style: context.mlText.titleLarge.copyWith(
                color: MlControlRoom.textStrong,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.mlText.labelSmall.copyWith(
                color: MlControlRoom.textMuted,
                fontWeight: FontWeight.w400,
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
                    track: MlControlRoom.cyan.withValues(alpha: 0.18),
                    fill: MlControlRoom.cyan,
                  ),
                  child: Center(
                    child: Text(
                      pct == null ? '—' : '$pct%',
                      style: context.mlText.titleMedium.copyWith(
                        color: MlControlRoom.textStrong,
                        fontWeight: FontWeight.w800,
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
                      style: context.mlText.bodySmall.copyWith(
                        color: MlControlRoom.textMuted,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      pace,
                      style: context.mlText.titleMedium.copyWith(
                        color: MlControlRoom.textStrong,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'This month\'s done vs open',
                      style: context.mlText.labelSmall.copyWith(
                        color: MlControlRoom.textMuted,
                        fontWeight: FontWeight.w400,
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
                              style: context.mlText.code(
                                // `textFaint`, not `textMuted` at 60%.
                                // A zero SHOULD be quieter than a real
                                // figure; stacking an alpha on an ink to say
                                // so took it to 3.85:1. There is a token that
                                // means exactly "one step quieter" and it is
                                // legible on every surface in the product.
                                color: d.tons == 0
                                    ? MlControlRoom.textFaint
                                    : MlControlRoom.textMuted,
                                size: 11,
                                weight: FontWeight.w400,
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
                              style: context.mlText.labelSmall.copyWith(
                                color: MlControlRoom.textMuted,
                                fontWeight: FontWeight.w400,
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
                style: context.mlText.bodyMedium.copyWith(
                  color: MlControlRoom.textMuted,
                ),
              ),
            ),
            Text(
              value,
              style: context.mlText.titleMedium.copyWith(
                color: MlControlRoom.textStrong,
                fontWeight: FontWeight.w800,
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
                  color: MlControlRoom.cyan,
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
                    style: context.mlText.titleSmall.copyWith(
                      color: MlControlRoom.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (route.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      route,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.bodySmall.copyWith(
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
              style: context.mlText.bodyMedium.copyWith(
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

  Widget _mapCard(BuildContext context, double width) {
    return _card(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Builder(
            builder: (context) {
              final icon = Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(MlControlRoom.rTile),
                  color: MlControlRoom.cyan.withValues(alpha: 0.12),
                  border: Border.all(color: MlControlRoom.cyan.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.map_outlined, color: MlControlRoom.cyan, size: 24),
              );
              final words = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fleet activity map',
                    style: context.mlText.editorialMedium.copyWith(
                      color: MlControlRoom.textStrong,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Live GPS positions for every vehicle on this '
                    'organization\'s active trips.',
                    style: context.mlText.bodySmall.copyWith(
                      color: MlControlRoom.textMuted,
                    ),
                  ),
                ],
              );
              final button = FilledButton.tonal(
                onPressed: () => _openLiveMapTab(context),
                child: const Text('Open live map'),
              );
              // Below 420px the button and the words cannot share a row. On a
              // 412px phone this card is ~360px wide, and "Open live map" is a
              // fixed ~140px of it — which left the sentence 135px to say
              // "Live GPS positions for every vehicle on this organization's
              // active trips" in four cramped lines, with the title wrapping
              // too. Stacked, both get the full width.
              // Off the passed-down width, not a LayoutBuilder. See the
              // note on `_snapshotCard`: on the wide layout this card is a
              // child of `IntrinsicHeight`, and a LayoutBuilder there throws
              // "does not support returning intrinsic dimensions" — which is
              // what the doc comment on `_MapPreview` below already warns
              // about for FlutterMap's own internal one.
              return Builder(
                builder: (context) {
                  if (width - 36 >= 420) {
                    return Row(
                      children: [
                        icon,
                        const SizedBox(width: 14),
                        Expanded(child: words),
                        const SizedBox(width: 12),
                        button,
                      ],
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          icon,
                          const SizedBox(width: 14),
                          Expanded(child: words),
                        ],
                      ),
                      const SizedBox(height: 12),
                      button,
                    ],
                  );
                },
              );
            },
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
              style: context.mlText.bodyMedium.copyWith(
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
                            style: context.mlText.titleSmall.copyWith(
                              color: MlControlRoom.textStrong,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            alerts[i].sub,
                            style: context.mlText.bodySmall.copyWith(
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
                color: MlControlRoom.cyan,
              ),
            ),
          ),
        ),
        error: (_, _) => _placeholder(
          context,
          icon: Icons.wifi_off_rounded,
          title: 'Live map unavailable',
          message: 'Vehicle positions could not be loaded right now.',
        ),
        data: (trips) {
          final withFix = trips.where((t) => t.hasFix).toList();
          if (trips.isEmpty) {
            return _placeholder(
              context,
              icon: Icons.local_shipping_outlined,
              title: 'No active trips right now',
              message: 'Trucks appear here the moment a trip is scheduled; '
                  'positions go live once drivers share GPS.',
            );
          }
          if (withFix.isEmpty) {
            return _placeholder(
              context,
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

  Widget _placeholder(BuildContext context, {
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
                style: context.mlText.titleSmall.copyWith(
                  color: MlControlRoom.textStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: context.mlText.bodySmall.copyWith(
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
                      // Not flutter_map's near-white default: see
                      // mlMapBackground.
                      backgroundColor: mlMapBackground(context),
                      initialCameraFit: safeCoordinatesFit(
                        [for (final t in withFix) t.point!],
                        padding: const EdgeInsets.all(36),
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      mlOsmTiles(context),
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
                      style: context.mlText.labelMedium.copyWith(
                        color: MlControlRoom.textStrong,
                        fontWeight: FontWeight.w700,
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

  /// Phone density: two tiles share a row, so the figure, padding and gaps
  /// shrink and a long figure scales down rather than wrapping.
  final bool compact;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.sub,
    this.hint,
    this.onTap,
    this.compact = false,
  });

  _KpiTile asCompact() => _KpiTile(
        icon: icon,
        label: label,
        value: value,
        sub: sub,
        hint: hint,
        onTap: onTap,
        compact: true,
      );

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
        color: hovered ? MlControlRoom.cyan.withValues(alpha: 0.08) : MlControlRoom.surfaceTile,
        borderRadius: BorderRadius.circular(MlControlRoom.rTile),
        border: Border.all(
          color: hovered ? MlControlRoom.cyan.withValues(alpha: 0.55) : MlControlRoom.borderCard,
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
            padding: EdgeInsets.all(widget.compact ? 14 : 20),
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
                        style: context.mlText.bodySmall.copyWith(
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
                          color: hovered ? MlControlRoom.cyan : MlControlRoom.textMuted,
                        ),
                      ),
                  ],
                ),
                SizedBox(height: widget.compact ? 10 : 16),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.value,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: widget.compact ? 26 : 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: MlControlRoom.textStrong,
                    ),
                  ),
                ),
                SizedBox(height: widget.compact ? 6 : 14),
                Text(
                  widget.sub,
                  maxLines: widget.compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.bodySmall.copyWith(
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
