import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';

void main() {
  // The keys here must match the column names returned by the
  // list_transporter_fleet_status RPC exactly — a mismatch silently breaks the
  // picker and the Trucks On Route screen.
  test('fromJson maps an on-route vehicle from the RPC row shape', () {
    final s = FleetVehicleStatus.fromJson({
      'vehicle_id': 'v1',
      'registration': 'ABC123MP',
      'make': 'Scania',
      'vehicle_type': 'Horse',
      'driver_employee_id': 'e1',
      'driver_name': 'Sipho Dlamini',
      'is_active': true,
      'on_route': true,
      'active_trip_id': 't1',
      'trip_status': 'active',
      'buyer_name': 'Cyberhouse Buyer',
      'commodity': 'Manganese',
      'offloading_point': 'Saldanha',
      'loading_point': 'Sishen',
    });

    expect(s.vehicleId, 'v1');
    expect(s.registration, 'ABC123MP');
    expect(s.driverName, 'Sipho Dlamini');
    expect(s.driverLabel, 'Sipho Dlamini');
    expect(s.onRoute, isTrue);
    expect(s.available, isFalse); // on route → not selectable
    expect(s.buyerName, 'Cyberhouse Buyer');
  });

  test('an active, trip-free vehicle is available; empty strings normalise to null', () {
    final s = FleetVehicleStatus.fromJson({
      'vehicle_id': 'v2',
      'registration': 'TC125MP',
      'is_active': true,
      'on_route': false,
      'commodity': '', // RPC coalesces missing values to ''
      'driver_name': '',
    });

    expect(s.available, isTrue);
    expect(s.commodity, isNull);
    expect(s.driverName, isNull);
    expect(s.driverLabel, 'No driver assigned');
  });

  test('inactive vehicle is never available', () {
    final s = FleetVehicleStatus.fromJson({
      'vehicle_id': 'v3',
      'registration': 'RETIRED',
      'is_active': false,
      'on_route': false,
    });
    expect(s.available, isFalse);
  });
}
