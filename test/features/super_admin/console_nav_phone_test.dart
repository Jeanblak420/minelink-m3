// The admin menu on a phone (admin phone audit, 2026-10-24). It differs from
// the desktop rail only where the audit asked; the desktop rail is unchanged.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';

List<String> _labels(List<MlNavNode> tree) =>
    [for (final n in tree) ...n.leaves.map((l) => l.label)];

void main() {
  test('Platform settings is not on the phone menu (nothing to set)', () {
    expect(_labels(consoleNavTree(phone: true)), isNot(contains('Platform settings')));
  });

  test('the desktop rail still lists it, and its route still resolves', () {
    expect(_labels(consoleNavTree()), contains('Platform settings'));
    final router = File('lib/core/routing/app_router.dart').readAsStringSync();
    expect(router, contains("'/super-admin/settings'"));
  });

  test('Platform users is on the phone menu, under Tokens & Seats', () {
    final access = consoleNavTree(phone: true)
        .firstWhere((n) => n.label == 'Tokens & Seats');
    final users = access.leaves.where((l) => l.label == 'Platform users');
    expect(users, hasLength(1));
    expect(users.single.route, '/super-admin/users');
    expect(consoleNavTree(phone: true).resolveSelected('/super-admin/users'),
        '/super-admin/users',
        reason: 'the bottom bar would light Dashboard on that page');
    final router = File('lib/core/routing/app_router.dart').readAsStringSync();
    expect(router, contains("'/super-admin/users'"));
  });

  test('the desktop rail is unchanged by it', () {
    expect(_labels(consoleNavTree()), isNot(contains('Platform users')));
  });
}
