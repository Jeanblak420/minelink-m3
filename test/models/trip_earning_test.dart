import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/models/trip_earning.dart';

void main() {
  test('TripEarning.fromJson computes-through revenue fields', () {
    final e = TripEarning.fromJson({
      'trip_id': 't1',
      'reference': 'TRP-1',
      'truck_reg': 'KVK007MP',
      'vehicle_id': 'v1',
      'route_id': 'r1',
      'commodity': 'Chrome',
      'customer_name': 'Atlas Buyer Group',
      'source_name': 'Iron Hills Mining',
      'net_tons': 35,
      'rate_per_ton': 1000,
      'currency': 'ZAR',
      'revenue': 35000.0,
      'status': 'completed',
      'updated_at': '2026-07-27T10:00:00Z',
    });

    expect(e.netTons, 35);
    expect(e.ratePerTon, 1000);
    expect(e.revenue, 35000.0);
    expect(e.currency, 'ZAR');
    expect(e.isPriced, isTrue);
  });

  test('TripEarning with no rate is unpriced (revenue null)', () {
    final e = TripEarning.fromJson({
      'trip_id': 't2',
      'net_tons': 20,
      'rate_per_ton': null,
      'currency': null,
      'revenue': null,
      'updated_at': '2026-07-27T10:00:00Z',
    });
    expect(e.isPriced, isFalse);
    expect(e.revenue, isNull);
    expect(e.currency, 'ZAR'); // default
  });

  test('TripEarning.fromJson maps per-trip P&L (direct + allocated + net)', () {
    final e = TripEarning.fromJson({
      'trip_id': 't1',
      'net_tons': 35,
      'rate_per_ton': 1000,
      'currency': 'ZAR',
      'revenue': 35000.0,
      'direct_cost': 2000.0,
      'allocated_cost': 16000.0,
      'total_cost': 18000.0,
      'net': 17000.0,
      'updated_at': '2026-07-27T10:00:00Z',
    });
    expect(e.directCost, 2000.0);
    expect(e.allocatedCost, 16000.0);
    expect(e.totalCost, 18000.0);
    expect(e.net, 17000.0);
  });

  test('TripEarning defaults P&L fields to zero when absent', () {
    final e = TripEarning.fromJson({
      'trip_id': 't3',
      'currency': 'ZAR',
      'updated_at': '2026-07-27T10:00:00Z',
    });
    expect(e.directCost, 0);
    expect(e.allocatedCost, 0);
    expect(e.totalCost, 0);
    expect(e.net, isNull);
  });

  test('VehicleCost.fromJson sums maintenance', () {
    final c = VehicleCost.fromJson({
      'vehicle_id': 'v1',
      'reg': 'KVK007MP',
      'maintenance_cost': 4200.50,
      'record_count': 3,
    });
    expect(c.maintenanceCost, 4200.50);
    expect(c.recordCount, 3);
    expect(c.reg, 'KVK007MP');
  });
}
