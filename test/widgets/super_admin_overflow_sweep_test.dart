// Portal-wide overflow sweep for the super-admin console.
//
// The console lets each admin pick a text size (UiPrefs.textScale, clamped
// 0.85–1.3) and bold text, and applies both to the whole portal through
// MediaQuery. Every fixed-height tile that holds text therefore has to survive
// the larger sizes — at 1.0 a tile can be 1px inside its box and still overflow
// for a user who nudged the slider one notch.
//
// The slider is only HALF the scale a screen renders at. Since 2026-08-17 the
// shells compose it with the platform's own scaler rather than replacing it,
// so the effective ceiling is kMaxEffectiveTextScale, not 1.3. Raising the
// sweep to that value on the day it changed found four real overflows that had
// been sitting behind the old ceiling: an org-type pill, an "Open workspace"
// button, two chart legends starved to under 12px by an unflexed axis caption,
// and a leaderboard row. None reproduced below 1.6.
//
// Two things make this sweep meaningful rather than decorative:
//
//  1. It loads the REAL fonts. `flutter test` otherwise renders with a fallback
//     test font whose metrics differ from PlusJakartaSans / JetBrainsMono, so
//     text-metric overflows simply do not reproduce.
//  2. It sweeps width x text-scale, because these tiles only fail in corners.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/services/reconciliation_service.dart';
import 'package:flutter_application_1/features/super_admin/data/models/company_monthly_ops_stats.dart';
import 'package:flutter_application_1/features/super_admin/data/models/audit_log.dart';
import 'package:flutter_application_1/features/super_admin/data/models/platform_role.dart';
import 'package:flutter_application_1/features/super_admin/data/models/token_request.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/core/design/tokens/ui_prefs.dart';
import 'package:flutter_application_1/features/super_admin/screens/audit_logs_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/available_routes_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/chat_connections_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/dispute_inbox_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/driver_limit_requests_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/expired_access_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/live_map_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/margin_ledger_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/organization_detail_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/organization_management_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/platform_admin_settings_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/platform_users_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/recon_tables_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/register_company_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/request_tracking_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/route_marketplace_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_dashboard_v2_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_org_insights_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/token_history_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/token_requests_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/user_preferences_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/transporters_overview_v2_screen.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_dashboard.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/overview_models.dart';
import 'package:flutter_application_1/features/super_admin/widgets/transporters_overview/transporters_overview_body.dart';
import 'package:flutter_application_1/core/layout/text_scale.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import '../fixtures/console_capture_fixtures.dart';
import '../fixtures/ml_sample_data.dart';
import '../fixtures/portal_capture_fixtures.dart';
import '../fixtures/screen_fixtures.dart';
import '../test_helpers/real_fonts.dart';

/// Widths the console content area actually sees. 1612 is the measured value
/// on a 1920 window (1660 shell content minus the screen's own padding); the
/// rest walk down through both two-column breakpoints and on to a phone.
///
/// **This list used to stop at 860.** Every console screen was therefore
/// unrendered below that — on every phone and most tablets — while this file
/// reported that they "survive every width x text scale". The console is not
/// a desktop-only surface: the shell has a phone layout with a bottom bar and
/// a drawer, and Jean opens it on his own handset.
///
/// Extending it to 760 / 600 / 412 / 360 found six faults across three files,
/// all of them the same family (CLAUDE.md §10.4 — a Row hands a non-flex child
/// unbounded width) and none of them visible above 860:
///
///   * the dashboard's org table, four columns that cannot fit a phone
///   * its tab chips, unbounded inside a Wrap
///   * `MlSectionHead`, shared by every console section
///   * the organizations filter bar, its pagination footer, and its dropdowns
///   * `MlRailIdentity`, drawing a 280dp block in an 80dp rail
const _widths = <double>[1612, 1280, 1024, 860, 760, 600, 412, 360];

/// 1.0, the two ends of the UiPrefs slider, and on up to the effective
/// ceiling the shells actually install.
///
/// The top of this list is not a taste: the in-app slider is only one half of
/// the scale a screen really renders at. Since 2026-08-17 the shells COMPOSE
/// it with the platform's scaler and cap the product at
/// [kMaxEffectiveTextScale], so anything below that value is a size a real
/// user can reach and this sweep must cover it. Held to that by the first
/// test in `main`.
const _scales = <double>[0.85, 1.0, 1.15, 1.3, 1.6, 2.0];

void main() {
  // Not a layout assertion — a guard on the sweep itself. Raising the shells'
  // ceiling without widening this list would leave real sizes unrendered while
  // the suite still went green, which is the failure docs/future-work.md
  // warned about: trading a readability defect for a set of layout ones.
  test('the sweep reaches the largest scale the shells will install', () {
    expect(_scales.reduce((a, b) => a > b ? a : b),
        greaterThanOrEqualTo(kMaxEffectiveTextScale),
        reason: 'lib/core/layout/text_scale.dart caps the composed scale at '
            '$kMaxEffectiveTextScale; this sweep tops out at '
            '${_scales.reduce((a, b) => a > b ? a : b)}. Widen _scales and fix '
            'what it finds before raising that constant.');
  });

  setUpAll(() async {
    await loadRealFonts();
    // Several screens touch Supabase.instance during build. The sweep only
    // cares about layout, so a dummy instance is enough to get them rendering;
    // no request is ever made.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'overflow-sweep-key',
    );
  });

  /// Renders [child] across every width x scale and fails on the first
  /// overflow, naming the exact corner so the failure is actionable.
  Future<void> sweep(
    WidgetTester tester,
    Widget Function() child, {
    List<Override> overrides = const [],
    bool boldText = false,
    List<double> scales = _scales,
  }) async {
    for (final width in _widths) {
      for (final scale in scales) {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1.0;

        // Capture the full FlutterErrorDetails, not just the exception:
        // `takeException()` drops the "relevant error-causing widget" line,
        // which is the only part that says WHERE to fix it.
        final captured = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = captured.add;

        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: MaterialApp(
              theme: AppTheme.darkTheme,
              // Inside MaterialApp — its own MediaQuery.fromView replaces an
              // outer one, exactly as the console shell does it.
              builder: (context, c) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  boldText: boldText,
                ),
                child: c!,
              ),
              home: Scaffold(
                body: SizedBox(width: width, child: child()),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        FlutterError.onError = previousOnError;
        tester.takeException();

        // Only layout faults are in scope. Re-pumping the same tester across
        // 24 corners also provokes provider-disposal races ('Cannot use "ref"
        // after the widget was disposed') that are an artefact of the harness,
        // not of the screen, and would make this sweep cry wolf.
        bool isLayoutFault(FlutterErrorDetails d) {
          final s = d.exception.toString();
          return s.contains('overflowed') ||
              s.contains('forces an infinite') ||
              s.contains('BoxConstraints');
        }

        final layout = captured.where(isLayoutFault).toList();
        if (layout.isNotEmpty) {
          final where = layout
              .map((d) => d
                  .toDiagnosticsNode(style: DiagnosticsTreeStyle.error)
                  .toStringDeep())
              .join('\n');
          fail('Layout error at width=$width textScale=$scale '
              'boldText=$boldText\n$where');
        }
      }
    }
    addTearDown(tester.view.reset);
  }

  // ---- fakes -------------------------------------------------------------
  CompanyMonthlyOpsStats company(String id, String name) =>
      CompanyMonthlyOpsStats(
        companyId: id,
        companyName: name,
        orgType: 'buyer',
        fleetVehicles: 12,
        drivers: 9,
        employees: 40,
        routesDistinct: 6,
        trips: 128,
        loadsCount: 130,
        tonsMoved: 12345.6,
        completedWaybills: 118,
        pendingWaybills: 12,
      );

  MonthlyInsightsBundle bundleFor(String orgType) => MonthlyInsightsBundle(
        companies: [
          company('c1', 'Atlas Buyer Group'),
          company('c2', 'Northern Coal Co.'),
          company('c3', 'Roadhaul Logistics'),
          // A deliberately long name — wide strings are half of all overflows.
          company('c4', 'Consolidated Mineral Offtake & Logistics Holdings'),
        ],
        aggregate: OrgTypeAggregateStats(
          orgType: orgType,
          companyCount: 4,
          activeTripsApprox: 37,
          fleetVehiclesTotal: 48,
          tonsMoved: 49382.4,
          transactionsTotal: 512,
          completedWaybills: 472,
          pendingWaybills: 40,
        ),
      );

  List<Override> insightsOverrides(String orgType) => [
        monthlyInsightsBundleProvider(orgType)
            .overrideWith((ref) async => bundleFor(orgType)),
        rawReconRowsProvider(null)
            .overrideWith((ref) async => const <RawReconRow>[]),
      ];

  /// One organisation row shaped like `companies` selects it.
  Map<String, dynamic> org(String id, String name, String type) => {
        'id': id,
        'company_name': name,
        'org_type': type,
        'status': 'active',
        'seat_limit': 5,
        'seats_used': 4,
        'created_at': '2026-07-01T08:00:00Z',
        'token_expires_at': '2026-12-01T08:00:00Z',
        'physical_address': '12 Long Industrial Road, Emalahleni, Mpumalanga',
        'email': 'ops@example.com',
      };

  /// Everything the console dashboard and list screens read, faked. Values are
  /// deliberately wide (long names, 6-figure tonnage) — narrow data hides the
  /// overflows this sweep exists to catch.
  final consoleOverrides = <Override>[
    dashboardStatsProvider.overrideWith((ref) async => <String, dynamic>{
          'totalCompanies': 248,
          'activeCompanies': 231,
          'expiredCompanies': 12,
          'suspendedCompanies': 5,
          'totalUsers': 1864,
          'openTokenRequests': 37,
          'tokensExpiringSoon': 9,
          'activeRoutes': 142,
          'totalTonsManaged': 1712400.0,
          'newCompanies24h': 12,
          'newUsers24h': 148,
          'newTokenRequests24h': 22,
          'newExpired24h': 3,
          'activeUsersNow': 146,
          'tons24h': 28450.0,
        }),
    organizationsProvider.overrideWith((ref) async => [
          org('o1', 'Iron Hills Mining', 'mineSupplier'),
          org('o2', 'Atlas Buyer Group', 'buyer'),
          org('o3', 'Roadhaul Logistics', 'transporter'),
          org('o4', 'Consolidated Mineral Offtake & Logistics Holdings',
              'buyer'),
        ]),
    currentPlatformRoleProvider
        .overrideWith((ref) async => PlatformRole.superGlobalSerialAdminMain),
    allPlatformUsersProvider
        .overrideWith((ref) async => const <Map<String, dynamic>>[]),
    openTokenRequestsProvider.overrideWith((ref) async => const <TokenRequest>[]),
    auditLogsProvider(null).overrideWith((ref) async => const <AuditLog>[]),
    for (final t in ['transportation', 'product', 'buyer'])
      adminRequestQueueProvider(t)
          .overrideWith((ref) async => const <TransportationRequest>[]),
    for (final t in ['transporter', 'buyer', 'mineSupplier'])
      monthlyInsightsBundleProvider(t).overrideWith((ref) async => bundleFor(t)),
    rawReconRowsProvider(null)
        .overrideWith((ref) async => const <RawReconRow>[]),
    organizationDetailProvider('o4').overrideWith(
        (ref) async => org('o4',
            'Consolidated Mineral Offtake & Logistics Holdings', 'buyer')),
    // Avoids authStateProvider (and therefore Supabase auth) during build.
    uiPrefsProvider.overrideWith((ref) => UiPrefsNotifier(null)),
  ];

  group('org insights (legacy layout)', () {
    for (final orgType in ['buyer', 'mineSupplier', 'transporter']) {
      testWidgets('$orgType survives every width x text scale',
          (tester) async {
        await sweep(
          tester,
          () => SuperAdminOrgInsightsScreen(orgType: orgType),
          overrides: insightsOverrides(orgType),
        );
      });
    }

    testWidgets('buyer survives bold text', (tester) async {
      await sweep(
        tester,
        () => const SuperAdminOrgInsightsScreen(orgType: 'buyer'),
        overrides: insightsOverrides('buyer'),
        boldText: true,
      );
    });
  });

  group('console screens', () {
    final screens = <String, Widget Function()>{
      'dashboard (default landing)': () => const SuperAdminDashboardV2Screen(),
      'organizations': () => const OrganizationManagementScreen(),
      'platform users': () => const PlatformUsersScreen(),
      'token requests': () => const TokenRequestsScreen(),
      'audit logs': () => const AuditLogsScreen(),
      'recon tables': () => const ReconTablesScreen(),
      // Secondary screens. Their own list providers are left to resolve
      // against the dummy Supabase, so these sweep the loading/empty/error
      // layouts — which is exactly where a rigid row tends to break.
      'margin ledger': () => const MarginLedgerScreen(),
      'dispute inbox': () => const DisputeInboxScreen(),
      'driver limit requests': () => const DriverLimitRequestsScreen(),
      'request tracking': () => const RequestTrackingScreen(),
      'route marketplace': () => const RouteMarketplaceScreen(),
      'available routes': () => const AvailableRoutesScreen(),
      'chat connections': () => const ChatConnectionsScreen(),
      'token history': () => const TokenHistoryScreen(),
      // (seat_requests_screen.dart only re-exports TokenRequestsScreen.)
      'platform admin settings': () => const PlatformAdminSettingsScreen(),
      'register company': () => const RegisterCompanyScreen(),
      'live map': () => const LiveMapScreen(),
      'expired access': () => const ExpiredAccessScreen(
            companyName: 'Consolidated Mineral Offtake & Logistics Holdings',
            reason: 'token expired',
          ),
      'user preferences': () => const UserPreferencesScreen(),
      'organization detail': () =>
          const OrganizationDetailScreen(organizationId: 'o4'),
      // NOT covered: SuperAdminCompanyMirrorScreen, CompanyEmployeeRegisterScreen
      // and RequestReviewScreen. Each needs a company/request object and a
      // handful of further providers (mirror search index, live trip positions)
      // that this harness does not build, so they would render an error state
      // rather than the layout under test. Left out deliberately instead of
      // passing vacuously — see the report.
    };

    for (final entry in screens.entries) {
      testWidgets('${entry.key} survives every width x text scale',
          (tester) async {
        await sweep(tester, entry.value, overrides: consoleOverrides);
      });
    }

    // ── The same screens, WITH ROWS IN THEM. ────────────────────────────
    //
    // `consoleOverrides` fakes the dashboard's counters, but the LIST screens
    // above are swept against the dummy Supabase, so their own providers reject
    // and each one lays out an empty or error state. The comment on that map
    // says so — "these sweep the loading/empty/error layouts" — and that is a
    // real corner. It is also only half a job: an empty table has no plate pill
    // to overflow, no six-figure Rand figure to ellipsise and no long company
    // name to break a row.
    //
    // The portal sweep gained the same second pass on 2026-08-20 and it found
    // seven failing screens immediately. This is the console's half, using the
    // fixtures the render harness already installs.
    //
    // Two text scales rather than five: the data pass is several times the work
    // per screen and 1.0/1.3 are the ends of the range `ConsolePrefs` offers.
    // 1.6 and 2.0 stay on the empty pass, where they are cheap.
    const withData = [
      'recon tables',
      'margin ledger',
      'dispute inbox',
      'request tracking',
    ];
    for (final key in withData) {
      testWidgets('$key survives every width x text scale, WITH ROWS',
          (tester) async {
        await sweep(
          tester,
          screens[key]!,
          overrides: [
            ...consoleOverrides,
            ...companyScopeOverrides(),
            ...consoleCaptureOverrides(),
            ...portalCaptureOverrides(),
          ],
          scales: const [1.0, 1.3],
        );
      });
    }

    testWidgets('dashboard survives bold text', (tester) async {
      await sweep(tester, () => const SuperAdminDashboardV2Screen(),
          overrides: consoleOverrides, boldText: true);
    });
  });

  group('v2 layouts', () {
    testWidgets('dashboard survives every width x text scale', (tester) async {
      await sweep(tester, () => MineLinkDashboardScreen(
            // Explicit fixture data. These four used to DEFAULT to
            // `MlSampleData`, which is exactly how fabricated platform
            // totals could reach a real admin (P9-03). A layout sweep is
            // the one legitimate caller of sample data — so it now says
            // so, out loud, at the call site.
            orgAggregates: MlSampleData.orgAggregates,
            pendingRequests: MlSampleData.pendingRequests,
            registry: MlSampleData.registry,
            recentOrgs: MlSampleData.recentOrgs,
          ));
    });

    testWidgets('dashboard survives bold text', (tester) async {
      await sweep(
          tester,
          () => MineLinkDashboardScreen(
                orgAggregates: MlSampleData.orgAggregates,
                pendingRequests: MlSampleData.pendingRequests,
                registry: MlSampleData.registry,
                recentOrgs: MlSampleData.recentOrgs,
              ),
          boldText: true);
    });

    testWidgets('transporters survives every width x text scale',
        (tester) async {
      await sweep(
        tester,
        () => TransportersOverviewBody(data: _transportersFixture()),
      );
    });

    testWidgets('transporters survives bold text', (tester) async {
      await sweep(
        tester,
        () => TransportersOverviewBody(data: _transportersFixture()),
        boldText: true,
      );
    });

    // A target draws an extra caption and legend key inside the plot; the
    // no-target case is the one the screen ships with until somebody sets one.
    testWidgets('transporters survives a target line', (tester) async {
      await sweep(
        tester,
        () => TransportersOverviewBody(
          data: _transportersFixture(target: 42000),
        ),
      );
    });
  });
}

/// A busy month: long company names, five fleets, a variance, a missing POD
/// and enough open waybills to colour the ladder. Deliberately wordier than
/// the design's dataset — the widths that break are the ones with real names
/// in them.
OverviewData _transportersFixture({double? target}) {
  final now = DateTime(2026, 8, 20, 12);

  CompanyMonthlyOpsStats company(
    String name, {
    required double tons,
    required int trips,
    required int fleet,
    required int done,
    required int open,
  }) =>
      CompanyMonthlyOpsStats(
        companyId: name,
        companyName: name,
        orgType: 'transporter',
        fleetVehicles: fleet,
        drivers: fleet - 4,
        employees: fleet + 12,
        routesDistinct: 9,
        trips: trips,
        loadsCount: trips,
        tonsMoved: tons,
        completedWaybills: done,
        pendingWaybills: open,
      );

  final companies = [
    company('Roadhaul Logistics & Bulk Haulage',
        tons: 12420.5, trips: 180, fleet: 42, done: 140, open: 6),
    company('Trans African Haul', tons: 9880.1, trips: 140, fleet: 31, done: 96, open: 9),
    company('Corridor Freight', tons: 6940.1, trips: 100, fleet: 23, done: 82, open: 3),
    company('b man trans', tons: 0, trips: 0, fleet: 6, done: 0, open: 0),
    company('Land Rover Transport', tons: 120.4, trips: 2, fleet: 4, done: 2, open: 1),
  ];

  final rows = <RawReconRow>[
    for (var day = 1; day <= 20; day++)
      RawReconRow(
        tripId: 'aug-$day',
        tripDate: DateTime(2026, 8, day),
        timeIn: DateTime(2026, 8, day, 7),
        timeOut: DateTime(2026, 8, day, 14),
        transporterName: 'Roadhaul Logistics & Bulk Haulage',
        truckReg: 'RH ${100 + day} GP',
        netMass: 900 + day * 31.5,
        deliveredTons: 900 + day * 31.5,
        tripStatus: 'completed',
        podPhotoPath: day.isEven ? 'pod/$day.jpg' : null,
      ),
    for (var day = 1; day <= 31; day++)
      RawReconRow(
        tripId: 'jul-$day',
        tripDate: DateTime(2026, 7, day),
        transporterName: 'Trans African Haul',
        truckReg: 'TH ${200 + day} GP',
        netMass: 700 + day * 12.0,
      ),
    RawReconRow(
      tripId: 'variance',
      tripDate: DateTime(2026, 8, 11),
      transporterName: 'Corridor Freight',
      truckReg: 'CF 001 GP',
      netMass: 34.2,
      deliveredTons: 29.4,
    ),
  ];

  return TransportersOverviewMapper.build(
    bundle: MonthlyInsightsBundle(
      companies: companies,
      aggregate: OrgTypeAggregateStats(
        orgType: 'transporter',
        companyCount: companies.length,
        activeTripsApprox: 12,
        fleetVehiclesTotal: companies.fold(0, (s, c) => s + c.fleetVehicles),
        tonsMoved: 29240.5,
        transactionsTotal: 422,
        completedWaybills: 320,
        pendingWaybills: 19,
      ),
    ),
    rows: rows,
    targetTons: target,
    now: now,
  );
}
