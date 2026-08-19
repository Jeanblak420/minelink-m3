import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/features/portal/models/company_location.dart';

void main() {
  test('CompanyLocation.fromJson parses and derives point', () {
    final l = CompanyLocation.fromJson({
      'id': 'a',
      'company_id': 'c',
      'name': 'Main gate',
      'map_link': 'https://www.google.com/maps?q=-26.0285039,28.0019869',
      'is_primary': true,
    });
    expect(l.name, 'Main gate');
    expect(l.isPrimary, isTrue);
    expect(l.point, isNotNull);
    expect(l.point!.latitude, closeTo(-26.0285039, 1e-7));
  });

  test('NavDestination.fromJson found / address / none forms', () {
    final found = NavDestination.fromJson({
      'found': true,
      'lat': -26.0,
      'lng': 28.0,
      'label': 'Iron Hills — Gate',
      'source': 'company_location',
    });
    expect(found.point, equals(const LatLng(-26.0, 28.0)));
    expect(found.found, isTrue);

    final addr = NavDestination.fromJson({
      'found': false,
      'address': 'Steelport, Limpopo',
      'label': 'X',
      'source': 'address',
    });
    expect(addr.point, isNull);
    expect(addr.address, 'Steelport, Limpopo');

    final none = NavDestination.fromJson({'found': false, 'source': 'none'});
    expect(none.found, isFalse);
    expect(none.point, isNull);
    expect(none.address, isNull);
  });
}
