// Renders the redesign to PNGs you can actually look at.
//
// The app needs a Supabase session to reach the console, so a browser visit
// only ever shows the login screen. These goldens render the real screens —
// real widgets, real fonts, real fixture data — inside the real shell, so the
// design can be judged without credentials and without a device.
//
// Regenerate:
//
//     flutter test test/renders --update-goldens
//
// Output lands in docs/redesign/renders/.
//
// This is a RENDER test, not an assertion test. It is expected to be updated
// whenever the design changes on purpose; the layout sweeps in test/widgets are
// what actually fail on a regression. Keeping the two apart matters — a golden
// that fails on every intentional change teaches people to regenerate without
// looking, which is worse than having no golden at all.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// `hide UserIdentity`: gotrue exports a class of the same name, and this file
// wants the design system's.
import 'package:supabase_flutter/supabase_flutter.dart' hide UserIdentity;

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/core/design/shell/ml_rail_blocks.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_dashboard.dart';

import '../fixtures/ml_sample_data.dart';
import '../test_helpers/real_fonts.dart';

void main() {
  setUpAll(() async {
    await loadRealFonts();
    final icons = await loadMaterialIcons();
    // A render nobody can read is not evidence. Say so loudly rather than
    // quietly producing a grid of hollow squares and calling it a screenshot.
    if (!icons) {
      // ignore: avoid_print
      print('WARNING: MaterialIcons not found in the SDK cache — every icon in '
          'these renders will be an empty box.');
    }
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'render-test-key',
    );
  });

  /// The console dashboard inside the real shell.
  Widget console({
    required Brightness brightness,
    bool railExpanded = true,
  }) {
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(brightness),
        home: MlAppShell(
          tree: consoleNavTree(),
          selectedRoute: '/super-admin',
          onNavigate: (_) {},
          title: 'Global Admin',
          subtitle: 'Platform overview',
          expanded: railExpanded,
          onExpandedChanged: (_) {},
          badgeCounts: const {
            MlNavBadge.pendingRequests: 4,
            MlNavBadge.openDisputes: 2,
            MlNavBadge.unreadNotifications: 7,
          },
          leading: const BackButton(),
          railHeader: MlRailBrand(
            expanded: railExpanded,
            subtitle: 'GLOBAL ADMIN',
            onTap: () {},
          ),
          railFooter: MlRailIdentity(
            expanded: railExpanded,
            identity: const UserIdentity(
              name: 'Jean Blak',
              email: 'jean@cyberhouse.co.za',
              roleLabel: 'Super Admin',
            ),
            onOpenProfile: () {},
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
          // Explicit fixture data. These four used to DEFAULT to MlSampleData,
          // which is how fabricated platform totals could reach a real admin
          // (P9-03). A render test is a legitimate caller of sample data — so
          // it says so, out loud, at the call site.
          child: MineLinkDashboardScreen(
            orgAggregates: MlSampleData.orgAggregates,
            pendingRequests: MlSampleData.pendingRequests,
            registry: MlSampleData.registry,
            recentOrgs: MlSampleData.recentOrgs,
          ),
        ),
      ),
    );
  }

  Future<void> shoot(
    WidgetTester tester,
    Widget widget,
    Size size,
    String name,
  ) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Capture layout faults instead of failing on them, then REPORT them and
    // still write the image.
    //
    // The point of this file is to produce something to look at. A render that
    // refuses to exist because the screen inside it overflows tells you less
    // than the picture of it overflowing — and the picture is what makes the
    // fault arguable. The layout sweeps in test/widgets are what fail the
    // build; this one documents.
    final captured = <String>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      final s = d.exception.toString();
      if (s.contains('overflowed') ||
          s.contains('forces an infinite') ||
          s.contains('BoxConstraints')) {
        captured.add(s.split('\n').first);
      } else {
        previousOnError?.call(d);
      }
    };

    await tester.pumpWidget(widget);
    // Long enough for the shell's entrance transition and any staged reveal to
    // settle. pumpAndSettle would hang: the console has continuously running
    // animations (the live pill, the bell).
    await tester.pump(const Duration(milliseconds: 900));

    FlutterError.onError = previousOnError;
    tester.takeException();

    if (captured.isNotEmpty) {
      // ignore: avoid_print
      print('RENDER NOTE [$name] ${captured.length} layout fault(s) at '
          '${size.width.toInt()}x${size.height.toInt()}:');
      for (final c in captured.toSet()) {
        // ignore: avoid_print
        print('  - $c');
      }
    }

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/redesign/renders/$name.png'),
    );
  }

  group('console', () {
    testWidgets('desktop dark — expanded rail', (tester) async {
      await shoot(
        tester,
        console(brightness: Brightness.dark),
        const Size(1600, 1900),
        'console-desktop-dark',
      );
    });

    testWidgets('desktop light — expanded rail', (tester) async {
      await shoot(
        tester,
        console(brightness: Brightness.light),
        const Size(1600, 1900),
        'console-desktop-light',
      );
    });

    testWidgets('desktop dark — collapsed rail', (tester) async {
      await shoot(
        tester,
        console(brightness: Brightness.dark, railExpanded: false),
        const Size(1600, 1900),
        'console-desktop-dark-rail-collapsed',
      );
    });

    testWidgets('medium — the rail narrows, nothing is removed',
        (tester) async {
      await shoot(
        tester,
        console(brightness: Brightness.dark),
        const Size(760, 1400),
        'console-medium-dark',
      );
    });

    testWidgets('phone dark — bottom bar and drawer', (tester) async {
      await shoot(
        tester,
        console(brightness: Brightness.dark),
        const Size(412, 915),
        'console-phone-dark',
      );
    });

    testWidgets('phone light', (tester) async {
      await shoot(
        tester,
        console(brightness: Brightness.light),
        const Size(412, 915),
        'console-phone-light',
      );
    });
  });
}
