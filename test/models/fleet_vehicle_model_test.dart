import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';

void main() {
  group('FleetVehicle Model Tests', () {
    test('should create a FleetVehicle instance from JSON', () {
      // Arrange
      final json = {
        'id': '123',
        'vehicle_registration_number': 'ABC123',
        'vehicle_registration_expiry_date': '2023-12-31T00:00:00.000Z',
        'first_trailer_regs': 'TR1',
        'second_trailer_regs': 'TR2',
        'assigned_driver_id': 'driver123',
        'driver_first_name': 'John',
        'driver_last_name': 'Doe',
        'driver_id_number': 'ID123',
        'driver_passport_number': 'PP123',
        'driver_work_permit': 'WP123',
        'drivers_license_document': 'license.pdf',
        'driver_id_document_url': 'https://example.com/id.pdf',
        'driver_passport_document_url': 'https://example.com/passport.pdf',
        'driver_work_visa_document_url': 'https://example.com/visa.pdf',
        'driver_license_document_url': 'https://example.com/license.pdf',
        'driver_is_south_african_citizen': true,
        'company_id': 'company123',
        'created_at': '2023-01-01T00:00:00.000Z',
        'updated_at': '2023-01-02T00:00:00.000Z',
        'is_active': true,
      };

      // Act
      final vehicle = FleetVehicle.fromJson(json);

      // Assert
      expect(vehicle.id, '123');
      expect(vehicle.vehicleRegistrationNumber, 'ABC123');
      expect(
        vehicle.vehicleRegistrationExpiryDate,
        DateTime.parse('2023-12-31T00:00:00.000Z'),
      );
      expect(vehicle.firstTrailerRegs, 'TR1');
      expect(vehicle.secondTrailerRegs, 'TR2');
      expect(vehicle.assignedDriverId, 'driver123');
      expect(vehicle.driverFirstName, 'John');
      expect(vehicle.driverLastName, 'Doe');
      expect(vehicle.driverIdNumber, 'ID123');
      expect(vehicle.driverPassportNumber, 'PP123');
      expect(vehicle.driverWorkPermit, 'WP123');
      expect(vehicle.driversLicenseDocument, 'license.pdf');
      expect(vehicle.driverIdDocumentUrl, 'https://example.com/id.pdf');
      expect(
        vehicle.driverPassportDocumentUrl,
        'https://example.com/passport.pdf',
      );
      expect(vehicle.driverWorkVisaDocumentUrl, 'https://example.com/visa.pdf');
      expect(
        vehicle.driverLicenseDocumentUrl,
        'https://example.com/license.pdf',
      );
      expect(vehicle.driverIsSouthAfricanCitizen, true);
      expect(vehicle.companyId, 'company123');
      expect(vehicle.createdAt, DateTime.parse('2023-01-01T00:00:00.000Z'));
      expect(vehicle.updatedAt, DateTime.parse('2023-01-02T00:00:00.000Z'));
      expect(vehicle.isActive, true);
    });

    test('should convert FleetVehicle instance to JSON', () {
      // Arrange
      final vehicle = FleetVehicle(
        id: '123',
        vehicleRegistrationNumber: 'ABC123',
        vehicleRegistrationExpiryDate: DateTime.parse(
          '2023-12-31T00:00:00.000Z',
        ),
        firstTrailerRegs: 'TR1',
        secondTrailerRegs: 'TR2',
        assignedDriverId: 'driver123',
        driverFirstName: 'John',
        driverLastName: 'Doe',
        companyId: 'company123',
        createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
        updatedAt: DateTime.parse('2023-01-02T00:00:00.000Z'),
        isActive: true,
      );

      // Act
      final json = vehicle.toJson();

      // Assert
      expect(json['id'], '123');
      expect(json['vehicle_registration_number'], 'ABC123');
      expect(
        json['vehicle_registration_expiry_date'],
        '2023-12-31T00:00:00.000Z',
      );
      expect(json['first_trailer_regs'], 'TR1');
      expect(json['second_trailer_regs'], 'TR2');
      expect(json['assigned_driver_id'], 'driver123');
      expect(json['driver_first_name'], 'John');
      expect(json['driver_last_name'], 'Doe');
      expect(json['company_id'], 'company123');
      expect(json['created_at'], '2023-01-01T00:00:00.000Z');
      expect(json['updated_at'], '2023-01-02T00:00:00.000Z');
      expect(json['is_active'], true);
    });

    test('should create a copy with updated values', () {
      // Arrange
      final vehicle = FleetVehicle(
        id: '123',
        vehicleRegistrationNumber: 'ABC123',
        companyId: 'company123',
        createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
      );

      // Act
      final updatedVehicle = vehicle.copyWith(
        vehicleRegistrationNumber: 'XYZ789',
        isActive: false,
      );

      // Assert
      expect(updatedVehicle.id, '123');
      expect(updatedVehicle.vehicleRegistrationNumber, 'XYZ789');
      expect(updatedVehicle.companyId, 'company123');
      expect(
        updatedVehicle.createdAt,
        DateTime.parse('2023-01-01T00:00:00.000Z'),
      );
      expect(updatedVehicle.isActive, false);
    });

    test('hasAssignedDriver should return true when driver is assigned', () {
      // Arrange
      final vehicle = FleetVehicle(
        id: '123',
        vehicleRegistrationNumber: 'ABC123',
        assignedDriverId: 'driver123',
        companyId: 'company123',
        createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
      );

      // Act & Assert
      expect(vehicle.hasAssignedDriver, true);
    });

    test(
      'hasAssignedDriver should return false when no driver is assigned',
      () {
        // Arrange
        final vehicle = FleetVehicle(
          id: '123',
          vehicleRegistrationNumber: 'ABC123',
          companyId: 'company123',
          createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
        );

        // Act & Assert
        expect(vehicle.hasAssignedDriver, false);
      },
    );

    test('driverFullName should return full name when driver is assigned', () {
      // Arrange
      final vehicle = FleetVehicle(
        id: '123',
        vehicleRegistrationNumber: 'ABC123',
        assignedDriverId: 'driver123',
        driverFirstName: 'John',
        driverLastName: 'Doe',
        companyId: 'company123',
        createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
      );

      // Act & Assert
      expect(vehicle.driverFullName, 'John Doe');
    });

    test(
      'driverFullName should return default message when no driver is assigned',
      () {
        // Arrange
        final vehicle = FleetVehicle(
          id: '123',
          vehicleRegistrationNumber: 'ABC123',
          companyId: 'company123',
          createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
        );

        // Act & Assert
        expect(vehicle.driverFullName, 'No driver assigned');
      },
    );

    test(
      'formattedExpiryDate should return formatted date when expiry date is set',
      () {
        // Arrange
        final vehicle = FleetVehicle(
          id: '123',
          vehicleRegistrationNumber: 'ABC123',
          vehicleRegistrationExpiryDate: DateTime(2023, 12, 31),
          companyId: 'company123',
          createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
        );

        // Act & Assert
        expect(vehicle.formattedExpiryDate, '31/12/2023');
      },
    );

    test(
      'formattedExpiryDate should return default message when no expiry date is set',
      () {
        // Arrange
        final vehicle = FleetVehicle(
          id: '123',
          vehicleRegistrationNumber: 'ABC123',
          companyId: 'company123',
          createdAt: DateTime.parse('2023-01-01T00:00:00.000Z'),
        );

        // Act & Assert
        expect(vehicle.formattedExpiryDate, 'Not specified');
      },
    );
  });
}
