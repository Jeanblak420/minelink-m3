import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/nav/ml_nav_node.dart';
import 'package:flutter_application_1/core/routing/app_router.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav_ids.dart';

/// Replaces `console_sidebar_nav_map_test.dart`.
///
/// That file tested three interchangeable sidebar skins — their palettes, their
/// widths, which layout family each belonged to, whether a skin id round-tripped
/// through stored preferences. The M3 redesign collapsed the five rails into
/// one, so those assertions describe nothing that exists.
///
/// What it *also* tested, and what is kept here verbatim in substance, is the
/// part that was never about skins: that no navigation entry can dead-end, and
/// that the request inbox only ever points at a queue the router will serve.
void main() {
  group('the console navigation tree', () {
    test('every leaf carries a route, and no group pretends to be one', () {
      for (final node in consoleNavTree()) {
        if (node.isGroup) {
          expect(node.route, isNull, reason: '${node.label} is a group');
          expect(node.children, isNotEmpty);
          for (final child in node.children) {
            expect(child.route, isNotNull, reason: child.label);
            expect(child.isGroup, isFalse,
                reason: '${child.label}: the rail renders two levels, not three');
          }
        } else {
          expect(node.route, isNotNull, reason: node.label);
        }
      }
    });

    test('no destination appears twice', () {
      final routes = consoleNavTree().allLeaves.map((l) => l.route).toList();
      expect(
        routes.length,
        routes.toSet().length,
        reason: 'duplicate destinations: '
            '${routes.where((r) => routes.where((x) => x == r).length > 1).toSet()}',
      );
    });

    test('every destination the console can REACH is in the rail', () {
      // The test that would have caught the Targets gap.
      //
      // `/super-admin/targets` is a registered route with a built screen, and
      // `consoleNavRoutes` has mapped it all along — but the default sidebar
      // never listed it, so an admin who had not switched skins could not
      // navigate there at all. Thirty destinations written out twice by hand
      // hid a missing one.
      //
      // Anything genuinely reachable only from inside another screen belongs in
      // the exemption list below, WITH a reason. An empty reason is not an
      // exemption, it is an omission with a comment on it.
      const notInRail = <String, String>{
        '/super-admin/targets/org-type':
            'a tab within Targets, opened from the platform targets screen',
        '/super-admin/targets/company':
            'a tab within Targets, opened by picking a company',
        '/super-admin/users':
            'reached from the Organizations screen, scoped to one org',
        '/super-admin/register-company':
            'an action started from Organizations, not a standing destination',
      };

      final inRail = consoleNavTree().allLeaves.map((l) => l.route).toSet();
      final missing = consoleNavRoutes.values
          .where((route) => !inRail.contains(route))
          .where((route) => !notInRail.containsKey(route))
          .toSet();

      expect(
        missing,
        isEmpty,
        reason: 'Destinations the console maps but the rail does not offer: '
            '$missing. Either add them to consoleNavTree, or list them in '
            'notInRail with the reason they are reached another way.',
      );
    });

    test('search finds a nested destination without its group being open', () {
      // The flat list this replaced could only match top-level labels, so
      // typing "crash" found nothing even though Crash reports exists.
      final hits = consoleNavTree().filtered('crash');
      expect(hits, isNotEmpty);
      expect(
        hits.allLeaves.map((l) => l.label),
        contains('Crash reports'),
      );
    });

    test('a group is considered to hold the current route', () {
      final insights = consoleNavTree()
          .firstWhere((n) => n.label == 'Insights');
      expect(insights.contains('/super-admin/insights/buyer'), isTrue);
      expect(insights.contains('/super-admin/disputes'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Kept from the file this replaces. Nothing here was ever about skins.
  // ---------------------------------------------------------------------------

  // Found by mistyping a request-inbox URL during the 2026-08-17 walk.
  //
  // `/super-admin/requests/:type` matches ANY string, so
  // `/super-admin/requests/buyer-requests` rendered the review screen's generic
  // fallback — "Queue is clear, no requests in this queue yet" — under an app
  // bar reading "Requested buyers", while two buyer requests sat waiting. A
  // review queue that reports itself empty when it is not is the worst way for
  // a link to fail: the admin closes the tab.
  group('the request inbox only serves queues that exist', () {
    test('every real queue stays put', () {
      for (final t in kSuperAdminRequestQueues) {
        expect(superAdminRequestsRedirect(t), isNull, reason: t);
      }
    });

    test('an unknown queue goes to the canonical inbox, not to an empty one',
        () {
      for (final t in ['buyer-requests', 'products', '', 'BUYER', 'nonsense']) {
        expect(superAdminRequestsRedirect(t),
            '/super-admin/requests/transportation',
            reason: 'type "$t"');
      }
      expect(superAdminRequestsRedirect(null),
          '/super-admin/requests/transportation');
    });

    test('the ML deep-link aliases keep their own destinations', () {
      expect(superAdminRequestsRedirect('mine-transport'),
          '/super-admin/requests/transportation-mine');
      expect(superAdminRequestsRedirect('buyer-transport'),
          '/super-admin/requests/transportation-buyer');
    });

    test('every rail destination under /requests/ is a queue that exists', () {
      const prefix = '/super-admin/requests/';
      for (final leaf in consoleNavTree().allLeaves) {
        final route = leaf.route!;
        if (!route.startsWith(prefix)) continue;
        final type = route.substring(prefix.length);
        expect(superAdminRequestsRedirect(type), isNull,
            reason: '"${leaf.label}" points at "$route", which the router will '
                'bounce — add "$type" to kSuperAdminRequestQueues or fix the '
                'destination');
      }
    });

    test('and so is every id the dashboard tiles can emit', () {
      const prefix = '/super-admin/requests/';
      for (final entry in consoleNavRoutes.entries) {
        final route = entry.value;
        if (!route.startsWith(prefix)) continue;
        final type = route.substring(prefix.length);
        expect(superAdminRequestsRedirect(type), isNull,
            reason: '${entry.key} points at "$route", which the router will '
                'bounce');
      }
    });
  });
}
