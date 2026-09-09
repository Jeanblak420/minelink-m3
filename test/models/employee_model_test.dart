import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';

void main() {
  group('Employee Model Tests', () {
    test('should create an Employee instance from JSON', () {
      // Arrange
      final json = {
        'id': '123',
        'user_id': 'user123',
        'first_name': 'John',
        'last_name': 'Doe',
        'whatsapp_number': '+1234567890',
        'company_id': 'company123',
        'role': 'admin',
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-02T00:00:00.000Z',
        'profile_photo_url': 'https://example.com/photo.png',
      };

      // Act
      final employee = Employee.fromJson(json);

      // Assert
      expect(employee.id, '123');
      expect(employee.userId, 'user123');
      expect(employee.firstName, 'John');
      expect(employee.lastName, 'Doe');
      expect(employee.whatsappNumber, '+1234567890');
      expect(employee.companyId, 'company123');
      expect(employee.role, UserRole.admin);
      expect(employee.createdAt, DateTime.parse('2023-01-01T00:00:00.000Z'));
      expect(employee.updatedAt, DateTime.parse('2023-01-02T00:00:00.000Z'));
      expect(employee.profilePhotoUrl, 'https://example.com/photo.png');
    });

    test('should convert Employee instance to JSON', () {
      // Arrange
      final employee = Employee(
        id: '123',
        userId: 'user123',
        firstName: 'John',
        lastName: 'Doe',
        whatsappNumber: '+1234567890',
        companyId: 'company123',
        role: UserRole.driver,
        createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2023-01-02T00:00:00.000Z'),
        profilePhotoUrl: 'https://example.com/photo.png',
      );

      // Act
      final json = employee.toJson();

      // Assert
      expect(json['id'], '123');
      expect(json['user_id'], 'user123');
      expect(json['first_name'], 'John');
      expect(json['last_name'], 'Doe');
      expect(json['whatsapp_number'], '+1234567890');
      expect(json['company_id'], 'company123');
      expect(json['role'], 'driver');
      expect(json['created_at'], '2023-01-01T00:00:00.000Z');
      expect(json['updated_at'], '2023-01-02T00:00:00.000Z');
      expect(json['profile_photo_url'], 'https://example.com/photo.png');
    });

    test('should create a copy with updated values', () {
      // Arrange
      final employee = Employee(
        id: '123',
        userId: 'user123',
        firstName: 'John',
        lastName: 'Doe',
        whatsappNumber: '+1234567890',
        createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
      );

      // Act
      final updatedEmployee = employee.copyWith(
        firstName: 'Jane',
        role: UserRole.management,
      );

      // Assert
      expect(updatedEmployee.id, '123');
      expect(updatedEmployee.userId, 'user123');
      expect(updatedEmployee.firstName, 'Jane');
      expect(updatedEmployee.lastName, 'Doe');
      expect(updatedEmployee.whatsappNumber, '+1234567890');
      expect(updatedEmployee.role, UserRole.management);
      expect(
        updatedEmployee.createdAt,
        DateTime.parse('2023-01-01T00:00:00.000Z'),
      );
    });

    test('should return full name', () {
      // Arrange
      final employee = Employee(
        id: '123',
        userId: 'user123',
        firstName: 'John',
        lastName: 'Doe',
        whatsappNumber: '+1234567890',
        createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
      );

      // Act & Assert
      expect(employee.fullName, 'John Doe');
    });

    test('should not elevate an unknown role to admin', () {
      final json = {
        'id': '123',
        'user_id': 'user123',
        'first_name': 'John',
        'last_name': 'Doe',
        'whatsapp_number': '+1234567890',
        'company_id': 'company123',
        'role': 'unexpected_role',
        'created_at': '2023-01-01T00:00:00.000Z',
      };

      final employee = Employee.fromJson(json);

      expect(employee.role, isNull);
    });

    test('should not throw on null fields — the transporter-owner '
        '"type \'Null\' is not a subtype of type \'String\'" regression', () {
      // A single null used to crash the whole portal at login: id, user_id,
      // first_name, last_name were assigned straight into non-nullable
      // Strings and created_at into DateTime.parse, so any null row in a
      // company's employee list (database, device cache or RPC payload)
      // surfaced as "Error loading workspace · type 'Null' is not a subtype
      // of type 'String'". Same fault `Company.fromJson` was fixed for on
      // 2026-08-21; the fallbacks here match its conventions exactly.
      final employee = Employee.fromJson(const {
        'id': null,
        'user_id': null,
        'first_name': null,
        'last_name': null,
        'whatsapp_number': null,
        'company_id': null,
        'role': null,
        'status': null,
        'created_at': null,
        'updated_at': null,
        'profile_photo_url': null,
        'is_south_african_citizen': null,
        'id_number': null,
        'date_of_birth': null,
        'is_dismissed': null,
      });

      expect(employee.id, '');
      expect(employee.userId, '');
      expect(employee.firstName, '');
      expect(employee.lastName, '');
      expect(employee.whatsappNumber, '');
      expect(employee.companyId, isNull);
      expect(employee.role, isNull);
      expect(employee.status, isNull);
      expect(
        employee.createdAt,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      expect(employee.updatedAt, isNull);
      expect(employee.isSouthAfricanCitizen, isTrue);
      expect(employee.isDismissed, isFalse);
    });

    test('should not throw on missing keys (stale device cache row)', () {
      // A cached row written by an older build can be missing keys entirely;
      // a missing key reads as null and must not crash the parse either.
      final employee = Employee.fromJson(const {});

      expect(employee.id, '');
      expect(employee.fullName, ' ');
      expect(employee.isSouthAfricanCitizen, isTrue);
      expect(employee.isDismissed, isFalse);
    });

    test('should fall back to the epoch for an unparseable created_at', () {
      final employee = Employee.fromJson(const {
        'id': '123',
        'user_id': 'user123',
        'first_name': 'John',
        'last_name': 'Doe',
        'created_at': 12345, // a non-String must not throw either
      });

      expect(
        employee.createdAt,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    });
  });
}
