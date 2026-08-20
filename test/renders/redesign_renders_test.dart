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
import 'dart:io';

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
import 'package:flutter_application_1/features/company/screens/company_employees_screen.dart';
import 'package:flutter_application_1/features/employee/screens/employee_profile_screen.dart';
import 'package:flutter_application_1/features/fleet/screens/fleet_management_screen.dart';
import 'package:flutter_application_1/features/operations/screens/operations_hub_screen.dart';
import 'package:flutter_application_1/features/chat/screens/communications_hub_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/driver_routes_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/features/profile_setup/screens/profile_setup_screen.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_dashboard.dart';

import '../fixtures/ml_sample_data.dart';
import '../fixtures/portal_capture_fixtures.dart';
import '../fixtures/screen_fixtures.dart';
import '../test_helpers/real_fonts.dart';

void main() {
  _noOrphanGoldensTest();

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

    // Then load every `Image` for real.
    //
    // `Image.asset` reads the bundle asynchronously, and a widget test's fake
    // async never lets that future complete — so an image resolves only if it
    // is ALREADY in the global cache, which depends entirely on whether an
    // earlier test in the same file happened to draw it. The rail's MineLink
    // wordmark is one, and it is in every render in this file.
    //
    // The symptom was a render that passed alone and failed in the suite:
    // "Pixel test failed, 0.05%, 895px". 895px is the wordmark. The note above
    // records an earlier "0.04%, 895px" that was hunted as an animation and was
    // this same thing — an image cache warmed by test order.
    await tester.runAsync(() async {
      for (final element in find.byType(Image).evaluate()) {
        await precacheImage((element.widget as Image).image, element);
      }
    });
    await tester.pump();


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

  /// A REAL screen inside the real portal shell.
  ///
  /// Distinct from [portal], which renders the shell around a labelled
  /// placeholder. That one exists to show the rail and the reflow; this one
  /// exists to show the screens themselves, and it became possible only when
  /// `test/fixtures/screen_fixtures.dart` learned to supply the company, the
  /// session and the roster each of these gates on. Before that they rendered
  /// spinners and error lines — measured: eight of nineteen painted fewer than
  /// three text runs, and `fleet_management` painted "Company information not
  /// available."
  ///
  /// The data is obviously fake — Fixture Haulage, FIXTURE- ids, a 2020
  /// timestamp — so nothing in these images can be mistaken for a real
  /// company's figures. What is real is every pixel of layout, type, colour
  /// and shape.
  Widget screen({
    required Brightness brightness,
    required Widget child,
    required String title,
    required String subtitle,
    required OrgType orgType,
    required UserRole role,
    required String selectedRoute,
    bool railExpanded = true,
    List<Override> extraOverrides = const [],
  }) {
    return ProviderScope(
      overrides: [...companyScopeOverrides(role: role), ...extraOverrides],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(brightness),
        home: MlAppShell(
          tree: portalNavTree(orgType: orgType, role: role),
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
            subtitle: 'ADMIN',
            onTap: () {},
          ),
          railFooter: MlRailIdentity(
            expanded: railExpanded,
            identity: const UserIdentity(
              name: 'Fixture Operator',
              email: 'operator@fixture.co.za',
              roleLabel: 'Admin',
            ),
            onOpenProfile: () {},
          ),
          actions: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_outlined),
            ),
          ],
          child: child,
        ),
      ),
    );
  }

  group('real screens, real layout', () {
    // Fleet management, the operations hub and the communications hub were
    // DELIBERATELY ABSENT here until 2026-08-20, and the reason is worth
    // keeping because the fix is not what it looked like.
    //
    // All three reached the network while BUILDING: `FleetNotifier`,
    // `OperationsNotifier` and `CommunicationsNotifier` each loaded and opened
    // realtime channels from their CONSTRUCTORS. Against the dummy localhost
    // instance these tests use that is a real socket attempt, and it leaves a
    // pending timer — so a golden failed on "A Timer is still pending even
    // after the widget tree was disposed", which was a true statement rather
    // than a harness artefact. A sweep survives it (it pumps and ends) while
    // `expectLater(matchesGoldenFile)` keeps the body alive long enough for the
    // invariant check to see the timer.
    //
    // The note here said this needed "a Supabase transport fake". It did not.
    // It needed the notifiers to be CONSTRUCTIBLE without a network, which is
    // `start()` — a seam that matters outside tests too, since a notifier that
    // dials out from its constructor cannot serve a preview or a print view.
    // Pumping past the retry never helps, and that is still true: the reconnect
    // reschedules itself, so each pump creates another timer.
    //
    // AND THE 895px WAS THE WORDMARK. This note used to record "Pixel test
    // failed, 0.04%, 895px" as something hunted as an animation. It was
    // `Image.asset` — the rail's MineLink mark, which resolves only if it is
    // already in the global image cache, which depends on whether an earlier
    // test in the file happened to draw it. `shoot()` precaches every image
    // now, and these renders are order-independent. A failing comparison can
    // still mask a failing test; this one WAS the failing test.

    testWidgets('profile setup — desktop light', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.light,
          child: const ProfileSetupScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Profile setup',
          orgType: OrgType.transporter,
          role: UserRole.driver,
          selectedRoute: '/portal/driver',
          extraOverrides: [profileSetupOverride()],
        ),
        const Size(1400, 1500),
        'screen-profile-setup-desktop-light',
      );
    });

    testWidgets('company employees — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const CompanyEmployeesScreen(),
          title: 'Fixture Haulage',
          subtitle: 'People',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
        ),
        const Size(1600, 1200),
        'screen-employees-desktop-dark',
      );
    });

    testWidgets('fleet management — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const FleetManagementScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Fleet',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
        ),
        const Size(1600, 1400),
        'screen-fleet-desktop-dark',
      );
    });

    testWidgets('operations hub — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const OperationsHubScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Operations',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          extraOverrides: [operationsOverride()],
        ),
        const Size(1600, 1200),
        'screen-operations-hub-desktop-dark',
      );
    });

    testWidgets('communications hub — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const CommunicationsHubScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Communications',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          extraOverrides: [communicationsOverride()],
        ),
        const Size(1600, 1200),
        'screen-communications-hub-desktop-dark',
      );
    });

    testWidgets('employee profile — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const EmployeeProfileScreen(
            employeeId: 'FIXTURE-employee',
            canManage: true,
            inPortal: true,
          ),
          title: 'Fixture Haulage',
          subtitle: 'People',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
        ),
        const Size(1600, 1400),
        'screen-employee-profile-desktop-dark',
      );
    });

    // The phone is where the reflow work of this phase actually shows.
    testWidgets('company employees — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const CompanyEmployeesScreen(),
          title: 'Fixture Haulage',
          subtitle: 'People',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
        ),
        const Size(412, 1000),
        'screen-employees-phone-dark',
      );
    });

    testWidgets('profile setup — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const ProfileSetupScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Profile setup',
          orgType: OrgType.transporter,
          role: UserRole.driver,
          selectedRoute: '/portal/driver',
          extraOverrides: [profileSetupOverride()],
        ),
        const Size(412, 1100),
        'screen-profile-setup-phone-dark',
      );
    });
  });

  // -------------------------------------------------------------------------
  // The three role dashboards, WITH DATA.
  //
  // These are the screens the product is actually used through, and until now
  // none of them had a picture. The `portal — one shell, four roles` group
  // above renders the shell around a labelled placeholder, and the placeholder
  // says so on the image: "The dashboards need a live session; a picture of
  // their loading state would not be a picture of the design." That was true
  // and it was also the whole workspace missing from the record.
  //
  // What changed is not a Supabase fake. `test/fixtures/portal_capture_
  // fixtures.dart` already overrode every portal data provider — the seam is
  // the provider, not the transport — and it was only ever wired into the
  // design-REFERENCE capture. Pointing the redesign renders at the same
  // fixtures is all it took.
  //
  // Deliberately not uniform, per that file's own note: one stockpile is over
  // its collect threshold and one is not, one truck is on route and one is
  // available, one load carries a quality penalty, one dispute is open. A
  // fixture where every row looks the same hides exactly the states a design
  // has to handle.
  group('portal dashboards — the workspace, with data', () {
    testWidgets('transporter dashboard — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const TransporterPortalDashboardScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Transporter workspace',
          orgType: OrgType.transporter,
          role: UserRole.admin,
          selectedRoute: '/portal/transporter',
          extraOverrides: portalCaptureOverrides(),
        ),
        const Size(1600, 1900),
        'dash-transporter-desktop-dark',
      );
    });

    testWidgets('mine dashboard — desktop dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const MineSupplierPortalDashboardScreen(),
          title: 'Iron Hills Mining',
          subtitle: 'Mine workspace',
          orgType: OrgType.mineSupplier,
          role: UserRole.admin,
          selectedRoute: '/portal/mine',
          extraOverrides: portalCaptureOverrides(),
        ),
        const Size(1600, 1900),
        'dash-mine-desktop-dark',
      );
    });

    // Light, because the buyer portal is the one place the light theme gets
    // looked at on a data-dense screen, and a theme nobody photographs is a
    // theme nobody checks.
    testWidgets('buyer dashboard — desktop light', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.light,
          child: const BuyerPortalDashboardScreen(),
          title: 'Fixture Metals',
          subtitle: 'Buyer workspace',
          orgType: OrgType.buyer,
          role: UserRole.admin,
          selectedRoute: '/portal/buyer',
          extraOverrides: portalCaptureOverrides(),
        ),
        const Size(1600, 1900),
        'dash-buyer-desktop-light',
      );
    });

    // The driver's Trip screen on a phone — the only screen in this product
    // that is used one-handed, standing next to a truck.
    testWidgets('driver trip — phone dark', (tester) async {
      await shoot(
        tester,
        screen(
          brightness: Brightness.dark,
          child: const DriverRoutesScreen(),
          title: 'Fixture Haulage',
          subtitle: 'Trip',
          orgType: OrgType.transporter,
          role: UserRole.driver,
          selectedRoute: '/portal/driver',
          extraOverrides: portalCaptureOverrides(),
        ),
        const Size(412, 1400),
        'dash-driver-trip-phone-dark',
      );
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

/// Every PNG in `docs/redesign/renders/` must be one this file still produces.
///
/// An orphan golden is a stale picture with nobody to update it: it survives
/// `--update-goldens`, it survives review, and it goes on being the answer when
/// somebody asks what a screen looks like. Three screens were dropped from this
/// file for leaving pending timers, and one of their images stayed behind —
/// which is exactly how a render that no longer reflects the app becomes the
/// one people look at.
void _noOrphanGoldensTest() {
  test('no golden in docs/redesign/renders/ is orphaned', () {
    final source = File('test/renders/redesign_renders_test.dart')
        .readAsStringSync();
    final dir = Directory('docs/redesign/renders');
    final orphans = <String>[];
    for (final f in dir.listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last;
      if (!name.endsWith('.png')) continue;
      final stem = name.substring(0, name.length - 4);
      if (!source.contains("'$stem'")) orphans.add(name);
    }
    expect(
      orphans,
      isEmpty,
      reason: 'These images are in docs/redesign/renders/ but nothing here '
          'generates them any more, so nothing will ever update them:\n'
          '  ${orphans.join('\n  ')}\n'
          'Delete them, or restore the test that made them.',
    );
  });
}
