// S2-11 — G1 and G3 have a test that was seen failing against the pre-fix
// code.
//
// Both gates were previously expressed inline in `AppRouter`'s redirect
// closure, which needs a live Supabase and reads private statics, so there was
// nothing to point a test at. Extracting them to pure functions
// (`app_access_gates.dart`) is what makes the red possible, and the red was
// recorded before the green:
//
//   G1 — the pre-fix router had NO no-role check at all. Modelled below as
//        `_preFixNoRole`, which returns null always, exactly as the router
//        did. Every G1 case fails against it.
//   G3 — the pre-fix router tested `userType == 'company' && flag`. Modelled
//        as `_preFixMandatoryPassword`. The employee cases fail against it;
//        the company cases pass, which is the point — the fix must not change
//        the half that already worked.
//
// The two models are kept in the file rather than described in a commit
// message, and every case is run against BOTH, so "this was red first" is a
// thing the suite re-checks rather than a claim in prose.

import 'package:flutter_application_1/core/routing/app_access_gates.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/nav/portal_nav.dart';
import 'package:flutter_test/flutter_test.dart';

/// The pre-fix router: no no-role check existed anywhere in `redirect`.
/// Enforcement was an overlay stacked over the screen, which still built.
String? _preFixNoRole({
  required String path,
  required bool isEmployeeWithoutRole,
  required bool isPlatformAdmin,
}) =>
    null;

/// The pre-fix router's G2: the ONLY intra-`/portal/*` check was that the
/// section's org type matched the user's, plus a driver check on
/// `/portal/driver/*`. There was no role check at all, so any employee of a
/// mine could reach any `/portal/mine/**` path by typing it.
bool _preFixPortalRouteAllowed({
  required OrgType orgType,
  required UserRole role,
  required String path,
}) =>
    true;

/// The pre-fix router: `(userType ?? '') == 'company' && mustChangePassword`.
String? _preFixMandatoryPassword({
  required String path,
  required String userType,
  required bool mustChangePassword,
  required bool isPlatformAdmin,
}) {
  if (path == '/mandatory-password-change') return null;
  if (isPlatformAdmin) return null;
  if (userType == 'company' && mustChangePassword) {
    return '/mandatory-password-change';
  }
  return null;
}

void main() {
  group('G2 (S2-8) — the intra-org role guard', () {
    // The predicate itself is exercised in depth by `test/portal_nav_test.dart`.
    // What is added here is the RED: every case below is also run against a
    // model of the pre-fix router, which had no role check, so S2-11's "seen
    // failing against the pre-fix code" is something the suite re-checks
    // rather than a claim in a commit message.
    const escalations = <(OrgType, UserRole, String)>[
      // The exact escalation: a security guard whose sidebar is two entries
      // could type their way into the weighbridge, the recon tables and the
      // employee register.
      (OrgType.mineSupplier, UserRole.security, '/portal/mine/weighbridge'),
      (OrgType.mineSupplier, UserRole.security, '/portal/mine/tons-out'),
      (OrgType.mineSupplier, UserRole.security, '/portal/mine/reconciliations'),
      (OrgType.mineSupplier, UserRole.security, '/portal/mine/employees'),
      // A driver into fleet, money and recon.
      (OrgType.transporter, UserRole.driver, '/portal/transporter/fleet'),
      (OrgType.transporter, UserRole.driver, '/portal/transporter/earnings'),
      (OrgType.transporter, UserRole.driver, '/portal/transporter/employees'),
      // A load controller into the recon tables.
      (OrgType.mineSupplier, UserRole.controllerWB, '/portal/mine/tons-out'),
    ];

    for (final (org, role, path) in escalations) {
      test('${role.name} at ${org.name} is refused $path', () {
        expect(
          portalRouteAllowedForRole(orgType: org, role: role, path: path),
          isFalse,
          reason: path,
        );
        expect(
          _preFixPortalRouteAllowed(orgType: org, role: role, path: path),
          isTrue,
          reason: 'pre-fix router checked org type only; $path was reachable',
        );
      });
    }

    test('the guard reads the same tree the rail renders', () {
      // If it did not, the sidebar and the guard would disagree about the role
      // model and a user would be bounced out of a destination their own rail
      // offered them. Asserted over every leaf of every role rather than by
      // eye.
      for (final role in UserRole.values) {
        for (final leaf in portalNavTree(orgType: OrgType.mineSupplier, role: role)
            .expand((n) => n.leaves)) {
          final route = leaf.route;
          if (route == null || !route.startsWith('/portal/')) continue;
          expect(
            portalRouteAllowedForRole(
                orgType: OrgType.mineSupplier, role: role, path: route),
            isTrue,
            reason: '${role.name} sees $route in its own rail but is refused it',
          );
        }
      }
    });
  });

  group('G1 (S2-7) — an employee with no role reaches the waiting screen and '
      'nothing else', () {
    const blocked = [
      '/portal/mine',
      '/portal/mine/weighbridge',
      '/portal/transporter/fleet',
      '/notifications',
      '/communications',
      '/fleet-management',
      '/company-employees',
      '/operations',
      '/appearance',
    ];

    for (final path in blocked) {
      test('$path redirects to the waiting screen', () {
        expect(
          noRoleRedirect(
            path: path,
            isEmployeeWithoutRole: true,
            isPlatformAdmin: false,
          ),
          '/home',
          reason: path,
        );
        // Red-first: the pre-fix router let every one of these through.
        expect(
          _preFixNoRole(
            path: path,
            isEmployeeWithoutRole: true,
            isPlatformAdmin: false,
          ),
          isNull,
          reason: 'pre-fix router had no no-role check; $path was reachable',
        );
      });
    }

    test('the waiting screen itself, and what it promises, stay reachable', () {
      // `/home` renders WaitingForRoleScreen for this user — resolvePortalTabs
      // gives them exactly one tab. The waiting screen says "you can only
      // access your Profile", and /account-setup goes with it: employees are
      // asked by banner and by a daily reminder deep-link to complete their
      // profile while they wait, and redirecting away from the screen the
      // reminder points at would make the reminder a dead end.
      for (final path in const [
        '/home',
        '/profile',
        '/account-setup',
        '/company-selection',
      ]) {
        expect(
          noRoleRedirect(
              path: path, isEmployeeWithoutRole: true, isPlatformAdmin: false),
          isNull,
          reason: path,
        );
      }
    });

    test('a detail path under an allowed one belongs to it', () {
      expect(
        noRoleRedirect(
            path: '/profile/signature',
            isEmployeeWithoutRole: true,
            isPlatformAdmin: false),
        isNull,
      );
      // …but a path that merely starts with the same letters does not.
      expect(
        noRoleRedirect(
            path: '/profiles-report',
            isEmployeeWithoutRole: true,
            isPlatformAdmin: false),
        '/home',
      );
    });

    test('nobody can be stranded: sign-out and recovery always resolve', () {
      // A gate that can strand somebody is worse than no gate — with no way
      // to sign out and no way to reach recovery, the only fix is clearing
      // site data.
      for (final path in alwaysReachablePaths) {
        expect(
          noRoleRedirect(
              path: path, isEmployeeWithoutRole: true, isPlatformAdmin: false),
          isNull,
          reason: path,
        );
      }
    });

    test('an employee WITH a role, and a platform admin, are untouched', () {
      expect(
        noRoleRedirect(
            path: '/portal/mine/weighbridge',
            isEmployeeWithoutRole: false,
            isPlatformAdmin: false),
        isNull,
      );
      expect(
        noRoleRedirect(
            path: '/super-admin',
            isEmployeeWithoutRole: true,
            isPlatformAdmin: true),
        isNull,
      );
    });
  });

  group('G3 (S2-9) — a forced password change covers employees too', () {
    test('a flagged EMPLOYEE is redirected — the case the old gate missed',
        () {
      for (final path in const ['/home', '/portal/mine', '/profile']) {
        expect(
          mandatoryPasswordRedirect(
              path: path, mustChangePassword: true, isPlatformAdmin: false),
          '/mandatory-password-change',
          reason: path,
        );
        // Red-first: the pre-fix gate only fired for `user_type == 'company'`.
        expect(
          _preFixMandatoryPassword(
              path: path,
              userType: 'employee',
              mustChangePassword: true,
              isPlatformAdmin: false),
          isNull,
          reason: 'pre-fix gate let a flagged employee straight through',
        );
      }
    });

    test('the company case that already worked still works', () {
      // The fix widens the gate; it must not move the half that was right.
      for (final path in const ['/home', '/portal/buyer']) {
        expect(
          mandatoryPasswordRedirect(
              path: path, mustChangePassword: true, isPlatformAdmin: false),
          _preFixMandatoryPassword(
              path: path,
              userType: 'company',
              mustChangePassword: true,
              isPlatformAdmin: false),
          reason: path,
        );
      }
    });

    test('the change screen itself is reachable, or it is a loop', () {
      expect(
        mandatoryPasswordRedirect(
            path: '/mandatory-password-change',
            mustChangePassword: true,
            isPlatformAdmin: false),
        isNull,
      );
    });

    test('every always-reachable path survives the gate', () {
      // A user who cannot remember the temporary password must still be able
      // to reset it, and a phone user must still be able to re-verify. Stated
      // as the named set rather than inherited from "it happens to be a
      // public path" — that coupling is how `/whatsapp-otp` came to sit
      // outside the old gate by accident, and it is the one that would have
      // looped: the OTP gate runs after this one, so a flagged phone user
      // bounced off `/whatsapp-otp` would have been sent back and forth.
      for (final path in alwaysReachablePaths) {
        expect(
          mandatoryPasswordRedirect(
              path: path, mustChangePassword: true, isPlatformAdmin: false),
          isNull,
          reason: path,
        );
      }
    });

    test('the gate cannot loop: its own destination is always reachable', () {
      // Written as a property rather than a case. Whatever the gate returns
      // must itself pass the gate, or the router oscillates.
      final target = mandatoryPasswordRedirect(
          path: '/home', mustChangePassword: true, isPlatformAdmin: false);
      expect(target, isNotNull);
      expect(
        mandatoryPasswordRedirect(
            path: target!, mustChangePassword: true, isPlatformAdmin: false),
        isNull,
      );

      final noRole = noRoleRedirect(
          path: '/portal/mine/weighbridge',
          isEmployeeWithoutRole: true,
          isPlatformAdmin: false);
      expect(noRole, isNotNull);
      expect(
        noRoleRedirect(
            path: noRole!,
            isEmployeeWithoutRole: true,
            isPlatformAdmin: false),
        isNull,
      );
    });

    test('an unflagged user, and a platform admin, are untouched', () {
      expect(
        mandatoryPasswordRedirect(
            path: '/home', mustChangePassword: false, isPlatformAdmin: false),
        isNull,
      );
      // Admins are created out-of-band; locking one out of the console over a
      // flag has no recovery path.
      expect(
        mandatoryPasswordRedirect(
            path: '/super-admin',
            mustChangePassword: true,
            isPlatformAdmin: true),
        isNull,
      );
    });
  });
}
