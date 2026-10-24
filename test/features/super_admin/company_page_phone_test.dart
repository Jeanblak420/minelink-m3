// The company page and the user lists on a phone (admin phone audit,
// 2026-10-24): the bottom bar lit Dashboard while you were in Access, and
// WhatsApp users were listed by the internal login address.
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
  group('on a phone the bottom bar lights the section you are in', () {
    final tree = consoleNavTree();
    String? lit(String location) =>
        tree.resolveSelected(superAdminPhoneNavSection(location));

    test('a company page is in Access (Organizations), not Dashboard', () {
      expect(tree.resolveSelected('/super-admin/organization/abc'), '/super-admin',
          reason: 'without the mapping it falls to Dashboard \u2014 the bug');
      expect(lit('/super-admin/organization/abc'), '/super-admin/organizations');
    });

    test('the other pages that fell to Dashboard', () {
      expect(lit('/super-admin/register-company'), '/super-admin/organizations');
      expect(lit('/super-admin/seat-requests'), '/super-admin/token-requests');
      expect(lit('/super-admin/requests/buyer-transport'),
          '/super-admin/requests/transportation-mine');
      expect(lit('/super-admin/tons-out'), '/super-admin/recon-tables');
    });

    test('pages that already resolved are left alone', () {
      expect(lit('/super-admin'), '/super-admin');
      expect(lit('/super-admin/organizations'), '/super-admin/organizations');
      expect(lit('/super-admin/recon-tables'), '/super-admin/recon-tables');
    });
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
