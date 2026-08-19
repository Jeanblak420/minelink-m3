import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/models/vehicle_driver.dart';

void main() {
  group('VehicleDriver', () {
    test('parses a list_vehicle_drivers row', () {
      final d = VehicleDriver.fromJson({
        'assignment_id': 'a-1',
        'vehicle_id': 'v-1',
        'registration': 'ABC 123 GP',
        'driver_employee_id': 'e-1',
        'driver_name': 'Sipho Dlamini',
        'on_route': true,
        'assigned_at': '2026-07-12T09:00:00Z',
      });
      expect(d.assignmentId, 'a-1');
      expect(d.registration, 'ABC 123 GP');
      expect(d.nameLabel, 'Sipho Dlamini');
      expect(d.onRoute, isTrue);
    });

    test('tolerates a missing name and on_route', () {
      final d = VehicleDriver.fromJson({
        'assignment_id': 'a-2',
        'vehicle_id': 'v-1',
        'driver_employee_id': 'e-2',
        'assigned_at': '2026-07-12T09:00:00Z',
      });
      expect(d.nameLabel, '—');
      expect(d.onRoute, isFalse);
      expect(d.registration, '—');
    });
  });

  group('DriverLimitRequest', () {
    test('parses a list_driver_limit_requests row', () {
      final r = DriverLimitRequest.fromJson({
        'id': 'r-1',
        'company_id': 'co-1',
        'company_name': 'Haul Co',
        'vehicle_id': 'v-1',
        'registration': 'ABC 123 GP',
        'current_limit': 2,
        'requested_limit': 4,
        'status': 'pending',
        'requested_by_name': 'Jean',
        'created_at': '2026-07-12T09:00:00Z',
        'decided_at': null,
      });
      expect(r.isPending, isTrue);
      expect(r.currentLimit, 2);
      expect(r.requestedLimit, 4);
      expect(r.decidedAt, isNull);
    });

    test('decided request is not pending', () {
      final r = DriverLimitRequest.fromJson({
        'id': 'r-2',
        'company_id': 'co-1',
        'vehicle_id': 'v-1',
        'registration': 'ABC 123 GP',
        'current_limit': 2,
        'requested_limit': 5,
        'status': 'approved',
        'created_at': '2026-07-12T09:00:00Z',
        'decided_at': '2026-07-12T10:00:00Z',
      });
      expect(r.isPending, isFalse);
      expect(r.decidedAt, isNotNull);
    });
  });

  group('FleetVehicleStatus multi-driver fields', () {
    test('parses drivers aggregate + counts', () {
      final s = FleetVehicleStatus.fromJson({
        'vehicle_id': 'v-1',
        'registration': 'ABC 123 GP',
        'drivers': 'Sipho Dlamini, Thabo Nkosi',
        'driver_count': 2,
        'max_drivers': 3,
        'is_active': true,
        'on_route': false,
      });
      expect(s.driversLabel, 'Sipho Dlamini, Thabo Nkosi');
      expect(s.driverCount, 2);
      expect(s.maxDrivers, 3);
    });

    test('falls back to the placeholder with no drivers', () {
      final s = FleetVehicleStatus.fromJson({
        'vehicle_id': 'v-2',
        'registration': 'XYZ 987 GP',
        'is_active': true,
        'on_route': false,
      });
      expect(s.driversLabel, 'No driver assigned');
      expect(s.driverCount, 0);
      expect(s.maxDrivers, 2);
    });
  });
}
