import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';

void main() {
  group('Company Model Tests', () {
    test('should create a Company instance from JSON', () {
      // Arrange
      final json = {
        'id': '123',
        'user_id': 'user123',
        'company_name': 'Test Company',
        'whatsapp_number': '+1234567890',
        'org_type': 'mineSupplier',
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-02T00:00:00.000Z',
        'logo_url': 'https://example.com/logo.png',
      };

      // Act
      final company = Company.fromJson(json);

      // Assert
      expect(company.id, '123');
      expect(company.userId, 'user123');
      expect(company.companyName, 'Test Company');
      expect(company.whatsappNumber, '+1234567890');
      expect(company.orgType, OrgType.mineSupplier);
      expect(company.createdAt, DateTime.parse('2023-01-01T00:00:00.000Z'));
      expect(company.updatedAt, DateTime.parse('2023-01-02T00:00:00.000Z'));
      expect(company.logoUrl, 'https://example.com/logo.png');
    });

    test('should convert Company instance to JSON', () {
      // Arrange
      final company = Company(
        id: '123',
        userId: 'user123',
        companyName: 'Test Company',
        whatsappNumber: '+1234567890',
        orgType: OrgType.buyer,
        createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2023-01-02T00:00:00.000Z'),
        logoUrl: 'https://example.com/logo.png',
      );

      // Act
      final json = company.toJson();

      // Assert
      expect(json['id'], '123');
      expect(json['user_id'], 'user123');
      expect(json['company_name'], 'Test Company');
      expect(json['whatsapp_number'], '+1234567890');
      expect(json['org_type'], 'buyer');
      expect(json['created_at'], '2023-01-01T00:00:00.000Z');
      expect(json['updated_at'], '2023-01-02T00:00:00.000Z');
      expect(json['logo_url'], 'https://example.com/logo.png');
    });

    test('should create a copy with updated values', () {
      // Arrange
      final company = Company(
        id: '123',
        userId: 'user123',
        companyName: 'Test Company',
        whatsappNumber: '+1234567890',
        orgType: OrgType.buyer,
        createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
      );

      // Act
      final updatedCompany = company.copyWith(
        companyName: 'Updated Company',
        orgType: OrgType.transporter,
      );

      // Assert
      expect(updatedCompany.id, '123');
      expect(updatedCompany.userId, 'user123');
      expect(updatedCompany.companyName, 'Updated Company');
      expect(updatedCompany.whatsappNumber, '+1234567890');
      expect(updatedCompany.orgType, OrgType.transporter);
      expect(
        updatedCompany.createdAt,
        DateTime.parse('2023-01-01T00:00:00.000Z'),
      );
    });
  });
}
