import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/models/app_user.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';

void main() {
  group('AppUser', () {
    test('fullName omits null and blank name parts', () {
      final user = AppUser(
        userId: 'user-1',
        firstName: 'Jane',
        lastName: '   ',
      );

      expect(user.fullName, 'Jane');
    });

    test('fromJson keeps unknown role and org type values safe', () {
      final user = AppUser.fromJson({
        'user_id': 'user-1',
        'email': 'user@example.com',
        'user_type': 'employee',
        'role': 'super_admin',
        'org_type': 'unknown_org',
      });

      expect(user.userType, UserType.employee);
      expect(user.role, isNull);
      expect(user.orgType, isNull);
    });
  });
}
