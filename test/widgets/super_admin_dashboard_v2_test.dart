// The v2 dashboard was unreferenced dead code until it was mounted, so nothing
// had ever rendered it. Two latent faults only appear once it paints — an
// unbounded-width Flexible in the org-card metrics, and a coloured left border
// combined with a borderRadius (legal in CSS, an assertion in Flutter). These
// tests render the screen so neither can come back unnoticed.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_dashboard_v2_screen.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_dashboard.dart';
import '../fixtures/ml_sample_data.dart';

Widget _host(Widget child, double width) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: width, height: 900, child: child),
        ),
      ),
    );

/// The width the super-admin shell actually hands the content area on a 1920px
/// window, measured against the real shell: 1660 minus the screen's own 24px
/// side padding.
const double _contentWidth = 1612;

SuperAdminDashboardV2ViewModel _emptyVm() =>
    SuperAdminDashboardV2ViewModel.from(
      stats: const <String, dynamic>{},
      organizations: const <Map<String, dynamic>>[],
      rows: const <RawReconRow>[],
      transporters: null,
      buyers: null,
      mines: null,
      mineTransportCount: 0,
      buyerTransportCount: 0,
      productCount: 0,
      buyerRequestCount: 0,
      now: DateTime(2026, 8, 8),
    );

void main() {
  setUp(() {
    // 1920x1080 so the four-up registry grid is the path under test.
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('the screen renders', () {
    testWidgets('all six sections at the real content width', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester
          .pumpWidget(_host(_sampleDashboard(), _contentWidth));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Live operations by organization type'), findsOneWidget);
      expect(find.text('Pending requests'), findsOneWidget);
      expect(find.text('Platform registry'), findsOneWidget);
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.text('Recently active organizations'), findsOneWidget);
    });

    testWidgets('single-column below the 1180 breakpoint', (tester) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_host(_sampleDashboard(), 900));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Platform registry'), findsOneWidget);
    });
  });

  group('live data', () {
    test('an empty platform produces blanks, not invented figures', () {
      final vm = _emptyVm();

      expect(vm.recentOrgs, isEmpty);
      expect(vm.orgAggregates, hasLength(3));
      expect(vm.registry, hasLength(8));
      // Zero counts must not borrow the drop's 1 / 2 / 1.
      expect(vm.pendingRequests.every((p) => p.count == 0), isTrue);
      // Sparklines stay fixed-length: an empty list would make reduce() throw.
      for (final a in vm.orgAggregates) {
        expect(a.spark, isNotEmpty);
        expect(a.spark.every((v) => v == 0), isTrue);
      }
    });

    testWidgets('renders an empty platform without exception', (tester) async {
      tester.view.physicalSize = const Size(1920, 1080);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final vm = _emptyVm();
      await tester.pumpWidget(_host(
        MineLinkDashboardScreen(
          orgAggregates: vm.orgAggregates,
          pendingRequests: vm.pendingRequests,
          registry: vm.registry,
          recentOrgs: vm.recentOrgs,
        ),
        _contentWidth,
      ));
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('No organizations of this type in the current window.'),
          findsOneWidget);
    });
  });

  testWidgets('table tab counts come from the rows, not the drop constants',
      (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Only the table is populated, so any count on screen comes from the tabs.
    await tester.pumpWidget(_host(
      MineLinkDashboardScreen(
        orgAggregates: const [],
        pendingRequests: const [],
        registry: const [],
        recentOrgs: MlSampleData.recentOrgs.take(2).toList(),
      ),
      _contentWidth,
    ));
    await tester.pump();

    // The drop hardcoded 24 / 11 / 7 / 6 regardless of the rows beneath.
    expect(find.text('24'), findsNothing);
    expect(find.text('11'), findsNothing);
    // 'All types' now reports the 2 rows actually passed in.
    expect(find.text('2'), findsWidgets);
  });

  test('nav ids resolve to real console routes', () {
    // Every id the screen can emit either routes somewhere or is a known
    // no-destination action.
    const emitted = [
      'insights.transporters',
      'insights.buyers',
      'insights.mines',
      'requests',
      'requests.mine-transport',
      'requests.product',
      'requests.buyers',
      'orgs',
      'orgs.active',
      'orgs.expired',
      'orgs.suspended',
      'users',
      'users.active',
      'tokens.requests',
      'tokens.history',
      'tokens.audit',
      'register',
    ];
    for (final id in emitted) {
      expect(dashboardNavRoute(id), isNotNull, reason: '$id goes nowhere');
      expect(dashboardNavRoute(id), startsWith('/super-admin'));
    }
    // 'export' is drawn by the drop but has no report generator behind it.
    expect(dashboardNavRoute('export'), isNull);
  });
}

/// The dashboard wired to explicit fixture data.
///
/// `orgAggregates` / `pendingRequests` / `registry` / `recentOrgs` used to
/// DEFAULT to `MlSampleData`, which meant a caller omitting one shipped
/// fabricated platform totals to a real admin (P9-03). They are required now,
/// so a layout test has to say out loud that it is using sample data — which
/// is the one place doing so is correct.
MineLinkDashboardScreen _sampleDashboard() => MineLinkDashboardScreen(
      orgAggregates: MlSampleData.orgAggregates,
      pendingRequests: MlSampleData.pendingRequests,
      registry: MlSampleData.registry,
      recentOrgs: MlSampleData.recentOrgs,
    );
