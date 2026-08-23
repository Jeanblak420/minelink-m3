// The employees register shows everyone it counts, and reads in sentence case.
//
// Phase 3 mine-portal pass, 2026-08-23 (found independently by three
// reviewers). The role groups iterate `UserRole.getRolesForOrgType`, and the
// "Other" group caught only `role == null`, so an ACTIVE employee whose role
// is not one this org type has — the fixture's weighbridge controller at a
// transporter — was counted in "3 PEOPLE · 3 ACTIVE" and drawn in no group.
// A register that silently drops a person is the worst thing a register can
// do; "an unusual state" is what Other is for. And twelve labels were title
// case ("Company Employees", "Add User", "Manage User And Role" …).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/screens/company_employees_screen.dart';

import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'company-employees-register-test',
    );
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: companyScopeOverrides(
          role: UserRole.admin, orgType: OrgType.transporter),
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: CompanyEmployeesScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('every counted employee is drawn — an off-org role lands in Other',
      (tester) async {
    await pump(tester);
    final roster = fixtureRoster();
    final offOrg = roster.where((e) =>
        e.role != null &&
        !UserRole.getRolesForOrgType(OrgType.transporter).contains(e.role));
    expect(offOrg, isNotEmpty,
        reason: 'the fixture must carry an off-org role for this to bite');
    expect(find.text('${roster.length} PEOPLE'), findsOneWidget);
    for (final e in roster) {
      expect(find.textContaining(e.lastName), findsWidgets,
          reason: '${e.firstName} ${e.lastName} is counted but not drawn');
    }
  });

  testWidgets('labels are sentence case', (tester) async {
    await pump(tester);
    expect(find.text('Company employees'), findsOneWidget);
    expect(find.text('Add user'), findsWidgets);
    for (final stale in const ['Company Employees', 'Add User']) {
      expect(find.text(stale), findsNothing, reason: '"$stale" is back');
    }
  });
}
