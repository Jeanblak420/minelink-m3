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

import 'package:flutter_application_1/core/design/shell/ml_app_shell.dart';
import 'package:flutter_application_1/core/design/shell/ml_rail_blocks.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/widgets/user_identity_flyout.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/screens/login_screen.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
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

  /// A portal shell for one org type and role.
  ///
  /// The BODY is deliberately an empty-state placeholder rather than a real
  /// portal dashboard. Those screens need a company, a session and live
  /// providers; rendering one here would show a spinner or an error, and a
  /// picture of an error state is not a picture of the design.
  ///
  /// What these renders are FOR is the thing Jean actually asked about — "the
  /// placement of everything" — which is the shell: the rail, its grouping and
  /// ordering for that role, the top bar, the workspace canvas, and how all of
  /// it reflows onto a phone. That is real in every one of these, and it is
  /// exactly what differs between the four roles.
  Widget portal({
    required Brightness brightness,
    required OrgType orgType,
    required UserRole? role,
    required String title,
    required String subtitle,
    required String roleLabel,
    required String selectedRoute,
    bool railExpanded = true,
  }) {
    final tree = portalNavTree(orgType: orgType, role: role);
    return ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(brightness),
        home: MlAppShell(
          tree: tree,
          selectedRoute: selectedRoute,
          onNavigate: (_) {},
          title: title,
          subtitle: subtitle,
          expanded: railExpanded,
          onExpandedChanged: (_) {},
          badgeCounts: const {
            MlNavBadge.pendingRequests: 2,
            MlNavBadge.unreadNotifications: 5,
          },
          railHeader: MlRailBrand(
            expanded: railExpanded,
            subtitle: roleLabel.toUpperCase(),
            onTap: () {},
          ),
          railFooter: MlRailIdentity(
            expanded: railExpanded,
            identity: UserIdentity(
              name: 'Fixture Operator',
              email: 'operator@fixture.co.za',
              roleLabel: roleLabel,
            ),
            onOpenProfile: () {},
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined),
            ),
          ],
          child: const _PortalBodyPlaceholder(),
        ),
      ),
    );
  }

  /// The login screen — the only screen in the product every single user sees,
  /// and the only one that had no picture.
  Widget login(Brightness brightness) => ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.build(brightness),
          home: const LoginScreen(),
        ),
      );

  group('auth', () {
    testWidgets('login desktop dark', (tester) async {
      await shoot(tester, login(Brightness.dark), const Size(1440, 1000),
          'login-desktop-dark');
    });
    testWidgets('login phone dark', (tester) async {
      await shoot(tester, login(Brightness.dark), const Size(412, 915),
          'login-phone-dark');
    });
  });

  group('portal — one shell, four roles', () {
    testWidgets('transporter desktop dark', (tester) async {
      await shoot(
        tester,
        portal(
          brightness: Brightness.dark,
          orgType: OrgType.transporter,
          role: UserRole.admin,
          title: 'Fixture Haulage',
          subtitle: 'Transporter workspace',
          roleLabel: 'Admin',
          selectedRoute: '/portal/transporter',
        ),
        // Tall enough for the whole rail. At 1400 the last group was
        // clipped mid-item -- it scrolls in the app, but in a PICTURE a
        // half-drawn row reads as a layout bug rather than as a scroll.
        const Size(1600, 1750),
        'portal-transporter-desktop-dark',
      );
    });

    testWidgets('mine / supplier desktop dark', (tester) async {
      await shoot(
        tester,
        portal(
          brightness: Brightness.dark,
          orgType: OrgType.mineSupplier,
          role: UserRole.admin,
          title: 'Iron Hills Mining',
          subtitle: 'Mine workspace',
          roleLabel: 'Admin',
          selectedRoute: '/portal/mine',
        ),
        // Tall enough for the whole rail. At 1400 the last group was
        // clipped mid-item -- it scrolls in the app, but in a PICTURE a
        // half-drawn row reads as a layout bug rather than as a scroll.
        const Size(1600, 1750),
        'portal-mine-desktop-dark',
      );
    });

    testWidgets('buyer desktop light', (tester) async {
      await shoot(
        tester,
        portal(
          brightness: Brightness.light,
          orgType: OrgType.buyer,
          role: UserRole.admin,
          title: 'Fixture Metals',
          subtitle: 'Buyer workspace',
          roleLabel: 'Admin',
          selectedRoute: '/portal/buyer',
        ),
        // Tall enough for the whole rail. At 1400 the last group was
        // clipped mid-item -- it scrolls in the app, but in a PICTURE a
        // half-drawn row reads as a layout bug rather than as a scroll.
        const Size(1600, 1750),
        'portal-buyer-desktop-light',
      );
    });

    testWidgets('driver phone — the rail becomes a bottom bar', (tester) async {
      await shoot(
        tester,
        portal(
          brightness: Brightness.dark,
          orgType: OrgType.transporter,
          role: UserRole.driver,
          title: 'Fixture Haulage',
          subtitle: 'Driver',
          roleLabel: 'Driver',
          selectedRoute: '/portal/driver',
        ),
        const Size(412, 915),
        'portal-driver-phone-dark',
      );
    });

    testWidgets('transporter phone — the same tree, reflowed', (tester) async {
      await shoot(
        tester,
        portal(
          brightness: Brightness.dark,
          orgType: OrgType.transporter,
          role: UserRole.admin,
          title: 'Fixture Haulage',
          subtitle: 'Transporter workspace',
          roleLabel: 'Admin',
          selectedRoute: '/portal/transporter',
        ),
        const Size(412, 915),
        'portal-transporter-phone-dark',
      );
    });
  });

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

/// Stands in for a portal dashboard in the shell renders.
///
/// It says what it is, on the image, so nobody can mistake one of these for a
/// screenshot of a working dashboard.
class _PortalBodyPlaceholder extends StatelessWidget {
  const _PortalBodyPlaceholder();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.dashboard_customize_outlined,
                size: 44, color: scheme.onSurfaceVariant),
            const SizedBox(height: 14),
            Text('Workspace body',
                textAlign: TextAlign.center,
                style: text.titleMedium?.copyWith(color: scheme.onSurface)),
            const SizedBox(height: 6),
            Text(
              'These renders are of the SHELL — the rail, its grouping for '
              'this role, the top bar and the canvas. The dashboards need a '
              'live session; a picture of their loading state would not be a '
              'picture of the design.',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
