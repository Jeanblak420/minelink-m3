// Error-state RECOVERY contract for the three org portals.
//
// Found by looking at the S5-20 before-images (docs/design-reference/
// portal-mine-*.png), not by reading code. Three of the mine portal's eight
// captures were nothing but a centred grey panel reading "Could not load this"
// — no page title, no indication of which screen had failed, and no way to
// try again. The whole screen, title included, lives inside `.when(data:)`,
// so any failure takes the screen's identity down with the data.
//
// Why this is a release defect rather than a polish item: `friendly_error.dart`
// says it itself — "Network first: it is by far the most common real cause on
// a haul road". The dominant failure in this product is a transient one. A
// security guard at a mine gate on patchy signal opens Security check-in, the
// request drops, and the screen becomes a dead end: no retry, and nothing on
// it naming what failed. The truck does not get checked in. Recovering means
// knowing to navigate away and back.
//
// Measured before the fix: 27 MlEmptyState error states across lib/features/
// portal — 4 offered a retry, 23 did not; 16 were titled exactly
// "Could not load this", which names nothing.
//
// The contract asserted here, for any screen that renders a load failure:
//   1. it offers a way to try again, and
//   2. the title says what failed, so the screen keeps its identity.
//
// Harness notes, both learned the hard way on this suite (CLAUDE.md §7, §10.5):
// the real fonts are loaded, because the fallback face makes every glyph one em
// wide and misstates every text width; and the real AppTheme is used, because a
// bare ThemeData leaves buttons on Material's defaults.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/features/portal/providers/mirror_company_context_provider.dart';
import 'package:flutter_application_1/core/design/components/ml_empty_state.dart';

import 'package:flutter_application_1/features/portal/screens/buyer_loads_value_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_requests_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_waybills_screen.dart';
import 'package:flutter_application_1/features/portal/screens/compliance_screen.dart';
import 'package:flutter_application_1/features/portal/screens/earnings_screen.dart';
import 'package:flutter_application_1/features/portal/screens/load_controller_screen.dart';
import 'package:flutter_application_1/features/portal/screens/loading_activity_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_production_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_buyers_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/security_checkin_screen.dart';
import 'package:flutter_application_1/features/portal/screens/supervisor_view_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_maintenance_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_routes_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_truck_positions_screen.dart';
import 'package:flutter_application_1/features/portal/screens/trucks_on_route_screen.dart';

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
    await _loadRealFonts();
    // No backend: every provider that reaches Supabase resolves to its error
    // state. That is not a limitation of this test, it IS the test — this is
    // the same code path a dropped connection on a haul road takes.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'portal-error-recovery',
    );
  });

  /// Pumps [child] with a company id present and returns every failure panel
  /// on screen.
  ///
  /// Screens are only asserted against when they actually render a failure. A
  /// screen that resolves to data or to an honest empty state is not in scope
  /// here and is silently skipped rather than forced — inventing a failure to
  /// assert on would be asserting on the harness.
  Future<List<MlEmptyState>> failurePanels(
    WidgetTester tester,
    Widget Function() child,
  ) async {
    tester.view.physicalSize = const Size(1280, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final previousOnError = FlutterError.onError;
    FlutterError.onError = (_) {};
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Without an id every portal screen short-circuits to "Company not
          // loaded" before it ever reaches a data provider, and this suite
          // would pass having rendered nothing but the guard.
          mirrorCompanyIdProvider.overrideWith((ref) => 'recovery-company'),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: MlSemantic.of(context).surfaceApp,
              body: child(),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    FlutterError.onError = previousOnError;
    tester.takeException();

    return tester
        .widgetList<MlEmptyState>(find.byType(MlEmptyState))
        .where((w) => w.title.startsWith('Could not load'))
        .toList();
  }

  final screens = <String, Widget Function()>{
    // Mine / supplier
    'mine production': () => const MineProductionScreen(),
    'mine locations': () => const MineLocationsScreen(),
    'mine buyers detail': () => const MineSupplierBuyersDetailScreen(),
    'mine truck locations': () => const MineSupplierTruckLocationsScreen(),
    'supervisor view': () => const SupervisorViewScreen(),
    'security check-in': () => const SecurityCheckinScreen(),
    'load controller': () => const LoadControllerScreen(),
    'loading activity detail': () => const LoadingActivityDetailScreen(),
    // Buyer
    'buyer loads & value': () => const BuyerLoadsValueScreen(),
    'buyer reconciliations': () => const BuyerReconciliationsScreen(),
    'buyer requests': () => const BuyerRequestsScreen(),
    'buyer waybills': () => const BuyerWaybillsScreen(),
    'buyer truck locations': () => const BuyerTruckLocationsScreen(),
    // Transporter
    'transporter routes': () => const TransporterRoutesScreen(),
    'transporter maintenance': () => const TransporterMaintenanceScreen(),
    'transporter reconciliations': () => const TransporterReconciliationsScreen(),
    'transporter truck locations': () => const TransporterTruckLocationsScreen(),
    'transporter truck positions': () => const TransporterTruckPositionsScreen(),
    'trucks on route': () => const TrucksOnRouteScreen(),
    // Shared
    'compliance': () => const ComplianceScreen(),
    'earnings': () => const EarningsScreen(),
  };

  group('a failed portal screen can be recovered from', () {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} offers a way to try again', (tester) async {
        final panels = await failurePanels(tester, entry.value);
        if (panels.isEmpty) return; // resolved to data or an empty state

        for (final panel in panels) {
          expect(
            panel.action,
            isNotNull,
            reason: '"${entry.key}" fails with "${panel.title}" and no way to '
                'retry. On patchy signal at a mine gate that is a dead end: '
                'the user must navigate away and back to reload.',
          );
        }
      });
    }
  });

  group('a failed portal screen still says what failed', () {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} names the thing that failed', (tester) async {
        final panels = await failurePanels(tester, entry.value);
        if (panels.isEmpty) return;

        for (final panel in panels) {
          expect(
            panel.title,
            isNot('Could not load this'),
            reason: '"${entry.key}" replaces the entire screen — title and '
                'all — with an anonymous "Could not load this". The user '
                'cannot tell which screen failed, or what to tell support.',
          );
        }
      });
    }
  });
}
