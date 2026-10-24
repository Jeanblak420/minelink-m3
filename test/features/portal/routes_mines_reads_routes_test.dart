// The buyer's Routes & mines page lists the routes the platform actually
// links (emulator walk, 2026-10-24). It read `haul_routes`, a table nothing
// has written since the request -> link -> dispatch flow began minting rows in
// `routes`: 0 rows there against 1 in `routes`, so the page said "No haul
// routes yet" while Waybills beside it showed the route.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/logistics_models.dart';

void main() {
  test('a routes row becomes a route record, loading -> offloading', () {
    final r = HaulRouteRecord.fromRoute({
      'id': 'r1',
      'route_number': 'RT-9F7B5BA3',
      'supplier_company_id': 'mine',
      'buyer_company_id': 'buyer',
      'loading_point': 'Belfast',
      'offloading_point': 'maputo',
      'created_at': '2026-09-18T00:56:00Z',
    });
    expect(r.id, 'r1');
    expect(r.originLabel, 'Belfast');
    expect(r.destinationLabel, 'maputo');
    expect(r.buyerCompanyId, 'buyer');
    expect(r.updatedAt, DateTime.utc(2026, 9, 18, 0, 56));
  });

  test('missing points read as a dash, not a crash', () {
    final r = HaulRouteRecord.fromRoute(
        {'id': 'r2', 'created_at': '2026-09-18T00:56:00Z'});
    expect(r.originLabel, '—');
    expect(r.destinationLabel, '—');
  });

  test('the snapshot reads routes, not the abandoned haul_routes', () {
    final src = File('lib/features/portal/services/logistics_service.dart')
        .readAsStringSync();
    expect(src, isNot(contains(".from('haul_routes')")));
    expect(src, contains(".from('routes')"));
  });
}
