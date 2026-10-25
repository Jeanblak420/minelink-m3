// Each page is headed with the name the menu gave it (Jean, 2026-10-25:
// "rename the page to match the menu"). Walked as a mine admin on the
// S25-matched emulator, five pages opened under a different name from the
// entry tapped: Stockpiles → "Supervisor", Security gate → "Mine Security",
// Load controller → "Mine Control", Communications → "Communications Hub",
// Employees → "Company employees". My profile read "Profile".
//
// Read as source: each screen pulls in a session's worth of providers, and
// the claim is a pairing of two strings — the menu's label (read from the
// real nav tree, not retyped) and the heading the screen draws.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';

void main() {
  final cases = <(String route, String file)>[
    ('/portal/mine/stockpiles',
        'lib/features/portal/screens/supervisor_view_screen.dart'),
    ('/portal/mine/security',
        'lib/features/portal/screens/security_checkin_screen.dart'),
    ('/portal/mine/weighbridge',
        'lib/features/portal/screens/load_controller_screen.dart'),
    ('/communications',
        'lib/features/chat/screens/communications_hub_screen.dart'),
    ('/portal/mine/employees',
        'lib/features/company/screens/company_employees_screen.dart'),
    ('/portal/mine/profile', 'lib/features/profile/screens/profile_screen.dart'),
  ];
  final tree = portalNavTree(orgType: OrgType.mineSupplier, role: null);

  for (final (route, file) in cases) {
    test('$route is headed as the menu names it', () {
      final label = portalNavLabelFor(tree, route);
      expect(label, isNotNull, reason: '$route is no longer in the menu');
      final src = File(file).readAsStringSync();
      final heading = RegExp(r"MlPageHeader\(\s*title: '([^']*)'")
          .firstMatch(src)
          ?.group(1);
      expect(heading, label,
          reason: '$file heads its page "$heading"; the menu says "$label"');
    });
  }
}
