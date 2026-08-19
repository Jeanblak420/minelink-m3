import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/fleet/services/fleet_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'fleet_provider_test.mocks.dart';
import '../test_helpers/test_supabase.dart';

@GenerateNiceMocks([MockSpec<FleetService>()])

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await ensureTestSupabaseInitialized();
  });

  late MockFleetService mockFleetService;
  late ProviderContainer container;

  final activeVehicle = FleetVehicle(
    id: 'vehicle-1',
    vehicleRegistrationNumber: 'ABC123GP',
    companyId: 'company-123',
    createdAt: DateTime.parse('2026-03-29T08:00:00.000Z'),
    isActive: true,
  );

  final inactiveVehicle = FleetVehicle(
    id: 'vehicle-2',
    vehicleRegistrationNumber: 'XYZ987GP',
    companyId: 'company-123',
    createdAt: DateTime.parse('2026-03-29T08:00:00.000Z'),
    isActive: false,
  );

  final assignedVehicle = FleetVehicle(
    id: 'vehicle-3',
    vehicleRegistrationNumber: 'DRV555GP',
    companyId: 'company-123',
    assignedDriverEmployeeId: 'employee-123',
    driverFirstName: 'Pat',
    driverLastName: 'Driver',
    createdAt: DateTime.parse('2026-03-29T08:00:00.000Z'),
    isActive: true,
  );

  setUp(() {
    mockFleetService = MockFleetService();
    container = ProviderContainer(
      overrides: [fleetServiceProvider.overrideWithValue(mockFleetService)],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('loadFleetVehicles updates provider state from the service', () async {
    when(mockFleetService.getFleetVehicles('company-123')).thenAnswer(
      (_) async => [activeVehicle, inactiveVehicle, assignedVehicle],
    );

    final notifier = container.read(fleetProvider('company-123').notifier);
    await notifier.loadFleetVehicles();

    final state = container.read(fleetProvider('company-123'));
    expect(state.vehicles, hasLength(3));
    expect(state.error, isNull);
    expect(state.isLoading, isFalse);
  });

  test(
    'assignDriver refreshes the updated vehicle and available drivers',
    () async {
      when(
        mockFleetService.getFleetVehicles('company-123'),
      ).thenAnswer((_) async => [activeVehicle]);
      when(
        mockFleetService.assignDriver(
          vehicleId: 'vehicle-1',
          companyId: 'company-123',
          driverId: 'employee-123',
        ),
      ).thenAnswer((_) async => assignedVehicle.copyWith(id: 'vehicle-1'));
      when(mockFleetService.getAvailableDrivers('company-123')).thenAnswer(
        (_) async => [
          {'id': 'employee-999', 'first_name': 'Casey', 'last_name': 'Backup'},
        ],
      );

      final notifier = container.read(fleetProvider('company-123').notifier);
      await notifier.loadFleetVehicles();
      await notifier.assignDriver(
        vehicleId: 'vehicle-1',
        driverId: 'employee-123',
      );

      final state = container.read(fleetProvider('company-123'));
      expect(state.vehicles.single.hasAssignedDriver, isTrue);
      expect(state.availableDrivers, hasLength(1));
      expect(state.availableDrivers.single['id'], 'employee-999');
    },
  );

  test(
    'FleetState getters separate active, inactive, and assigned vehicles',
    () {
      final state = FleetState(
        vehicles: [activeVehicle, inactiveVehicle, assignedVehicle],
      );

      expect(state.activeVehicles, hasLength(2));
      expect(state.inactiveVehicles, hasLength(1));
      expect(state.assignedVehicles, hasLength(1));
      expect(state.unassignedVehicles, hasLength(1));
      expect(state.unassignedVehicles.single.id, activeVehicle.id);
    },
  );
}
