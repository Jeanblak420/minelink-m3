import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';

void main() {
  group('UserRoleNotificationX', () {
    test('management includes downstream scopes and unscoped notifications', () {
      expect(
        UserRole.management.managementNotificationScopes,
        // `driver` added 2026-08-15 (S8-6). This test's own name says
        // "downstream scopes", and driver is one — its absence meant every
        // driver-scoped notification was invisible to management, which on a
        // haulage platform is most of the operational traffic.
        equals([
          UserRole.management,
          UserRole.admin,
          UserRole.controllerWB,
          UserRole.supervisorForeman,
          UserRole.security,
          UserRole.driver,
          null,
        ]),
      );
      expect(
        UserRole.management.managementNotificationFilter,
        'role_scope.eq.management,role_scope.eq.admin,role_scope.eq.controllerWB,role_scope.eq.supervisorForeman,role_scope.eq.security,role_scope.eq.driver,role_scope.is.null',
      );
    });

    test('admin excludes management-only notifications', () {
      expect(
        UserRole.admin.managementNotificationScopes,
        // Still excludes `management` — that is what this test is for. It
        // gains `driver` for the same reason management did (S8-6).
        equals([
          UserRole.admin,
          UserRole.controllerWB,
          UserRole.supervisorForeman,
          UserRole.security,
          UserRole.driver,
          null,
        ]),
      );
      expect(
        UserRole.admin.managementNotificationFilter,
        'role_scope.eq.admin,role_scope.eq.controllerWB,role_scope.eq.supervisorForeman,role_scope.eq.security,role_scope.eq.driver,role_scope.is.null',
      );
      expect(
        UserRole.admin.managementNotificationScopes,
        isNot(contains(UserRole.management)),
        reason: 'the exclusion this test is named for must survive the '
            'addition above',
      );
    });

    test('driver only sees driver-scoped and unscoped notifications', () {
      expect(
        UserRole.driver.managementNotificationScopes,
        equals([UserRole.driver, null]),
      );
      expect(
        UserRole.driver.managementNotificationFilter,
        'role_scope.eq.driver,role_scope.is.null',
      );
    });
  });
}
