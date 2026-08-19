import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/models/maintenance_record.dart';
import 'package:flutter_application_1/features/fleet/models/service_schedule.dart';

void main() {
  group('MaintenanceKind/Status parse', () {
    test('parses wire strings and tolerates junk', () {
      expect(MaintenanceKind.parse('breakdown'), MaintenanceKind.breakdown);
      expect(MaintenanceKind.parse('service'), MaintenanceKind.service);
      expect(MaintenanceKind.parse('???'), MaintenanceKind.repair);
      expect(MaintenanceStatus.parse('open'), MaintenanceStatus.open);
      expect(MaintenanceStatus.parse(null), MaintenanceStatus.closed);
    });
  });

  group('MaintenanceRecord', () {
    test('open out-of-service record blocks assignment', () {
      final r = MaintenanceRecord.fromJson({
        'id': 'r1',
        'vehicle_id': 'v1',
        'registration': 'ABC123MP',
        'kind': 'breakdown',
        'title': 'Gearbox',
        'status': 'open',
        'takes_out_of_service': true,
      });
      expect(r.blocksAssignment, isTrue);
    });

    test('closed record never blocks — truck is back in service', () {
      final r = MaintenanceRecord.fromJson({
        'id': 'r1',
        'vehicle_id': 'v1',
        'registration': 'ABC123MP',
        'kind': 'breakdown',
        'title': 'Gearbox',
        'status': 'closed',
        'takes_out_of_service': true,
      });
      expect(r.blocksAssignment, isFalse);
    });
  });

  group('FleetVehicleStatus availability with maintenance', () {
    FleetVehicleStatus status({bool onRoute = false, bool inMaint = false}) =>
        FleetVehicleStatus(
          vehicleId: 'v1',
          registration: 'ABC123MP',
          isActive: true,
          onRoute: onRoute,
          inMaintenance: inMaint,
        );

    test('in-maintenance truck is not available', () {
      expect(status(inMaint: true).available, isFalse);
    });

    test('closing maintenance returns the truck to available', () {
      // Derived state: same truck, record closed server-side → flag false.
      expect(status(inMaint: false).available, isTrue);
    });

    test('on-route still wins over available', () {
      expect(status(onRoute: true).available, isFalse);
    });
  });

  group('ServiceSchedule.dueSoon', () {
    test('date inside reminder window is due soon', () {
      final s = ServiceSchedule(
        id: 's1',
        vehicleId: 'v1',
        registration: 'ABC123MP',
        name: 'Minor service',
        notifyDaysBefore: 7,
        active: true,
        dueDate: DateTime.now().add(const Duration(days: 3)),
      );
      expect(s.dueSoon, isTrue);
    });

    test('date outside window is not due', () {
      final s = ServiceSchedule(
        id: 's1',
        vehicleId: 'v1',
        registration: 'ABC123MP',
        name: 'Minor service',
        notifyDaysBefore: 7,
        active: true,
        dueDate: DateTime.now().add(const Duration(days: 60)),
      );
      expect(s.dueSoon, isFalse);
    });

    test('odometer within 500 km of due is due soon', () {
      final s = ServiceSchedule(
        id: 's1',
        vehicleId: 'v1',
        registration: 'ABC123MP',
        name: 'Minor service',
        notifyDaysBefore: 7,
        active: true,
        dueOdometerKm: 100000,
        vehicleOdometerKm: 99700,
      );
      expect(s.dueSoon, isTrue);
    });

    test('paused schedule is never due', () {
      final s = ServiceSchedule(
        id: 's1',
        vehicleId: 'v1',
        registration: 'ABC123MP',
        name: 'Minor service',
        notifyDaysBefore: 7,
        active: false,
        dueDate: DateTime.now(),
      );
      expect(s.dueSoon, isFalse);
    });
  });
}
