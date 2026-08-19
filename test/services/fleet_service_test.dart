import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/services/database_service.dart';
import 'package:flutter_application_1/features/fleet/services/fleet_service.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'fleet_service_test.mocks.dart';
import '../test_helpers/test_supabase.dart';

@GenerateNiceMocks([MockSpec<DatabaseService>()])

void main() {
  late MockDatabaseService mockDatabaseService;
  late FleetService fleetService;

  final vehicleRecord = <String, dynamic>{
    'id': 'vehicle-123',
    'vehicle_registration_number': 'ABC123GP',
    'company_id': 'company-123',
    'created_at': '2026-03-29T08:00:00.000Z',
    'is_active': true,
  };

  final employeeRecord = <String, dynamic>{
    'id': 'employee-123',
    'user_id': 'user-123',
    'first_name': 'Jordan',
    'last_name': 'Driver',
    'whatsapp_number': '+27000000000',
    'company_id': 'company-123',
    'role': 'driver',
    'status': 'active',
    'created_at': '2026-03-29T08:00:00.000Z',
    'updated_at': '2026-03-29T08:30:00.000Z',
  };

  final companyRecord = <String, dynamic>{
    'id': 'company-123',
    'user_id': 'owner-123',
    'company_name': 'Mineral Movers',
    'whatsapp_number': '+27000000001',
    'org_type': 'transporter',
    'created_at': '2026-03-29T08:00:00.000Z',
  };

  setUpAll(() async {
    await ensureTestSupabaseInitialized();
  });

  setUp(() {
    mockDatabaseService = MockDatabaseService();
    fleetService = FleetService(mockDatabaseService);
  });

  test('returns parsed fleet vehicles for a company', () async {
    when(
      mockDatabaseService.getRecords(
        'fleet_vehicles',
        filters: {'company_id': 'company-123'},
        orderBy: 'created_at',
        ascending: false,
      ),
    ).thenAnswer((_) async => [vehicleRecord]);

    final vehicles = await fleetService.getFleetVehicles('company-123');

    expect(vehicles, hasLength(1));
    expect(vehicles.single.id, 'vehicle-123');
    expect(vehicles.single.vehicleRegistrationNumber, 'ABC123GP');
    expect(vehicles.single.companyId, 'company-123');
    expect(vehicles.single.isActive, isTrue);
  });

  test('returns a single fleet vehicle by id', () async {
    when(
      mockDatabaseService.getRecord('fleet_vehicles', 'id', 'vehicle-123'),
    ).thenAnswer((_) async => vehicleRecord);

    final vehicle = await fleetService.getFleetVehicleById('vehicle-123');

    expect(vehicle.id, 'vehicle-123');
    expect(vehicle.vehicleRegistrationNumber, 'ABC123GP');
  });

  test('returns company employees as resolved maps', () async {
    when(
      mockDatabaseService.getRecords(
        'employees',
        filters: {'company_id': 'company-123'},
      ),
    ).thenAnswer((_) async => [employeeRecord]);

    final employees = await fleetService.getCompanyEmployees('company-123');

    expect(employees, hasLength(1));
    expect(employees.single['user_id'], 'user-123');
    expect(employees.single['first_name'], 'Jordan');
    expect(employees.single['role'], 'driver');
  });

  test('returns a company record by id', () async {
    when(
      mockDatabaseService.getRecord('companies', 'id', 'company-123'),
    ).thenAnswer((_) async => companyRecord);

    final company = await fleetService.getCompanyById('company-123');

    expect(company, isNotNull);
    expect(company!['company_name'], 'Mineral Movers');
    expect(company['org_type'], 'transporter');
  });
}
