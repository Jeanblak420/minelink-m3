// The admin menu on a phone (admin phone audit, 2026-10-24) and, from Jean's
// go-ahead the same day, the desktop rail too.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';

List<String> _labels(List<MlNavNode> tree) =>
    [for (final n in tree) ...n.leaves.map((l) => l.label)];

void main() {
  final router = File('lib/core/routing/app_router.dart').readAsStringSync();

  test('Platform settings is on neither menu (nothing to set)', () {
    expect(_labels(consoleNavTree(phone: true)), isNot(contains('Platform settings')));
    expect(_labels(consoleNavTree()), isNot(contains('Platform settings')));
  });

  test('its route still resolves, so an old link still opens', () {
    expect(router, contains("'/super-admin/settings'"));
  });

  for (final phone in [true, false]) {
    final where = phone ? 'phone' : 'desktop';

    test('$where: Platform users is under Tokens & Seats', () {
      final access = consoleNavTree(phone: phone)
          .firstWhere((n) => n.label == 'Tokens & Seats');
      final users = access.leaves.where((l) => l.label == 'Platform users');
      expect(users, hasLength(1));
      expect(users.single.route, '/super-admin/users');
      expect(consoleNavTree(phone: phone).resolveSelected('/super-admin/users'),
          '/super-admin/users',
          reason: 'the menu would light Dashboard on that page');
    });

    test('$where: Navigation setup is under Tracking', () {
      final tracking = consoleNavTree(phone: phone)
          .firstWhere((n) => n.label == 'Tracking');
      final guide = tracking.leaves.where((l) => l.label == 'Navigation setup');
      expect(guide, hasLength(1));
      expect(guide.single.route, '/super-admin/navigation-setup');
      expect(
          consoleNavTree(phone: phone)
              .resolveSelected('/super-admin/navigation-setup'),
          '/super-admin/navigation-setup');
    });
  }

  test('both new destinations are served by the router', () {
    expect(router, contains("'/super-admin/users'"));
    expect(router, contains("'/super-admin/navigation-setup'"));
  });
}
