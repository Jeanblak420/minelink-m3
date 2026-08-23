// Nothing in a sidebar sits at the top level on its own, except the Dashboard.
//
// Ruled by jean, 2026-08-22:
//
//   "please also find a proper parent for everything inside of the sidebar nav
//    menu that doesn't have a parent, if the excisting ones aren't a proper
//    match and or fit then create a proper match and or fit them please, none
//    of them shouldn't have a parent, all should have a parent"
//
// Before this, every tree in the product mixed the two: the console had eight
// loose leaves — Recon tables, Margin ledger history, Disputes, Available
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

      test('$who has no top-level destination but the Dashboard', () {
        final tree = portalNavTree(orgType: org, role: role);

        expect(tree, isNotEmpty,
            reason: 'an empty rail reads as a broken app rather than a '
                'restricted one');

        final loose = tree.where((n) => !n.isGroup).toList();
        expect(
          loose.map((n) => n.label).where((l) => l != 'Dashboard'),
          isEmpty,
          reason: '$who has a destination with no parent that is not the '
              'Dashboard: ${loose.map((n) => n.label).join(', ')}',
        );
        expect(
          loose.length,
          lessThanOrEqualTo(1),
          reason: 'only ONE top-level destination is allowed, and it is the '
              'Dashboard',
        );
        // And when it is there it is FIRST, above the groups -- which is what
        // the original app's sidebar does and what jean asked for on
        // 2026-08-22. A Dashboard in the middle of the groups is not the
        // exception; it is a different bug.
        if (loose.isNotEmpty) {
          expect(tree.first.isGroup, isFalse,
              reason: 'the Dashboard must be the FIRST entry, not buried '
                  'between groups');
          expect(tree.first.label, 'Dashboard');
        }
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
    test('has no top-level destination but the Dashboard, and it is first', () {
      final loose = consoleNavTree().where((n) => !n.isGroup).toList();
      expect(
        loose.map((n) => n.label).where((l) => l != 'Dashboard'),
        isEmpty,
        reason: 'the console has a destination with no parent that is not the '
            'Dashboard: ${loose.map((n) => n.label).join(', ')}',
      );
      expect(loose.length, 1);
      expect(consoleNavTree().first.label, 'Dashboard');
    });

    test('is in the ORIGINAL sidebar order', () {
      // Read out of the untouchable worktree on 2026-08-22, from
      // lib/features/super_admin/widgets/sidebar/minelink_sidebar_core.dart:
      // its "dashboard" section alone, then "main" = Insights, Tokens &
      // Seats, Requests,
      // then the flat block Margin ledger history / Recon tables / Disputes /
      // Available routes / Route marketplace / Chat links / Live map, then the
      // footer's Notifications and Settings.
      //
      // jean asked for that order back across the whole app while keeping the
      // M3 look and the new groups. This is the half a picture cannot check.
      expect(
        consoleNavTree().map((n) => n.label).toList(),
        const [
          'Dashboard',
          'Insights',
          'Tokens & Seats',
          'Requests',
          'Reconciliation',
          'Routes',
          'Communications',
          'Tracking',
          'Settings',
        ],
      );
      // The flat block's own sequence survives inside its group.
      final recon =
          consoleNavTree().firstWhere((n) => n.label == 'Reconciliation');
      expect(
        recon.leaves.map((l) => l.label).toList(),
        const ['Margin ledger history', 'Recon tables', 'Disputes'],
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
    // Dashboard first, then groups — the shape the whole product uses.
    expect(tree.first.label, 'Dashboard');
    expect(tree.first.isGroup, isFalse);
    expect(tree.skip(1).every((n) => n.isGroup), isTrue);
    expect(
      tree.expand((n) => n.leaves).map((l) => l.route),
      contains('/portal/mine/profile'),
      reason: 'the fallback must always reach the user\'s own record',
    );
  });
}
