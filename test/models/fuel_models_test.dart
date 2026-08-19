import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/models/fuel_models.dart';

void main() {
  test('FuelEntry.fromJson + price/litre', () {
    final f = FuelEntry.fromJson({
      'id': 'f1',
      'vehicle_id': 'v1',
      'reg': 'ABC123MP',
      'trip_id': null,
      'litres': 400,
      'cost_zar': 8000,
      'odometer_km': 100000,
      'station': 'Shell',
      'filled_at': '2026-07-27T10:00:00Z',
      'notes': null,
      'created_by': 'u1',
    });
    expect(f.litres, 400);
    expect(f.costZar, 8000);
    expect(f.pricePerLitre, closeTo(20.0, 1e-9));
    expect(f.odometerKm, 100000);
  });

  test('OperatingCostKind parse + OperatingCost.fromJson', () {
    for (final k in OperatingCostKind.values) {
      expect(OperatingCostKind.parse(k.wire), k);
    }
    expect(OperatingCostKind.parse('xyz'), OperatingCostKind.other);

    final c = OperatingCost.fromJson({
      'id': 'o1',
      'vehicle_id': 'v1',
      'reg': 'ABC123MP',
      'kind': 'tyre',
      'cost_zar': 3000,
      'incurred_at': '2026-07-27T10:00:00Z',
      'description': '2 steer tyres',
    });
    expect(c.kind, OperatingCostKind.tyre);
    expect(c.costZar, 3000);
  });

  test('VehicleCostBreakdown totals all cost lines', () {
    final b = VehicleCostBreakdown.fromJson({
      'vehicle_id': 'v1',
      'reg': 'ABC123MP',
      'maintenance_cost': 5000,
      'fuel_cost': 13000,
      'fuel_litres': 650,
      'tyre_cost': 3000,
      'toll_cost': 500,
      'other_cost': 0,
      'distance_km': 500,
      'l_per_100km': 50,
      'cost_per_km': 10,
    });
    expect(b.totalCost, 21500); // 5000+13000+3000+500+0
    expect(b.lPer100km, 50);
    expect(b.costPerKm, 10);
  });
}
