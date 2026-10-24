// The company page and the user lists on a phone (admin phone audit,
// 2026-10-24): the bottom bar lit Dashboard while you were in Access, and
// WhatsApp users were listed by the internal login address.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/screens/platform_users_screen.dart';
import 'package:flutter_application_1/features/super_admin/widgets/super_admin_shell_layout.dart';

void main() {
  // Phone first (admin phone audit), then the desktop rail on Jean's go-ahead
  // (2026-10-24). On desktop it is one ITEM lit, not one tab, so a page that
  // already has its own entry must keep it.
  for (final phone in [true, false]) {
    group('${phone ? 'phone' : 'desktop'}: the menu lights the page you are on',
        () {
      final tree = consoleNavTree(phone: phone);
      String? lit(String location) =>
          tree.resolveSelected(superAdminNavSection(location, tree));

      test('a company page is in Organizations, not Dashboard', () {
        expect(tree.resolveSelected('/super-admin/organization/abc'),
            '/super-admin',
            reason: 'without the mapping it falls to Dashboard \u2014 the bug');
        expect(lit('/super-admin/organization/abc'), '/super-admin/organizations');
      });

      test('the other pages that fell to Dashboard', () {
        expect(lit('/super-admin/register-company'), '/super-admin/organizations');
        expect(lit('/super-admin/seat-requests'), '/super-admin/token-requests');
        expect(lit('/super-admin/tons-out'), '/super-admin/recon-tables');
        expect(lit('/super-admin/requests/buyer-transport'),
            '/super-admin/requests/transportation-buyer');
        expect(lit('/super-admin/requests/mine-transport'),
            '/super-admin/requests/transportation-mine');
      });

      test('a page that is off the menu lights nothing, not Dashboard', () {
        expect(lit('/super-admin/settings'), isNull);
      });

      test('pages with their own entry keep it', () {
        expect(lit('/super-admin'), '/super-admin');
        expect(lit('/super-admin/organizations'), '/super-admin/organizations');
        expect(lit('/super-admin/recon-tables'), '/super-admin/recon-tables');
        expect(lit('/super-admin/requests/transportation-buyer'),
            '/super-admin/requests/transportation-buyer',
            reason: 'a blanket requests/ mapping would light the mine inbox');
        expect(lit('/super-admin/requests/product'), '/super-admin/requests/product');
        expect(lit('/super-admin/insights/buyer/company/x'),
            '/super-admin/insights/buyer');
      });
    });
  }

  test('every page the router serves lights something other than Dashboard',
      () {
    // The sweep that should have been here from the start: every console
    // path the router registers, with each `:param` filled in.
    final router = File('lib/core/routing/app_router.dart').readAsStringSync();
    final paths = RegExp(r"path: '(/super-admin[^']*)'")
        .allMatches(router)
        .map((m) => m.group(1)!.replaceAll(RegExp(r':\w+'), 'transporter'))
        .toSet();
    const dashboardOnly = {'/super-admin', '/super-admin/dashboard-v2'};
    const offMenu = {'/super-admin/settings'};
    final tree = consoleNavTree();
    final wrong = [
      for (final p in paths)
        if (!dashboardOnly.contains(p) && !offMenu.contains(p))
          if (tree.resolveSelected(superAdminNavSection(p, tree)) ==
              '/super-admin')
            p,
    ];
    expect(wrong, isEmpty, reason: 'these light Dashboard: $wrong');
  });

  testWidgets('Platform users: a WhatsApp user is shown by number', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        allPlatformUsersProvider.overrideWith((ref) async => [
              {
                'first_name': 'Eli',
                'last_name': 'Mans',
                'role': 'driver',
                'company_id': 'c1',
                'company_name': 'AB trans',
                'whatsapp_number': '0833067846',
                'profiles': {'email': 'wa-0833067846@wa.mineralguide.com'},
              },
              {
                'first_name': 'Thandi',
                'last_name': 'Mokoena',
                'role': 'admin',
                'company_id': 'c1',
                'company_name': 'AB trans',
                'profiles': {'email': 'thandi@example.com'},
              },
            ]),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(body: PlatformUsersScreen()),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('wa.mineralguide.com'), findsNothing);
    expect(find.textContaining('WhatsApp 0833067846'), findsOneWidget);
    expect(find.textContaining('thandi@example.com'), findsOneWidget);
  });
}
