// The employee grid's page head, in the product's own vocabulary.
//
// Phase 3 mine-portal pass, 2026-08-23 (reviewer finding #40). The title was
// `'$companyName Employees'` — the shipping app's `AppBar` title carried
// across into an `MlPageHeader` unchanged — so it read "Fixture Haulage
// Employees" while every other header in the product is sentence case, the
// register next door reads "Employee register" and the screen one route over
// reads "Company employees".
//
// And it carried NO meta line, which `docs/design-reference.md` §5.4 asks of
// every header. The roster was already being fetched — `getByCompanyId`
// selects a company's whole roster whatever page is asked for — so the count
// costs nothing but was simply never shown.
//
// The count is only honest because of the commit before this one: the
// repository used to cache the twenty-row PAGE under the company's key, so a
// header counting that roster would have said "20 people" about a company of
// two hundred. See `employee_roster_paging_test.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/mcp/models/employee_model.dart';
import 'package:flutter_application_1/core/mcp/repository_providers.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/employee/screens/employee_grid_screen.dart';

import '../../fixtures/portal_tail_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'employee-grid-head-test',
    );
  });

  Future<void> pump(WidgetTester tester, List<EmployeeMCP> roster) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          employeeRepositoryProvider.overrideWithValue(
            FixtureEmployeeRepository(roster),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: EmployeeGridScreen(
              companyId: 'co-transporter',
              companyName: 'Fixture Haulage',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the title is sentence case, not the AppBar title', (
    tester,
  ) async {
    await pump(tester, kCompanyRoster);

    expect(find.text('Fixture Haulage employees'), findsOneWidget);
    expect(
      find.text('Fixture Haulage Employees'),
      findsNothing,
      reason:
          'the company is a proper noun; "employees" is not. Every other '
          'header in the product is sentence case',
    );
  });

  testWidgets('the head counts the people it draws', (tester) async {
    await pump(tester, kCompanyRoster);

    final drawn = kCompanyRoster
        .where((e) => e.companyId == null || e.companyId == 'co-transporter')
        .length;
    expect(
      drawn,
      greaterThan(1),
      reason: 'a one-person fixture cannot tell a count from a singular',
    );
    expect(
      find.text('$drawn people'),
      findsOneWidget,
      reason:
          '§5.4 — every header carries a meta line, and it counts the thing '
          'the page actually shows',
    );
  });

  testWidgets('one person is "1 person", not "1 people"', (tester) async {
    await pump(tester, [kCompanyRoster.first]);
    expect(find.text('1 person'), findsOneWidget);
    expect(find.text('1 people'), findsNothing);
  });

  // The GREEN case: the description is the screen's own sentence and this pass
  // did not touch it. If a later edit rewrites the header wholesale, this says
  // so rather than letting the sentence quietly disappear.
  testWidgets('the description still says who is on the page', (tester) async {
    await pump(tester, kCompanyRoster);
    expect(find.text('Everyone registered under this company.'), findsOneWidget);
  });
}
