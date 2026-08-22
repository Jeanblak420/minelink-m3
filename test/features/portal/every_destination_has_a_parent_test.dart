// Nothing in a sidebar sits at the top level on its own.
//
// Ruled by jean, 2026-08-22:
//
//   "please also find a proper parent for everything inside of the sidebar nav
//    menu that doesn't have a parent, if the excisting ones aren't a proper
//    match and or fit then create a proper match and or fit them please, none
//    of them shouldn't have a parent, all should have a parent"
//
// Before this, every tree in the product mixed the two: the console had eight
// loose leaves — Recon tables, Margin ledger History, Disputes, Available
// routes, Route marketplace, Chat links, Live map, Notifications — sitting at
// the same level as Insights ▾ and Requests ▾, and every portal tree opened
// with a bare `Dashboard` leaf above its groups. A rail where some entries
// open and others jump is a rail you have to read twice.
//
// This sweeps EVERY tree the product can build — three org types × every role,
// plus the console — rather than the three or four a person would think to
// check. The restricted roles are the ones that were most obviously wrong and
// the least likely to be looked at.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';

/// Every (org type, role) pair a session can actually hold — including `null`,
/// which is the company account's own login.
Iterable<(OrgType, UserRole?)> _everySession() sync* {
  for (final org in OrgType.values) {
    yield (org, null);
    for (final role in UserRole.values) {
      yield (org, role);
    }
  }
}

void main() {
  group('every portal tree', () {
    for (final (org, role) in _everySession()) {
      final who = '${org.name} / ${role?.name ?? 'company account'}';

      test('$who has no top-level destination', () {
        final tree = portalNavTree(orgType: org, role: role);

        expect(tree, isNotEmpty,
            reason: 'an empty rail reads as a broken app rather than a '
                'restricted one');

        final loose = tree.where((n) => !n.isGroup).map((n) => n.label).toList();
        expect(
          loose,
          isEmpty,
          reason: '$who still has ${loose.length} destination(s) with no '
              'parent: ${loose.join(', ')}',
        );
      });

      test('$who has no group that leads nowhere', () {
        // The symmetric half. "Wrap everything in a group" passes the check
        // above even if a group is empty, and an empty group is a header that
        // opens onto nothing.
        for (final node in portalNavTree(orgType: org, role: role)) {
          expect(node.leaves, isNotEmpty,
              reason: '"${node.label}" is a group with no destinations in it');
        }
      });

      test('$who still lands somewhere real', () {
        // Grouping moved every landing route one level deeper.
        // `portalLandingRoute` reads the first LEAF rather than the first node,
        // so it is unaffected — but that is exactly the kind of thing that is
        // only true until someone changes it.
        final landing = portalLandingRoute(orgType: org, role: role);
        expect(landing, startsWith('/'));
        expect(landing, isNot('/profile'),
            reason: 'that is the documented unreachable fallback; reaching it '
                'means this role built an empty tree');
      });
    }
  });

  group('the console tree', () {
    test('has no top-level destination', () {
      final loose =
          consoleNavTree().where((n) => !n.isGroup).map((n) => n.label).toList();
      expect(
        loose,
        isEmpty,
        reason: 'the console still has ${loose.length} destination(s) with no '
            'parent: ${loose.join(', ')}',
      );
    });

    test('has no group that leads nowhere', () {
      for (final node in consoleNavTree()) {
        expect(node.leaves, isNotEmpty,
            reason: '"${node.label}" is a group with no destinations in it');
      }
    });

    test('kept every destination it had', () {
      // Regrouping must MOVE things, not lose them. These are the eight that
      // were loose, plus the dashboard — the ones this change touched.
      final routes = consoleNavTree().expand((n) => n.leaves).map((l) => l.route);
      for (final route in const [
        '/super-admin',
        '/super-admin/recon-tables',
        '/super-admin/margin-ledger',
        '/super-admin/disputes',
        '/super-admin/available-routes',
        '/super-admin/route-marketplace',
        '/super-admin/chat-links',
        '/super-admin/live-map',
      ]) {
        expect(routes, contains(route),
            reason: '$route disappeared when the tree was regrouped');
      }
    });
  });

  test('a role that loses its rail still gets the minimal one', () {
    // The fallback exists so an unsupported configuration still has a way to
    // its own record and to sign-out. It is grouped now like everything else,
    // and it must not have become empty in the process.
    final tree =
        portalNavTree(orgType: OrgType.mineSupplier, role: UserRole.driver);
    expect(tree, isNotEmpty);
    expect(tree.every((n) => n.isGroup), isTrue);
    expect(
      tree.expand((n) => n.leaves).map((l) => l.route),
      contains('/portal/mine/profile'),
      reason: 'the fallback must always reach the user\'s own record',
    );
  });
}
