// Layout sweep for the THREE ORG PORTALS — mine/supplier, buyer, transporter.
//
// The super-admin console has had `super_admin_overflow_sweep_test.dart` for
// some time. The portals had NOTHING: not one widget test rendered a portal
// dashboard. That is the half of the product every customer actually uses.
//
// Why this matters more than it sounds (CLAUDE.md §10.4): the console applies a
// per-user text scale (0.85–1.3) and bold-text through MediaQuery, and portal
// users get the same treatment. A tile that sits 1px inside its box at 1.0
// overflows for anyone who nudged the slider. Both real bugs found in the
// targets work only appeared at 1.3.
//
// The real fonts are loaded. Without them `flutter test` substitutes a face
// where every glyph is one em wide, so a 9-character label at fontSize 9
// measures 81px instead of ~45px — which both invents overflows that do not
// exist and hides ones that do.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
// The capture fixtures, so the second pass below sweeps screens with real
// rows in their tables rather than their empty states.

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/features/portal/providers/mirror_company_context_provider.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_loads_value_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_requests_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_waybills_screen.dart';
import 'package:flutter_application_1/features/portal/screens/compliance_screen.dart';
import 'package:flutter_application_1/features/portal/screens/earnings_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_production_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_quality_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_tons_out_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_trips_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_maintenance_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_routes_screen.dart';
import 'package:flutter_application_1/features/portal/screens/trucks_on_route_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_routes_mines_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/driver_app_screen.dart';
import 'package:flutter_application_1/features/portal/screens/driver_routes_screen.dart';
import 'package:flutter_application_1/features/portal/screens/fuel_costs_screen.dart';
import 'package:flutter_application_1/features/portal/screens/load_controller_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_buyers_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_own_company_screen.dart';
import 'package:flutter_application_1/features/portal/screens/request_transportation_screen.dart';
import 'package:flutter_application_1/features/portal/screens/security_checkin_screen.dart';
import 'package:flutter_application_1/features/portal/screens/stockpile_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/supervisor_view_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_request_tracking_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_truck_positions_screen.dart';
import 'package:flutter_application_1/features/portal/screens/appearance_theme_screen.dart';
import 'package:flutter_application_1/features/portal/screens/drop_off_screen.dart';
import 'package:flutter_application_1/features/portal/screens/live_trip_map_screen.dart';
import 'package:flutter_application_1/features/portal/screens/loading_activity_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_trip_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/stockpile_audit_screen.dart';
import 'package:flutter_application_1/features/portal/screens/tons_out_detail_screen.dart';

/// Narrow phone, small tablet, desktop rail width. The 360 is the one that
/// matters most: drivers and security run this on a phone.
import '../fixtures/portal_capture_fixtures.dart';
import '../fixtures/screen_fixtures.dart';
import '../test_helpers/frozen_clock.dart';

const _widths = <double>[360, 800, 1280];
const _scales = <double>[0.85, 1.0, 1.3, 1.6, 2.0];

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  var loaded = false;
  for (final f in files) {
    final file = File('assets/fonts/$f');
    if (!file.existsSync()) continue;
    loaded = true;
    loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
  }
  if (loaded) await loader.load();
}

Future<void> _loadRealFonts() async {
  await _loadFont('PlusJakartaSans', [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]);
  await _loadFont('JetBrainsMono', [
    'JetBrainsMono-Regular.ttf',
    'JetBrainsMono-Medium.ttf',
    'JetBrainsMono-Bold.ttf',
  ]);
  await _loadFont('Fraunces', ['Fraunces-Medium.ttf', 'Fraunces-SemiBold.ttf']);
}

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await _loadRealFonts();
    // Portal screens touch Supabase.instance while building. A dummy instance
    // gets them rendering; no request is ever made, so every provider resolves
    // to its empty or error state — which is the state most likely to overflow,
    // because an error message is longer than the figure it replaced.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'portal-overflow-sweep',
    );
  });

  /// Renders [child] across every width × scale and fails on the first layout
  /// fault, naming the exact corner so the failure is actionable.
  Future<void> sweep(
    WidgetTester tester,
    Widget Function() child, {
    bool boldText = false,
    List<Override> overrides = const [],
    List<double> scales = _scales,
  }) async {
    for (final width in _widths) {
      for (final scale in scales) {
        tester.view.physicalSize = Size(width, 1400);
        tester.view.devicePixelRatio = 1.0;

        final captured = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = captured.add;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Without a company id every portal screen short-circuits to
              // "Company not loaded" — a Center with one short label, which
              // cannot overflow. The sweep would then pass 27 times having
              // laid out nothing. This is the difference between a real sweep
              // and a green tick.
              mirrorCompanyIdProvider.overrideWith((ref) => 'sweep-company'),
              // THE REAL FIXTURES, not an empty app.
              //
              // A company id alone gets past "Company not loaded", and the
              // note below says so — but every provider then resolves to an
              // EMPTY list, so this sweep spent 27 screens laying out empty
              // states. An empty state is short, and short things do not
              // overflow (CLAUDE.md §10.5).
              //
              // Measured 2026-08-23 by turning the data on: four real
              // overflows the sweep had always passed, on screens it had
              // always covered —
              //
              //   the load controller's truck identity row      22 px @ 360x2.0
              //   the load controller's whole wide branch       @ 800x2.0
              //   the buyer reconciliation card's header        21 px @ 360x2.0
              //   the buyer reconciliation card's two buttons   32 px @ 360x2.0
              //
              // and a fifth on the driver's hero card, which this sweep still
              // cannot see because the hero only exists when there is a trip
              // to put in it (`driver_week_figures_name_their_basis_test`).
              //
              // The load controller's own source already carried a comment
              // about a 29 px overflow "that no sweep had seen because the
              // sweep ran with no trips" — found by hand, fixed by hand, and
              // the sweep left blind to the next one. This is that comment
              // turned into coverage.
              ...portalCaptureOverrides(),
              ...overrides,
            ],
            child: MaterialApp(
                          // The REAL app theme: a bare ThemeData leaves buttons on
            // Material defaults, and default paddings differ from the app's,
            // which changes what does and does not overflow.
              theme: AppTheme.darkTheme,
              builder: (context, c) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  boldText: boldText,
                ),
                child: c!,
              ),
              home: Builder(
                builder: (context) => Scaffold(
                  backgroundColor: MlSemantic.of(context).surfaceApp,
                  body: SizedBox(width: width, child: child()),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        FlutterError.onError = previousOnError;
        tester.takeException();

        // Only layout faults are in scope. Re-pumping one tester across 9
        // corners also provokes provider-disposal races that belong to the
        // harness, not the screen, and would make this sweep cry wolf.
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

  final screens = <String, Widget Function()>{
    // Mine / supplier
    'mine dashboard': () => const MineSupplierPortalDashboardScreen(),
    'mine production': () => const MineProductionScreen(),
    'mine quality': () => const MineQualityScreen(),
    'tons out': () => const PortalTonsOutScreen(),
    // Buyer
    'buyer dashboard': () => const BuyerPortalDashboardScreen(),
    'buyer loads & value': () => const BuyerLoadsValueScreen(),
    'buyer requests': () => const BuyerRequestsScreen(),
    'buyer waybills': () => const BuyerWaybillsScreen(),
    // Transporter
    'transporter dashboard': () => const TransporterPortalDashboardScreen(),
    'transporter routes': () => const TransporterRoutesScreen(),
    'transporter maintenance': () => const TransporterMaintenanceScreen(),
    'trucks on route': () => const TrucksOnRouteScreen(),
    // Shared
    'trips': () => const PortalTripsScreen(basePath: '/portal/mine/trips'),
    'compliance': () => const ComplianceScreen(),
    'earnings': () => const EarningsScreen(),
    // ---- second wave: the rest of the portal ---------------------------
    // Mine / supplier
    'mine reconciliations': () => const MineReconciliationsScreen(),
    'mine locations': () => const MineLocationsScreen(),
    'mine buyers detail': () => const MineSupplierBuyersDetailScreen(),
    'mine truck locations': () => const MineSupplierTruckLocationsScreen(),
    'supervisor view': () => const SupervisorViewScreen(),
    'security check-in': () => const SecurityCheckinScreen(),
    'load controller': () => const LoadControllerScreen(),
    'stockpile detail': () => const StockpileDetailScreen(),
    // Buyer
    'buyer reconciliations': () => const BuyerReconciliationsScreen(),
    'buyer routes & mines': () => const BuyerRoutesMinesScreen(),
    'buyer truck locations': () => const BuyerTruckLocationsScreen(),
    'request transportation': () => const RequestTransportationScreen(),
    // Transporter
    'transporter reconciliations': () => const TransporterReconciliationsScreen(),
    'transporter request tracking': () => const TransporterRequestTrackingScreen(),
    'transporter truck locations': () => const TransporterTruckLocationsScreen(),
    'transporter truck positions': () => const TransporterTruckPositionsScreen(),
    'fuel costs': () => const FuelCostsScreen(),
    // Driver
    'driver app': () => const DriverAppScreen(),
    'driver routes': () => const DriverRoutesScreen(),
    // Company
    'own company': () => const PortalOwnCompanyScreen(),
    // ---- third wave: detail routes and the remaining leaves -------------
    'appearance & theme': () => const AppearanceThemeScreen(),
    'live trip map': () => const LiveTripMapScreen(),
    'loading activity detail': () => const LoadingActivityDetailScreen(),
    'stockpile audit': () => const StockpileAuditScreen(),
    // Detail routes take an id. A non-existent one is the RIGHT fixture here:
    // it drives the not-found / error branch, which carries the longest text
    // on the screen and is therefore the most likely corner to overflow.
    'trip detail': () => const PortalTripDetailScreen(tripId: 'sweep-trip'),
    'drop off': () => const DropOffScreen(tripId: 'sweep-trip'),
    // Empty list, not a fabricated row: an empty table renders its empty
    // state, and inventing rows here would be inventing data.
    'tons out detail': () => const TonsOutDetailScreen(entries: []),
  };

  group('portal screens', () {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} survives every width x text scale',
          (tester) async {
        await sweep(tester, entry.value);
      });
    }
  });

  // ---------------------------------------------------------------------
  // THE SAME SCREENS, WITH ROWS IN THEM.
  //
  // Everything above renders with no data behind it. That is deliberate and it
  // is documented — an error state carries more text than the figure it
  // replaced, so it is a real corner — but it is only half the job, and the
  // half it misses is the half with tables in it. CLAUDE.md §10.5: a green test
  // over an empty fixture proves nothing.
  //
  // Measured 2026-08-20: three tables overflowed at 412px with rows in them —
  // 24px on the super-admin recon screen's quality table, 35px and 4.6px on the
  // buyer's reconciliations — and every one of the 27 corners above passed,
  // because with no rows there is no plate pill to overflow. A plate is 114px
  // of fixed content in a flex column, which is exactly the case an empty table
  // cannot show.
  //
  // Two text scales rather than five. The data pass is roughly 3x the work per
  // screen (real rows, real tables, real exports) and 1.0/1.3 are the ends of
  // the range `ConsolePrefs` actually offers; 1.6 and 2.0 stay on the empty
  // pass, where they are cheap. Widening this later is a runtime decision, not
  // a correctness one.
  group('portal screens, with data', () {
    // Only the screens the capture fixtures genuinely populate. A screen listed
    // here that the fixtures do not reach would sweep its error state twice and
    // report it as coverage.
    const withData = [
      'mine dashboard',
      'buyer dashboard',
      'transporter dashboard',
      'mine reconciliations',
      'buyer reconciliations',
      'transporter reconciliations',
      'tons out',
      'load controller',
      'security check-in',
      'buyer loads & value',
      'buyer waybills',
      'earnings',
      'fuel costs',
      'mine quality',
      'mine production',
      'driver routes',
      // Second batch, 2026-08-20. Every one of these is reached by the capture
      // fixtures and was sweeping its EMPTY state before.
      'transporter routes',
      'transporter maintenance',
      'trucks on route',
      'trips',
      'buyer requests',
      'supervisor view',
    ];
    for (final key in withData) {
      testWidgets('$key survives every width x text scale, WITH ROWS',
          (tester) async {
        await sweep(
          tester,
          screens[key]!,
          overrides: [
            ...companyScopeOverrides(),
            ...portalCaptureOverrides(),
          ],
          scales: const [1.0, 1.3],
        );
      });
    }
  });

  group('portal screens, bold text', () {
    // Bold text widens every glyph. Run it over the three dashboards, which
    // are the densest layouts and the ones every user lands on.
    for (final key in const [
      'mine dashboard',
      'buyer dashboard',
      'transporter dashboard',
    ]) {
      testWidgets('$key survives bold text', (tester) async {
        await sweep(tester, screens[key]!, boldText: true);
      });
    }
  });
}
