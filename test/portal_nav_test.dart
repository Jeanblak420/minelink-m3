// Pins the portal navigation trees (P7-01 … P7-17).
//
// The tree is pure data, so it can be checked as a value rather than by
// driving a rail. The load-bearing test is `every leaf route resolves`: it
// reads the *real* route table out of `app_router.dart` and asserts every
// destination the rail can reach is one the router declares. A typo in a path
// string is otherwise invisible until someone clicks the entry and lands on
// the 404 screen — which is precisely how 55 `/portal/*` routes came to exist
// with nothing pointing at them.
//
// It reads the router as source rather than building a `GoRouter`, because
// `AppRouter` initialises from `SupabaseConfig.client` in a static field and
// cannot be constructed without a live Supabase handle. A string check over
// the route table is enough for what is being asserted here: that the two
// files agree on the set of paths.

import 'dart:io';

import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every (org type, role) pair the portal can legitimately produce, plus the
/// company account (null role) for each org type.
const _cases = <({OrgType orgType, UserRole? role})>[
  (orgType: OrgType.mineSupplier, role: null),
  (orgType: OrgType.mineSupplier, role: UserRole.admin),
  (orgType: OrgType.mineSupplier, role: UserRole.management),
  (orgType: OrgType.mineSupplier, role: UserRole.supervisorForeman),
  (orgType: OrgType.mineSupplier, role: UserRole.controllerWB),
  (orgType: OrgType.mineSupplier, role: UserRole.security),
  (orgType: OrgType.buyer, role: null),
  (orgType: OrgType.buyer, role: UserRole.admin),
  (orgType: OrgType.buyer, role: UserRole.management),
  (orgType: OrgType.transporter, role: null),
  (orgType: OrgType.transporter, role: UserRole.admin),
  (orgType: OrgType.transporter, role: UserRole.management),
  (orgType: OrgType.transporter, role: UserRole.driver),
];

String _name(({OrgType orgType, UserRole? role}) c) =>
    '${c.orgType.name} / ${c.role?.name ?? 'company account'}';

/// Path literals declared by `GoRoute`s in the router, e.g. `/portal/mine`.
Set<String> _declaredRoutes() {
  final source = File('lib/core/routing/app_router.dart').readAsStringSync();
  final matches = RegExp(r"path: '([^']+)'").allMatches(source);
  final paths = matches.map((m) => m.group(1)!).toSet();
  // Guard the guard: if the regex ever stops matching, every assertion below
  // would pass vacuously against an empty set.
  expect(paths.length, greaterThan(100),
      reason: 'route table looks unparsed — check the `path:` literal format');
  return paths;
}

void main() {
  group('portal nav trees', () {
    late Set<String> declared;

    setUpAll(() => declared = _declaredRoutes());

    test('every leaf route resolves against app_router.dart', () {
      final missing = <String>{};
      for (final c in _cases) {
        for (final leaf
            in portalNavTree(orgType: c.orgType, role: c.role).expand(
          (n) => n.leaves,
        )) {
          if (!declared.contains(leaf.route)) {
            missing.add('${_name(c)} → ${leaf.label} → ${leaf.route}');
          }
        }
      }
      expect(missing, isEmpty,
          reason: 'nav entries pointing at paths the router does not declare');
    });

    for (final c in _cases) {
      group(_name(c), () {
        late List<PortalNavNode> tree;
        setUp(() => tree = portalNavTree(orgType: c.orgType, role: c.role));

        test('is never empty', () {
          // An empty rail reads as a broken app rather than a restricted one,
          // and leaves no route to sign-out.
          expect(tree, isNotEmpty);
        });

        test('every leaf carries a real path and every group has children', () {
          void walk(PortalNavNode n) {
            if (n.isGroup) {
              expect(n.route, isNull,
                  reason: '${n.label} is a group and must not be a target');
              expect(n.children, isNotEmpty);
              n.children.forEach(walk);
            } else {
              expect(n.route, isNotNull, reason: '${n.label} has no route');
              expect(n.route, startsWith('/'), reason: n.label);
            }
          }

          tree.forEach(walk);
        });

        test('no destination appears twice', () {
          // The flat list carried `Truck locations` and `Truck positions` as
          // separate transporter tabs reading the same provider and rendering
          // the same panel (P7-17).
          final routes = tree.expand((n) => n.leaves).map((l) => l.route);
          expect(routes.toSet().length, routes.length,
              reason: 'duplicate destinations: $routes');
        });

        test('no entry is named after the org type', () {
          // A mine saw a tab called `Mine/Supplier` that showed its own staff
          // (P7-16).
          final labels = <String>[];
          void walk(PortalNavNode n) {
            labels.add(n.label.toLowerCase());
            n.children.forEach(walk);
          }

          tree.forEach(walk);
          for (final banned in const [
            'mine/supplier',
            'mine-supplier',
            'buyer',
            'transporter',
            'workspace',
          ]) {
            expect(labels, isNot(contains(banned)),
                reason: '"$banned" is the operator\'s own org type, not a '
                    'destination');
          }
        });

        test('search reaches nested leaves', () {
          // The flat list could only ever match top-level labels (P7-06).
          final leaf = tree
              .expand((n) => n.leaves)
              .firstWhere((l) => l.label.contains(' '), orElse: () => tree.first)
              .label;
          final hits = tree
              .map((n) => n.filtered(leaf))
              .whereType<PortalNavNode>()
              .expand((n) => n.leaves)
              .map((l) => l.label);
          expect(hits, contains(leaf));
        });
      });
    }

    test('restricted mine roles get no company-wide destinations', () {
      // The security guard and load controller are mobile-first and
      // deliberately locked down; the point of the rebuild is that they gain
      // the Operations Hub tab they are authorised to write to, not that they
      // gain the owner console.
      for (final role in const [
        UserRole.security,
        UserRole.controllerWB,
        UserRole.supervisorForeman,
      ]) {
        final routes = portalNavTree(orgType: OrgType.mineSupplier, role: role)
            .expand((n) => n.leaves)
            .map((l) => l.route!)
            .toSet();
        expect(routes, isNot(contains('/portal/mine/employees')),
            reason: '${role.name} must not reach the employee roster');
        expect(routes, isNot(contains('/portal/mine/company')),
            reason: '${role.name} must not reach the company profile');
        expect(routes, isNot(contains('/portal/mine/tons-out')),
            reason: '${role.name} must not reach the recon tables');
      }
    });

    test('security and the load controller can reach the Operations Hub', () {
      // `OperationsAccessPolicy.canCreate` authorises `security` for incidents
      // and gate checks and `controllerWB` for weighbridge records, but their
      // sidebars were exactly [one screen, Profile] and the only links to the
      // hub lived in two orphaned tab screens. That is the whole explanation
      // for `security_incidents` = 0 rows and `gate_checks` = 1 (P7-18).
      for (final role in const [UserRole.security, UserRole.controllerWB]) {
        final routes = portalNavTree(orgType: OrgType.mineSupplier, role: role)
            .expand((n) => n.leaves)
            .map((l) => l.route!);
        expect(routes, contains('/portal/mine/operations'), reason: role.name);
      }
    });

    test('the supervisor can see the trucks coming for their pile', () {
      // New for this role, and the point of it: they fill the order stockpile
      // and could not see which trucks were inbound to collect it (P7-11).
      final routes = portalNavTree(
        orgType: OrgType.mineSupplier,
        role: UserRole.supervisorForeman,
      ).expand((n) => n.leaves).map((l) => l.route!);
      expect(routes, contains('/portal/mine/truck-locations'));
    });

    test('a driver gets no fleet, money or reconciliation destinations', () {
      final routes =
          portalNavTree(orgType: OrgType.transporter, role: UserRole.driver)
              .expand((n) => n.leaves)
              .map((l) => l.route!)
              .toSet();
      for (final denied in const [
        '/portal/transporter/fleet',
        '/portal/transporter/earnings',
        '/portal/transporter/fuel-costs',
        '/portal/transporter/reconciliations',
        '/portal/transporter/employees',
        '/portal/transporter/company',
      ]) {
        expect(routes, isNot(contains(denied)));
      }
    });

    group('the route guard reads the same tree as the rail (P7-07/P4-09)', () {
      test('a security guard cannot deep-link past their two entries', () {
        // The exact escalation: matching org type was the only check, so a
        // guard whose sidebar is two entries could type their way in.
        for (final path in const [
          '/portal/mine/weighbridge',
          '/portal/mine/tons-out',
          '/portal/mine/reconciliations',
          '/portal/mine/employees',
          '/portal/mine/company',
          '/portal/mine/stockpiles',
          '/portal/mine/quality',
        ]) {
          expect(
            portalRouteAllowedForRole(
              orgType: OrgType.mineSupplier,
              role: UserRole.security,
              path: path,
            ),
            isFalse,
            reason: path,
          );
        }
      });

      test('a driver cannot deep-link into fleet, money or recon', () {
        for (final path in const [
          '/portal/transporter/fleet',
          '/portal/transporter/fleet/abc',
          '/portal/transporter/earnings',
          '/portal/transporter/reconciliations',
          '/portal/transporter/employees',
        ]) {
          expect(
            portalRouteAllowedForRole(
              orgType: OrgType.transporter,
              role: UserRole.driver,
              path: path,
            ),
            isFalse,
            reason: path,
          );
        }
      });

      test('a role keeps the detail routes under its own destinations', () {
        // Selection and the guard both have to understand that a detail page
        // belongs to its parent, or the guard bounces users out of screens
        // they are looking at.
        expect(
          portalRouteAllowedForRole(
            orgType: OrgType.mineSupplier,
            role: UserRole.supervisorForeman,
            path: '/portal/mine/stockpiles/6f0c-abc',
          ),
          isTrue,
        );
        expect(
          portalRouteAllowedForRole(
            orgType: OrgType.mineSupplier,
            role: UserRole.admin,
            path: '/portal/mine/trips/6f0c/waybill',
          ),
          isTrue,
        );
      });

      test('deep-link aliases no tree names stay reachable', () {
        // A whitelist would break the transporter's accept flow and the
        // driver's drop-off to tighten a guard — one fault traded for a worse
        // one. These are reached from a screen, not from the rail.
        for (final path in const [
          '/portal/transporter/accept-route/rt-1',
          '/portal/transporter/allocate-fleet/rt-1',
          '/portal/transporter/drop-off/trip-1',
        ]) {
          expect(
            portalRouteAllowedForRole(
              orgType: OrgType.transporter,
              role: UserRole.admin,
              path: path,
            ),
            isTrue,
            reason: path,
          );
        }
      });

      test('the load controller reaches the hub but not the recon tables', () {
        expect(
          portalRouteAllowedForRole(
            orgType: OrgType.mineSupplier,
            role: UserRole.controllerWB,
            path: '/portal/mine/operations',
          ),
          isTrue,
        );
        expect(
          portalRouteAllowedForRole(
            orgType: OrgType.mineSupplier,
            role: UserRole.controllerWB,
            path: '/portal/mine/tons-out',
          ),
          isFalse,
        );
      });

      test('admin and management are unrestricted within their org', () {
        for (final role in const [UserRole.admin, UserRole.management]) {
          for (final leaf in portalNavTree(
            orgType: OrgType.mineSupplier,
            role: null,
          ).expand((n) => n.leaves)) {
            expect(
              portalRouteAllowedForRole(
                orgType: OrgType.mineSupplier,
                role: role,
                path: leaf.route!,
              ),
              isTrue,
              reason: '${role.name} → ${leaf.route}',
            );
          }
        }
      });
    });

    test('company, admin and management see the same tree', () {
      // `PLAN.md` §4.3 gives all three the org's full tree. The flat list
      // differed between them only by appending employee-roster tabs, which is
      // the "old nonsense" being removed.
      for (final orgType in OrgType.values) {
        String render(UserRole? role) => portalNavTree(
              orgType: orgType,
              role: role,
            ).expand((n) => n.leaves).map((l) => '${l.label}|${l.route}').join();

        expect(render(UserRole.admin), render(null), reason: orgType.name);
        expect(render(UserRole.management), render(null), reason: orgType.name);
      }
    });
  });
}
