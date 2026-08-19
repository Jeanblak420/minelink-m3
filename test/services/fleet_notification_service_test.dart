import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/models/company_model.dart';
import 'package:flutter_application_1/features/company/services/company_service.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/employee/services/employee_service.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/services/fleet_notification_service.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:flutter_application_1/features/notifications/services/notification_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'fleet_notification_service_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<NotificationService>(),
  MockSpec<EmployeeService>(),
  MockSpec<CompanyService>(),
])

void main() {
  late MockNotificationService mockNotificationService;
  late MockEmployeeService mockEmployeeService;
  late MockCompanyService mockCompanyService;
  late FleetNotificationService fleetNotificationService;

  final company = Company(
    id: 'company-123',
    userId: 'owner-123',
    companyName: 'Acme Logistics',
    whatsappNumber: '+27000000000',
    orgType: OrgType.transporter,
    createdAt: DateTime.parse('2026-03-29T08:00:00.000Z'),
  );

  final managementEmployee = Employee(
    id: 'employee-1',
    userId: 'manager-123',
    firstName: 'Morgan',
    lastName: 'Manager',
    whatsappNumber: '+27000000001',
    companyId: company.id,
    role: UserRole.management,
    status: 'active',
    createdAt: DateTime.parse('2026-03-29T08:00:00.000Z'),
  );

  final adminEmployee = Employee(
    id: 'employee-2',
    userId: 'admin-123',
    firstName: 'Addison',
    lastName: 'Admin',
    whatsappNumber: '+27000000002',
    companyId: company.id,
    role: UserRole.admin,
    status: 'active',
    createdAt: DateTime.parse('2026-03-29T08:00:00.000Z'),
  );

  final driverEmployee = Employee(
    id: 'employee-3',
    userId: 'driver-123',
    firstName: 'Drew',
    lastName: 'Driver',
    whatsappNumber: '+27000000003',
    companyId: company.id,
    role: UserRole.driver,
    status: 'active',
    createdAt: DateTime.parse('2026-03-29T08:00:00.000Z'),
  );

  final vehicle = FleetVehicle(
    id: 'vehicle-1',
    vehicleRegistrationNumber: 'ABC123GP',
    companyId: company.id,
    createdAt: DateTime.parse('2026-03-29T08:00:00.000Z'),
  );

  setUp(() {
    mockNotificationService = MockNotificationService();
    mockEmployeeService = MockEmployeeService();
    mockCompanyService = MockCompanyService();
    fleetNotificationService = FleetNotificationService(
      mockNotificationService,
      mockEmployeeService,
      mockCompanyService,
    );

    when(
      mockCompanyService.getCompanyById(company.id),
    ).thenAnswer((_) async => company);
    when(mockEmployeeService.getEmployeesByCompanyId(company.id)).thenAnswer(
      (_) async => [
        managementEmployee.toJson(),
        adminEmployee.toJson(),
        driverEmployee.toJson(),
      ],
    );
    when(
      mockNotificationService.createActionedNotification(
        userId: anyNamed('userId'),
        title: anyNamed('title'),
        message: anyNamed('message'),
        type: anyNamed('type'),
        companyId: anyNamed('companyId'),
        employeeId: anyNamed('employeeId'),
        actionedBy: anyNamed('actionedBy'),
        actionedById: anyNamed('actionedById'),
        roleScope: anyNamed('roleScope'),
        orgType: anyNamed('orgType'),
        importance: anyNamed('importance'),
        metadata: anyNamed('metadata'),
      ),
    ).thenAnswer((_) async {});
  });

  test('notifies owner, management, and admin when a vehicle is added', () async {
    final success = await fleetNotificationService.notifyVehicleAdded(
      companyId: company.id,
      vehicleRegistrationNumber: vehicle.vehicleRegistrationNumber,
      actionedById: 'actor-123',
      actionedByName: 'Taylor Transport',
    );

    expect(success, isTrue);

    verify(
      mockNotificationService.createActionedNotification(
        userId: company.userId,
        title: 'New Vehicle Added',
        message:
            'Vehicle ${vehicle.vehicleRegistrationNumber} has been added to the fleet by Taylor Transport.',
        type: NotificationType.fleetVehicleAdded,
        companyId: company.id,
        employeeId: null,
        actionedBy: 'Taylor Transport',
        actionedById: 'actor-123',
        roleScope: null,
        orgType: company.orgType.name,
        importance: NotificationImportance.normal,
        metadata: {
          'vehicle_registration_number': vehicle.vehicleRegistrationNumber,
          'actioned_by': 'Taylor Transport',
          'actioned_by_id': 'actor-123',
        },
      ),
    ).called(1);

    verify(
      mockNotificationService.createActionedNotification(
        userId: managementEmployee.userId,
        title: anyNamed('title'),
        message: anyNamed('message'),
        type: NotificationType.fleetVehicleAdded,
        companyId: company.id,
        employeeId: anyNamed('employeeId'),
        actionedBy: anyNamed('actionedBy'),
        actionedById: anyNamed('actionedById'),
        roleScope: UserRole.management.name,
        orgType: company.orgType.name,
        importance: NotificationImportance.normal,
        metadata: anyNamed('metadata'),
      ),
    ).called(1);

    verify(
      mockNotificationService.createActionedNotification(
        userId: adminEmployee.userId,
        title: anyNamed('title'),
        message: anyNamed('message'),
        type: NotificationType.fleetVehicleAdded,
        companyId: company.id,
        employeeId: anyNamed('employeeId'),
        actionedBy: anyNamed('actionedBy'),
        actionedById: anyNamed('actionedById'),
        roleScope: UserRole.admin.name,
        orgType: company.orgType.name,
        importance: NotificationImportance.normal,
        metadata: anyNamed('metadata'),
      ),
    ).called(1);

    verifyNever(
      mockNotificationService.createActionedNotification(
        userId: driverEmployee.userId,
        title: 'New Vehicle Added',
        message: anyNamed('message'),
        type: NotificationType.fleetVehicleAdded,
        companyId: anyNamed('companyId'),
        employeeId: anyNamed('employeeId'),
        actionedBy: anyNamed('actionedBy'),
        actionedById: anyNamed('actionedById'),
        roleScope: anyNamed('roleScope'),
        orgType: anyNamed('orgType'),
        importance: anyNamed('importance'),
        metadata: anyNamed('metadata'),
      ),
    );
  });

  test(
    'sends a dedicated driver notification when a driver is assigned',
    () async {
      final success = await fleetNotificationService.notifyDriverAssigned(
        companyId: company.id,
        vehicle: vehicle,
        driverId: driverEmployee.userId,
        driverName: driverEmployee.fullName,
        actionedById: 'actor-123',
        actionedByName: 'Taylor Transport',
      );

      expect(success, isTrue);

      verify(
        mockNotificationService.createActionedNotification(
          userId: driverEmployee.userId,
          title: 'Vehicle Assignment',
          message:
              'You have been assigned to vehicle ${vehicle.vehicleRegistrationNumber}.',
          type: NotificationType.fleetDriverAssigned,
          companyId: company.id,
          employeeId: null,
          actionedBy: 'Taylor Transport',
          actionedById: 'actor-123',
          roleScope: null,
          orgType: null,
          importance: NotificationImportance.normal,
          metadata: {
            'vehicle_id': vehicle.id,
            'vehicle_registration_number': vehicle.vehicleRegistrationNumber,
          },
        ),
      ).called(1);
    },
  );
}
