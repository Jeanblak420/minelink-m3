// The screens nothing had ever rendered.
//
// Measured 2026-08-20 by listing every screen `app_router.dart` builds and
// subtracting every screen name that appears anywhere under `test/`:
//
//     74 routed screens
//     22 of them not so much as NAMED in a test
//
// Among the 22: `LoginScreen` — the first screen every user of this product
// sees — plus `ProfileScreen`, `FleetManagementScreen`, `MessagesScreen`,
// `NotificationScreen`, and `EmployeeProfileScreen`, which is the second-most
// drifted file in `lib/features` (2,148 lines; 18 hand-named font families,
// 65 hand-written font sizes, 37 of them fractional and off-scale, 34 numeric
// corner radii).
//
// The existing sweeps are good and they cover the console and the portal. These
// screens are neither, so nothing reached them: auth, profile, chat, fleet,
// employee, operations, company. CLAUDE.md §10.5 asks for "screens proving
// something / N" rather than a passing-test count, and this file is what moves
// that numerator.
//
// It is deliberately the SAME sweep the portal uses — real fonts, the real
// theme, every width down to 360 and every text scale up to the ceiling the
// shells actually install — because the point is to hold these screens to the
// standard the rest are already held to, not to invent a gentler one for them.
//
// 🚨 A GREEN TICK HERE IS ONLY WORTH WHAT THE SCREEN ACTUALLY PAINTED.
//
// A screen that resolves to a spinner cannot overflow, so it would pass every
// width and every scale having laid out nothing. When this file was written
// that was true of EIGHT of its nineteen screens — four painted nothing at all,
// and `fleet_management` painted "Company information not available.", an error
// state.
//
// `test/fixtures/screen_fixtures.dart` now supplies the state each one gates
// on, and every screen here is swept with the same overrides its
// render-something check uses. `untested_screens_render_something_test.dart`
// measures what each paints and prints "PROVING SOMETHING: n / N" every run;
// it currently reads 18 / 18, and its baseline of excuses is EMPTY. Keep the
// two in step: a screen added here without a fixture will pass this sweep and
// fail that check, which is the right way round.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/layout/text_scale.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

import 'package:flutter_application_1/features/auth/screens/forgot_password_screen.dart';
import 'package:flutter_application_1/features/auth/screens/login_screen.dart';
import 'package:flutter_application_1/features/auth/screens/mandatory_password_change_screen.dart';
import 'package:flutter_application_1/features/chat/screens/communications_hub_screen.dart';
import 'package:flutter_application_1/features/chat/screens/messages_screen.dart';
import 'package:flutter_application_1/features/company/screens/company_employees_screen.dart';
import 'package:flutter_application_1/features/company/screens/employee_register_screen.dart';
import 'package:flutter_application_1/features/employee/screens/company_selection_screen.dart';
import 'package:flutter_application_1/features/employee/screens/employee_profile_screen.dart';
import 'package:flutter_application_1/features/fleet/screens/fleet_management_screen.dart';
import 'package:flutter_application_1/features/notifications/screens/notification_screen.dart';
import 'package:flutter_application_1/features/operations/screens/operations_hub_screen.dart';
import 'package:flutter_application_1/features/portal/screens/portal_tons_out_search_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_drivers_screen.dart';
import 'package:flutter_application_1/features/profile/screens/account_security_screen.dart';
import 'package:flutter_application_1/features/profile/screens/profile_screen.dart';
import 'package:flutter_application_1/features/profile_setup/screens/profile_setup_screen.dart';
import 'package:flutter_application_1/features/super_admin/screens/transporter_leaderboard_screen.dart';

import '../fixtures/screen_fixtures.dart';
import '../test_helpers/real_fonts.dart';

/// Down to 360 — the narrowest Android phone in common use, and the width
/// CLAUDE.md §10.4 keeps naming.
const _widths = <double>[1280, 860, 600, 412, 360];

/// Up to the ceiling the shells will actually install. Held to that by the
/// first test below, exactly as the console sweep holds its own list.
const _scales = <double>[1.0, 1.3, 2.0];

void main() {
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
    // These screens touch Supabase.instance while building. A dummy instance
    // gets them rendering; no request is ever made, so every provider resolves
    // to its empty or error state — which is the state most likely to overflow,
    // because an error message is longer than the figure it replaced.
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'untested-screens-sweep',
    );
  });

  Future<void> sweep(
    WidgetTester tester,
    Widget Function() child, {
    bool boldText = false,
    List<Override> overrides = const [],
  }) async {
    for (final width in _widths) {
      for (final scale in _scales) {
        tester.view.physicalSize = Size(width, 1600);
        tester.view.devicePixelRatio = 1.0;

        final captured = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = captured.add;

        await tester.pumpWidget(
          ProviderScope(
            overrides: overrides,
            child: MaterialApp(
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

        // Only layout faults are in scope. Re-pumping one tester across 15
        // corners provokes provider-disposal races that belong to the harness,
        // not the screen, and would make this sweep cry wolf.
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

  group('auth — the screens every user meets first', () {
    testWidgets('login', (t) => sweep(t, () => const LoginScreen()));
    testWidgets('forgot password',
        (t) => sweep(t, () => const ForgotPasswordScreen()));
    testWidgets('mandatory password change',
        (t) => sweep(t, () => const MandatoryPasswordChangeScreen()));
  });

  group('profile', () {
    testWidgets('profile', (t) => sweep(t, () => const ProfileScreen()));
    testWidgets(
        'account security',
        (t) => sweep(t, () => const AccountSecurityScreen(),
            overrides: [accountEmailOverride()]));
    testWidgets(
        'profile setup',
        (t) => sweep(t, () => const ProfileSetupScreen(),
            overrides: [profileSetupOverride()]));
  });

  group('employee & company', () {
    testWidgets('employee profile — managed', (t) {
      return sweep(
        t,
        () => const EmployeeProfileScreen(
          employeeId: 'sweep-employee',
          canManage: true,
          inPortal: true,
        ),
        overrides: companyScopeOverrides(),
      );
    });
    testWidgets('employee profile — read-only mirror', (t) {
      return sweep(
        t,
        () => const EmployeeProfileScreen(
          employeeId: 'sweep-employee',
          canManage: false,
          inPortal: false,
        ),
        overrides: companyScopeOverrides(canManageEmployees: false),
      );
    });
    testWidgets(
        'company employees',
        (t) => sweep(t, () => const CompanyEmployeesScreen(),
            overrides: companyScopeOverrides()));
    testWidgets(
        'employee register',
        (t) => sweep(t, () => const PortalEmployeeRegisterScreen(),
            overrides: companyScopeOverrides()));
    testWidgets('company selection',
        (t) => sweep(t, () => const CompanySelectionScreen()));
  });

  group('fleet & operations', () {
    testWidgets(
        'fleet management',
        (t) => sweep(t, () => const FleetManagementScreen(),
            overrides: companyScopeOverrides()));
    testWidgets(
        'operations hub',
        (t) => sweep(t, () => const OperationsHubScreen(),
            overrides: companyScopeOverrides()));
    testWidgets('transporter drivers',
        (t) => sweep(t, () => const TransporterDriversScreen()));
    testWidgets('tons-out search',
        (t) => sweep(t, () => const PortalTonsOutSearchScreen()));
  });

  group('chat & notifications', () {
    testWidgets('messages', (t) => sweep(t, () => const MessagesScreen()));
    testWidgets(
        'communications hub',
        (t) => sweep(t, () => const CommunicationsHubScreen(),
            overrides: companyScopeOverrides()));
    testWidgets('notifications',
        (t) => sweep(t, () => const NotificationScreen()));
  });

  // HomeTabBodyScreen is deliberately absent: it is a container that renders
  // `tabs[selected].screen` and adds no chrome, so sweeping it would sweep
  // whichever tab body it was handed. Those are real screens with their own
  // sweeps.
  group('leaderboard', () {
    testWidgets('transporter leaderboard',
        (t) => sweep(t, () => const TransporterLeaderboardScreen()));
  });
}
