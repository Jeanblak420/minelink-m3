// The live-map header counts what the map shows (admin phone audit,
// 2026-10-24): one scheduled trip whose driver had not shared GPS read
// "1 truck reporting" directly above "No GPS fixes yet."
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/live_trip_position.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/widgets/live_trip_map_view.dart';

LiveTripPosition _trip(String id, {bool fix = false}) => LiveTripPosition(
    tripId: id, status: TripStatus.scheduled, lat: fix ? -25.7 : null, lng: fix ? 28.2 : null);

void main() {
  test('a trip without a GPS fix is not a truck reporting', () {
    expect(liveMapReportingMeta([_trip('a')]), '1 active trip · 0 reporting GPS');
  });
  test('some reporting, some not: both numbers', () {
    expect(liveMapReportingMeta([_trip('a', fix: true), _trip('b'), _trip('c')]),
        '3 active trips · 1 reporting GPS');
  });
  test('all reporting: the short form', () {
    expect(liveMapReportingMeta([_trip('a', fix: true)]), '1 truck reporting');
    expect(liveMapReportingMeta([_trip('a', fix: true), _trip('b', fix: true)]), '2 trucks reporting');
  });
}
