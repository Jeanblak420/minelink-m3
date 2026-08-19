// S5-20/21 — the denominator, derived instead of inherited.
//
// S5-20 and S5-21 are scoped as "Mine's 13 screens and Transporter's 13" and
// "Buyer's 7, the 10 shared and the 11 auth/onboarding screens". Those figures
// come from P6-24…P6-28 and, as the checklist itself flags, had never been
// re-derived. On this project that is a warning rather than a quibble: S1-7
// was 10 and turned out to be 38, S5-13 was 3 and was 5, S5-17 was 3 and was
// 1-of-16, S5-18 was 28 and was 35.
//
// `portalNavTree(orgType:, role:)` is a pure function and is the same tree the
// route guard reads, so it — not a filename prefix, and not a count somebody
// typed once — is what a role can actually reach. This test enumerates it for
// every (org type, role) pair the app can produce and pins the totals.
//
// The numbers below are asserted, not printed and forgotten. If one moves, a
// destination was added to or removed from a role's rail, and the migration
// stage's denominator moved with it — which is a person's decision, not a
// script's.
//
// SCOPE NOTE: this covers the portal rail only. The 11 auth/onboarding screens
// S5-21 also names are pre-login and are not in any nav tree; they are not
// counted here and remain unmeasured.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';

Set<String> routesFor(OrgType org, UserRole? role) => portalNavTree(
      orgType: org,
      role: role,
    ).expand((n) => n.leaves).map((l) => l.route!).toSet();

/// Union of every route any role at [org] can reach. `null` is the company
/// account — the owner login.
Set<String> orgRoutes(OrgType org) => {
      for (final role in <UserRole?>[null, ...UserRole.getRolesForOrgType(org)])
        ...routesFor(org, role),
    };

void main() {
  final mine = orgRoutes(OrgType.mineSupplier);
  final buyer = orgRoutes(OrgType.buyer);
  final transporter = orgRoutes(OrgType.transporter);
  final shared = mine.intersection(buyer).intersection(transporter);
  final all = {...mine, ...buyer, ...transporter};

  group('the measured portal screen inventory', () {
    test('prints the full inventory so a run IS the list', () {
      for (final (label, routes) in [
        ('MINE', mine),
        ('BUYER', buyer),
        ('TRANSPORTER', transporter),
        ('SHARED BY ALL THREE', shared),
      ]) {
        // ignore: avoid_print
        print('\n$label — ${routes.length}');
        for (final r in routes.toList()..sort()) {
          // ignore: avoid_print
          print('  $r');
        }
      }
      // ignore: avoid_print
      print('\nDISTINCT ACROSS THE WHOLE PORTAL — ${all.length}');
      expect(all, isNotEmpty);
    });

    test('per-org totals — the figures S5-20/21 should be measured against',
        () {
      // Measured 2026-08-15. The stage inherited 13 / 13 / 7.
      //
      // +1 each on 2026-08-17: "Search loads"
      // (`/portal/<org>/tons-out-search`). Not a new screen — it is the
      // `TonsOutDetailScreen` that had existed for months with search, sorting
      // and date/mass ranges built and NO route, no import from lib/, and no
      // data source, so it could only ever be constructed empty by a widget
      // test. Jean's ruling: connect it to real data rather than delete it.
      expect(mine.length, 25, reason: 'mine rail destinations');
      expect(transporter.length, 27, reason: 'transporter rail destinations');
      expect(buyer.length, 20, reason: 'buyer rail destinations');
    });

    test('the shared tail is what every org sees identically', () {
      expect(shared, {
        '/account-security',
        '/appearance',
        '/communications',
      });
    });

    test('org-specific counts, once the shared tail is removed', () {
      expect(mine.difference(shared).length, 22);
      expect(transporter.difference(shared).length, 24);
      expect(buyer.difference(shared).length, 17);
    });

    test('the whole portal is this many distinct destinations', () {
      expect(all.length, 66);
    });
  });

  group('invariants that hold across every (org, role) pair', () {
    test('every role has somewhere to go', () {
      for (final org in OrgType.values) {
        for (final role in <UserRole?>[
          null,
          ...UserRole.getRolesForOrgType(org)
        ]) {
          expect(routesFor(org, role), isNotEmpty,
              reason: '${org.name}/${role?.name ?? "owner"} has an empty rail');
        }
      }
    });

    test('the driver gets its own shell, and it is the only such exception',
        () {
      // The driver's Dashboard · Trip · Profile shell is deliberately NOT part
      // of the transporter company account's tree, so "every role's routes are
      // a subset of the owner's" is false — and asserting it as an invariant
      // was this test file's first mistake. The real contract is narrower: the
      // driver has a dedicated shell and no other role does.
      const driverShell = {
        '/portal/driver/home',
        '/portal/driver/trip',
        '/portal/driver/profile',
      };
      expect(routesFor(OrgType.transporter, UserRole.driver),
          containsAll(driverShell));
      expect(routesFor(OrgType.transporter, null).intersection(driverShell),
          isEmpty,
          reason: 'the company account does not get the driver shell');

      for (final org in OrgType.values) {
        for (final role in <UserRole?>[
          null,
          ...UserRole.getRolesForOrgType(org)
        ]) {
          if (org == OrgType.transporter && role == UserRole.driver) continue;
          final extra = routesFor(org, role).difference(orgRoutes(org));
          expect(extra, isEmpty,
              reason: '${org.name}/${role?.name ?? "owner"} reaches $extra '
                  'outside its own org tree');
          final beyondOwner =
              routesFor(org, role).difference(routesFor(org, null));
          expect(beyondOwner, isEmpty,
              reason: '${org.name}/${role?.name ?? "owner"} reaches '
                  '$beyondOwner, which the company account cannot — a second '
                  'role-specific shell has appeared and the migration '
                  'denominator needs revisiting');
        }
      }
    });
  });
}
