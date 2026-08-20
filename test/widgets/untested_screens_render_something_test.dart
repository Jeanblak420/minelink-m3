// Does the sweep next door actually LAY ANYTHING OUT?
//
// CLAUDE.md §10.5: "A green test over an empty fixture, an error state, or a
// fallback font proves nothing. Report 'screens proving something / N', not
// the passing-test count — 28 green tests once covered 7 real screens."
//
// `untested_screens_sweep_test.dart` renders twenty screens with no Supabase
// data behind them. A screen that resolves to a centred spinner cannot
// overflow, so it would pass every width and every text scale while proving
// nothing at all. This file is the check on that claim: it measures what each
// screen actually painted and says so out loud.
//
// The bar is deliberately low and mechanical — a screen has to produce a real
// number of laid-out text runs and render taller than a spinner — because the
// point is to distinguish "laid out a screen" from "laid out a loading
// indicator", not to assert a design.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
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

/// A screen that paints fewer than this many text runs has not really
/// rendered — it is a spinner, an error line, or an empty state. Three is
/// below anything with a title and a sentence, and above a bare spinner.
const int _minTextRuns = 3;

/// Screens the sweep next door renders but **does not prove anything about**,
/// each with the reason it cannot.
///
/// These are not skipped and they are not quietly dropped from the sweep. They
/// are named here, with a cause, and the test below asserts this list is
/// EXACTLY right in both directions: a screen that starts rendering properly
/// fails until it is promoted out of this map, so the list can only shrink.
/// Same shape as `tool/migration_ledger_baseline.json` and for the same reason
/// — an accepted gap that is printed every run is a gap; an invisible one is a
/// false claim of coverage.
///
/// Fixing each means supplying the state it short-circuits on, which is real
/// per-screen work on the provider graph rather than one shared override. That
/// is the follow-up; pretending in the meantime is not.
/// **HomeTabBodyScreen is deliberately not in [_screens].** It is a container,
/// not a screen: it renders `tabs[selected].screen` inside a LazyIndexedStack
/// and adds no chrome of its own, so whatever it paints belongs to the tab body
/// it was handed. Measuring it would measure the fixture. The tab bodies are
/// real screens with their own sweeps, which is where that coverage lives.
const Map<String, String> _unproven = {
  'account security':
      'its fields are built from the signed-in session; with no session it '
      'paints one line.',
  'profile setup':
      'gated on a profile-setup state that is null without a signed-in user.',
  'employee register': 'same company gate as company employees.',
  'fleet management':
      'short-circuits to "Company information not available." — an ERROR '
      'state, which is exactly what CLAUDE.md §10.5 warns a green sweep over '
      'proves nothing about.',
  'operations hub':
      'needs an OperationsAccessPolicy resolved from a role; paints nothing '
      'without one.',
  'communications hub':
      'chat rooms come from a realtime subscription that never opens against '
      'the dummy Supabase instance.',
};

typedef Screens = Map<String, Widget Function()>;

/// Provider overrides a screen needs before it will lay anything out.
/// See `test/fixtures/screen_fixtures.dart` for what each supplies and why.
///
/// `company employees` renders its **restricted** branch here — a real
/// user-facing state, and the one reachable without faking `companyProvider`,
/// whose notifier takes four services and opens two realtime channels. The
/// managing branch is still uncovered; that is a fixture worth building, not a
/// reason to leave the screen rendering a spinner.
final Map<String, List<Override>> _fixtures = {
  'company employees': [companyAccessOverride()],
};

final Screens _screens = {
  'login': () => const LoginScreen(),
  'forgot password': () => const ForgotPasswordScreen(),
  'mandatory password change': () => const MandatoryPasswordChangeScreen(),
  'profile': () => const ProfileScreen(),
  'account security': () => const AccountSecurityScreen(),
  'profile setup': () => const ProfileSetupScreen(),
  'employee profile': () => const EmployeeProfileScreen(
        employeeId: 'sweep-employee',
        canManage: true,
        inPortal: true,
      ),
  'company employees': () => const CompanyEmployeesScreen(),
  'employee register': () => const PortalEmployeeRegisterScreen(),
  'company selection': () => const CompanySelectionScreen(),
  'fleet management': () => const FleetManagementScreen(),
  'operations hub': () => const OperationsHubScreen(),
  'transporter drivers': () => const TransporterDriversScreen(),
  'tons-out search': () => const PortalTonsOutSearchScreen(),
  'messages': () => const MessagesScreen(),
  'communications hub': () => const CommunicationsHubScreen(),
  'notifications': () => const NotificationScreen(),
  'transporter leaderboard': () => const TransporterLeaderboardScreen(),
};

void main() {
  setUpAll(() async {
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'render-something-check',
    );
  });

  /// What the sweep next door is actually proving, screen by screen.
  final report = <String, int>{};
  final spinners = <String>[];

  for (final entry in _screens.entries) {
    testWidgets('${entry.key} lays out real content', (tester) async {
      tester.view.physicalSize = const Size(1280, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final prior = FlutterError.onError;
      FlutterError.onError = (_) {}; // layout faults are the other file's job
      addTearDown(() => FlutterError.onError = prior);

      await tester.pumpWidget(ProviderScope(
        overrides: _fixtures[entry.key] ?? const [],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (context) => Scaffold(
              backgroundColor: MlSemantic.of(context).surfaceApp,
              body: entry.value(),
            ),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 400));
      FlutterError.onError = prior;

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .where((t) => (t.data ?? '').trim().isNotEmpty)
          .length;
      final spinning =
          find.byType(CircularProgressIndicator).evaluate().isNotEmpty;

      report[entry.key] = texts;
      if (texts < _minTextRuns) spinners.add(entry.key);

      final known = _unproven[entry.key];
      if (known == null) {
        expect(
          texts,
          greaterThanOrEqualTo(_minTextRuns),
          reason: 'Only $texts text run(s) painted'
              '${spinning ? ' (a CircularProgressIndicator is on screen)' : ''}'
              '. The overflow sweep passes this screen at every width and text '
              'scale, but it is not laying out enough to prove anything. Give '
              'it a fixture, or add it to _unproven with a reason — do not '
              'leave the sweep claiming coverage it does not have.',
        );
      } else {
        // The baseline can only shrink. A screen that starts rendering has to
        // be promoted, or this entry goes on excusing a screen that no longer
        // needs excusing — which is how a baseline becomes a blindfold.
        expect(
          texts,
          lessThan(_minTextRuns),
          reason: 'This screen is listed in _unproven ("$known") but it now '
              'paints $texts text runs. It renders — promote it: delete that '
              'entry, and the sweep next door starts meaning something here.',
        );
      }
    });
  }

  tearDownAll(() {
    final sorted = report.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    // ignore: avoid_print
    print('\n── text runs painted, per screen '
        '(the sweep next door is only as good as these) ──');
    for (final e in sorted) {
      // ignore: avoid_print
      print('  ${e.value.toString().padLeft(4)}  ${e.key}');
    }
    final proven = report.length - spinners.length;
    // ignore: avoid_print
    print('\n  PROVING SOMETHING: $proven / ${report.length} screens');
    if (spinners.isNotEmpty) {
      // ignore: avoid_print
      print('  UNPROVEN (each with a reason in _unproven): '
          '${spinners.join(', ')}');
    }
  });
}
