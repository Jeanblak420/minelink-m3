import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/live_trip_position.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/utils/maps_link.dart';

void main() {
  group('latLngFromMapsLink', () {
    test('parses the universal ?q= link', () {
      final p = latLngFromMapsLink('https://www.google.com/maps?q=-26.2041,28.0473');
      expect(p, isNotNull);
      expect(p!.latitude, closeTo(-26.2041, 1e-9));
      expect(p.longitude, closeTo(28.0473, 1e-9));
    });

    test('parses q= among other params', () {
      final p = latLngFromMapsLink('https://maps.example/?zoom=12&q=10.5,-20.25');
      expect(p, isNotNull);
      expect(p!.latitude, 10.5);
      expect(p.longitude, -20.25);
    });

    test('returns null for plain text, null, and out-of-range values', () {
      expect(latLngFromMapsLink('Rustenburg smelter gate 3'), isNull);
      expect(latLngFromMapsLink(null), isNull);
      expect(latLngFromMapsLink('https://x/?q=95.0,10.0'), isNull);
      expect(latLngFromMapsLink('https://x/?q=10.0,190.0'), isNull);
    });
  });

  group('LiveTripPosition', () {
    Map<String, dynamic> row({
      String status = 'en_route_to_offload',
      double? lat = -26.2041,
      double? lng = 28.0473,
      double? speed = 60,
      String? offloading = 'https://www.google.com/maps?q=-25.7479,28.2293',
    }) =>
        {
          'trip_id': 'trip-1',
          'trip_status': status,
          'vehicle_id': 'veh-1',
          'truck_reg': 'ND 123-456',
          'transporter_name': 'Haulers Co',
          'supplier_name': 'Big Mine',
          'buyer_name': 'Steel Buyer',
          'loading_point': 'https://www.google.com/maps?q=-26.9000,26.6667',
          'offloading_point': offloading,
          'lat': lat,
          'lng': lng,
          'heading': 12.5,
          'speed_kmh': speed,
          'recorded_at': '2026-07-12T10:00:00+00:00',
        };

    test('fromJson maps every column', () {
      final t = LiveTripPosition.fromJson(row());
      expect(t.tripId, 'trip-1');
      expect(t.status, TripStatus.enRouteToOffload);
      expect(t.truckReg, 'ND 123-456');
      expect(t.transporterName, 'Haulers Co');
      expect(t.hasFix, isTrue);
      expect(t.point!.latitude, closeTo(-26.2041, 1e-9));
      expect(t.speedKmh, 60);
      expect(t.recordedAt, DateTime.utc(2026, 7, 12, 10));
    });

    test('tolerates a row with no position yet', () {
      final t = LiveTripPosition.fromJson({
        'trip_id': 'trip-2',
        'trip_status': 'scheduled',
      });
      expect(t.hasFix, isFalse);
      expect(t.point, isNull);
      expect(t.distanceToDestinationKm, isNull);
      expect(t.eta, isNull);
    });

    test('destination is the loading point until the truck leaves the mine',
        () {
      for (final s in ['scheduled', 'en_route_to_load', 'loading', 'loaded']) {
        final t = LiveTripPosition.fromJson(row(status: s));
        expect(t.destinationText, t.loadingPoint, reason: s);
      }
      for (final s in ['left_mine', 'en_route_to_offload', 'offloaded']) {
        final t = LiveTripPosition.fromJson(row(status: s));
        expect(t.destinationText, t.offloadingPoint, reason: s);
      }
    });

    test('distance + ETA from position, maps-link destination and speed', () {
      final t = LiveTripPosition.fromJson(row());
      // Johannesburg -> Pretoria is ~52 km as the crow flies.
      expect(t.distanceToDestinationKm, isNotNull);
      expect(t.distanceToDestinationKm!, greaterThan(45));
      expect(t.distanceToDestinationKm!, lessThan(60));
      final eta = t.eta!;
      // ~52 km at 60 km/h ≈ 52 minutes.
      expect(eta.inMinutes, greaterThan(40));
      expect(eta.inMinutes, lessThan(65));
    });

    test('no ETA when stationary or when the destination is plain text', () {
      expect(LiveTripPosition.fromJson(row(speed: 2)).eta, isNull);
      expect(LiveTripPosition.fromJson(row(speed: null)).eta, isNull);
      final plainText =
          LiveTripPosition.fromJson(row(offloading: 'Durban harbour berth 4'));
      expect(plainText.destinationPoint, isNull);
      expect(plainText.distanceToDestinationKm, isNull);
      expect(plainText.eta, isNull);
    });
  });
}
