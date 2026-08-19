import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/models/trip_reconciliation.dart';

void main() {
  // Keys must match the list_trip_reconciliations RPC columns exactly.
  test('fromJson maps a delivered trip with variance', () {
    final r = TripReconciliation.fromJson({
      'trip_id': 't1',
      'reference': 'TRP-ABC',
      'truck_reg': 'CA 123-456',
      'commodity': 'Iron Ore',
      'source_name': 'Sishen',
      'customer_name': 'Cyberhouse Buyer',
      'transporter_name': 'Trans-Africa',
      'mine_net_tons': 36.22,
      'delivered_tons': 35.90,
      'variance': 0.32,
      'trip_status': 'completed',
      'updated_at': '2026-07-12T10:30:00Z',
    });

    expect(r.tripId, 't1');
    expect(r.sourceName, 'Sishen');
    expect(r.customerName, 'Cyberhouse Buyer');
    expect(r.mineNetTons, closeTo(36.22, 1e-9));
    expect(r.deliveredTons, closeTo(35.90, 1e-9));
    expect(r.variance, closeTo(0.32, 1e-9));
    expect(r.isDelivered, isTrue);
  });

  test('a loaded-but-not-delivered trip has null delivered/variance', () {
    final r = TripReconciliation.fromJson({
      'trip_id': 't2',
      'truck_reg': 'ND 55 555',
      'mine_net_tons': 40.0,
      'delivered_tons': null,
      'variance': null,
      'trip_status': 'loaded',
      'updated_at': '2026-07-12T08:00:00Z',
    });

    expect(r.mineNetTons, closeTo(40.0, 1e-9));
    expect(r.deliveredTons, isNull);
    expect(r.variance, isNull);
    expect(r.isDelivered, isFalse);
  });
}
