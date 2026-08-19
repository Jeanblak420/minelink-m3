// S8-6. Management and admin could not see driver-scoped notifications.
//
// `managementNotificationScopes` decides which `role_scope` values a user's
// notification inbox subscribes to. Management's list held management, admin,
// controllerWB, supervisorForeman, security and null — and **not driver**.
// Admin's list was the same minus management.
//
// So every notification written with `role_scope = 'driver'` was invisible to
// exactly the two roles that supervise drivers. On a haulage platform that is
// most of the operational traffic: driver assignment, trip lifecycle events,
// POD capture. Management would be told about a weighbridge reading and not
// about the driver who never arrived.
//
// The asymmetry is the tell. Every other role's list is [itself, null] —
// self-scoped, correct. Management and admin are the two supervisory lists,
// and driver was the one operational role missing from both.

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/auth/models/user_type.dart';

void main() {
  group('supervisory roles see driver-scoped notifications', () {
    test('management includes driver', () {
      expect(
        UserRole.management.managementNotificationScopes,
        contains(UserRole.driver),
        reason: 'management supervises drivers; a driver-scoped notification '
            'they cannot see is a notification that did not happen',
      );
    });

    test('admin includes driver', () {
      expect(
        UserRole.admin.managementNotificationScopes,
        contains(UserRole.driver),
      );
    });

    test('management still sees every other operational role', () {
      // Guards against "fixing" this by narrowing the list instead of widening
      // it — the point is that management sees more, not that driver replaced
      // somebody.
      final scopes = UserRole.management.managementNotificationScopes;
      for (final role in [
        UserRole.management,
        UserRole.admin,
        UserRole.controllerWB,
        UserRole.supervisorForeman,
        UserRole.security,
        UserRole.driver,
      ]) {
        expect(scopes, contains(role), reason: '$role missing from management');
      }
      expect(scopes, contains(null),
          reason: 'unscoped company-wide notifications must still arrive');
    });

    test('a non-supervisory role stays self-scoped', () {
      // security must NOT gain visibility of anyone else — this is the
      // boundary that makes the two lists above meaningful.
      expect(
        UserRole.security.managementNotificationScopes,
        unorderedEquals(<UserRole?>[UserRole.security, null]),
      );
      expect(
        UserRole.driver.managementNotificationScopes,
        unorderedEquals(<UserRole?>[UserRole.driver, null]),
      );
    });

    test('the filter string carries driver through to the query', () {
      // managementNotificationFilter is what actually reaches PostgREST; a
      // list fix that did not reach the filter would change nothing.
      expect(
        UserRole.management.managementNotificationFilter,
        contains('role_scope.eq.driver'),
      );
      expect(
        UserRole.admin.managementNotificationFilter,
        contains('role_scope.eq.driver'),
      );
    });
  });
}
