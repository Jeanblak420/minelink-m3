import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UserRole labels', () {
    test('controllerWB is relabelled to Load Controller', () {
      expect(UserRole.controllerWB.label, 'Load Controller');
      // The enum name (stored DB value) is unchanged.
      expect(UserRole.controllerWB.name, 'controllerWB');
    });

    test('supervisorForeman exists with the expected label', () {
      expect(UserRole.supervisorForeman.label, 'Supervisor/Foreman');
      expect(UserRole.tryParse('supervisorForeman'), UserRole.supervisorForeman);
    });
  });

  group('getRolesForOrgType(mineSupplier)', () {
    test('includes Supervisor/Foreman and Load Controller', () {
      final roles = UserRole.getRolesForOrgType(OrgType.mineSupplier);
      expect(roles, contains(UserRole.supervisorForeman));
      expect(roles, contains(UserRole.controllerWB));
      expect(roles, contains(UserRole.security));
      expect(roles, contains(UserRole.admin));
      expect(roles, contains(UserRole.management));
    });
  });

  // P3-51 — the org-type role matrix, ruled by the client on 2026-08-11 and
  // enforced in Postgres by migration 20260812090000 (trigger
  // employees_role_org_type_check → is_valid_role_for_org). This group is the
  // UI half of the same rule: every role picker in the app resolves its options
  // through getRolesForOrgType, so pinning it here pins all of them.
  //
  // Asserted with unorderedEquals rather than `contains`, deliberately. The
  // group above uses `contains`, which can only catch a role going missing — it
  // cannot catch one being ADDED, and "the buyer picker offers exactly two
  // options" is precisely a statement about what is absent.
  group('P3-51 org-type role matrix', () {
    test('buyer offers exactly admin and management', () {
      expect(
        UserRole.getRolesForOrgType(OrgType.buyer),
        unorderedEquals([UserRole.admin, UserRole.management]),
      );
    });

    test('mineSupplier offers exactly the five mine roles', () {
      expect(
        UserRole.getRolesForOrgType(OrgType.mineSupplier),
        unorderedEquals([
          UserRole.admin,
          UserRole.management,
          UserRole.supervisorForeman,
          UserRole.security,
          UserRole.controllerWB,
        ]),
      );
    });

    test('transporter offers exactly admin, management and driver', () {
      expect(
        UserRole.getRolesForOrgType(OrgType.transporter),
        unorderedEquals(
            [UserRole.admin, UserRole.management, UserRole.driver]),
      );
    });

    test('supervisorForeman, security and controllerWB are mine-only', () {
      for (final orgType in [OrgType.buyer, OrgType.transporter]) {
        final roles = UserRole.getRolesForOrgType(orgType);
        expect(roles, isNot(contains(UserRole.supervisorForeman)));
        expect(roles, isNot(contains(UserRole.security)));
        expect(roles, isNot(contains(UserRole.controllerWB)));
      }
    });

    test('driver is transporter-only', () {
      for (final orgType in [OrgType.buyer, OrgType.mineSupplier]) {
        expect(UserRole.getRolesForOrgType(orgType),
            isNot(contains(UserRole.driver)));
      }
    });

    test('every org type gets a default that its own matrix permits', () {
      // A default outside the matrix would be refused by the trigger on save —
      // a picker that opens on an option the database will reject.
      for (final orgType in OrgType.values) {
        expect(
          UserRole.getRolesForOrgType(orgType),
          contains(UserRole.getDefaultRoleForOrgType(orgType)),
          reason: '${orgType.name} defaults to a role it may not use',
        );
      }
    });
  });
}
