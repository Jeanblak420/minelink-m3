import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/transportation_request.dart';

void main() {
  Map<String, dynamic> baseDispatch() => {
        'id': 'd-1',
        'transporter_company_id': 'co-t',
        'status': 'dispatched',
        'dispatched_at': '2026-07-12T09:00:00Z',
        'transporter_price_per_ton': 410.5,
        'transportation_requests': {
          'id': 'r-1',
          'buyer_company_id': 'co-b',
          'request_type': 'transportation',
          'status': 'linked',
          'created_at': '2026-07-12T08:00:00Z',
          'updated_at': '2026-07-12T09:00:00Z',
        },
      };

  test('DispatchedRoute parses the embedded Route ID', () {
    final route = DispatchedRoute.fromJson({
      ...baseDispatch(),
      'route_id': 'rt-uuid',
      'routes': {'route_number': 'RT-1A2B3C4D'},
    });
    expect(route.routeId, 'rt-uuid');
    expect(route.routeNumber, 'RT-1A2B3C4D');
    expect(route.transporterPricePerTon, 410.5);
  });

  test('DispatchedRoute tolerates pre-Route-ID rows (null route)', () {
    final route = DispatchedRoute.fromJson({
      ...baseDispatch(),
      'route_id': null,
      'routes': null,
    });
    expect(route.routeId, isNull);
    expect(route.routeNumber, isNull);
  });
}
