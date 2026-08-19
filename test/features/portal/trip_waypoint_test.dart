// S9-4 — trip waypoints and the two-party gate confirmation, which had no
// test at all.
//
// The load-bearing thing here is that `isTareWeighbridge` and
// `isGrossWeighbridge` are decided by a bare sequence NUMBER — 2 and 4 — and
// that number is a contract with a Postgres function the Dart never sees.
// `auto_generate_trip_waypoints` inserts a fixed six-row ladder, and the
// definition was read off the live project on 2026-08-15:
//
//   1 main_gate · 2 weighbridge · 3 loading_point · 4 weighbridge
//   5 main_gate · 6 drop_off
//
// If that order is ever changed, the first and second weighbridge visits swap
// and the app labels the tare weigh as the gross weigh — silently, because
// both are just `weighbridge`. `kServerWaypointLadder` writes the server's
// sequence down next to the Dart so the divergence has somewhere to fail.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/models/trip_waypoint.dart';

/// The ladder `auto_generate_trip_waypoints` inserts, sequence_order 1..6.
const List<String> kServerWaypointLadder = [
  'main_gate',
  'weighbridge',
  'loading_point',
  'weighbridge',
  'main_gate',
  'drop_off',
];

TripWaypoint wp(int seq, String wire, {double lat = 0, double lng = 0}) =>
    TripWaypoint(
      id: 'wp-$seq',
      tripId: 'trip-1',
      sequenceOrder: seq,
      locationType: WaypointType.parse(wire),
      latitude: lat,
      longitude: lng,
    );

void main() {
  group('WaypointType.parse — tolerant, per the repo wire-enum rule', () {
    test('round-trips every wire value', () {
      for (final t in WaypointType.values) {
        expect(WaypointType.parse(t.wire), t);
      }
    });

    test('normalises case, padding, spaces and hyphens', () {
      expect(WaypointType.parse('MAIN_GATE'), WaypointType.mainGate);
      expect(WaypointType.parse('  loading_point  '), WaypointType.loadingPoint);
      expect(WaypointType.parse('loading point'), WaypointType.loadingPoint);
      expect(WaypointType.parse('loading-point'), WaypointType.loadingPoint);
      expect(WaypointType.parse('Drop-Off'), WaypointType.dropOff);
    });

    test('never throws on an unknown or null value', () {
      expect(() => WaypointType.parse(null), returnsNormally);
      expect(() => WaypointType.parse('helipad'), returnsNormally);
      expect(() => WaypointType.parse(''), returnsNormally);
    });

    test('falls back to dropOff — recorded because it is a lossy default', () {
      // Pinning current behaviour, not endorsing it: an unrecognised stop is
      // presented to the driver as the trip's final destination. If that
      // fallback is ever reconsidered, this is the test that will say so.
      expect(WaypointType.parse('helipad'), WaypointType.dropOff);
      expect(WaypointType.parse(null), WaypointType.dropOff);
    });
  });

  group('the weighbridge visit that decides tare vs gross', () {
    test('the server ladder still says weighbridge at 2 and 4', () {
      expect(kServerWaypointLadder.length, 6);
      expect(kServerWaypointLadder[1], 'weighbridge', reason: 'sequence 2');
      expect(kServerWaypointLadder[3], 'weighbridge', reason: 'sequence 4');
    });

    test('classifies the ladder exactly one tare and one gross', () {
      final ladder = <TripWaypoint>[
        for (var i = 0; i < kServerWaypointLadder.length; i++)
          wp(i + 1, kServerWaypointLadder[i]),
      ];
      expect(ladder.where((w) => w.isTareWeighbridge).map((w) => w.sequenceOrder),
          [2]);
      expect(
          ladder.where((w) => w.isGrossWeighbridge).map((w) => w.sequenceOrder),
          [4]);
    });

    test('a weighbridge at any other sequence is neither', () {
      expect(wp(3, 'weighbridge').isTareWeighbridge, isFalse);
      expect(wp(3, 'weighbridge').isGrossWeighbridge, isFalse);
    });

    test('sequence alone is not enough — the type must match too', () {
      expect(wp(2, 'main_gate').isTareWeighbridge, isFalse);
      expect(wp(4, 'loading_point').isGrossWeighbridge, isFalse);
    });
  });

  group('hasCoordinates — (0,0) means unconfigured, not the Gulf of Guinea', () {
    test('is false only when both are exactly zero', () {
      expect(wp(1, 'main_gate').hasCoordinates, isFalse);
      expect(wp(1, 'main_gate', lat: -26.2).hasCoordinates, isTrue);
      expect(wp(1, 'main_gate', lng: 28.0).hasCoordinates, isTrue);
      expect(wp(1, 'main_gate', lat: -26.2, lng: 28.0).hasCoordinates, isTrue);
    });

    test('the generated drop-off is always a placeholder', () {
      // auto_generate_trip_waypoints inserts row 6 as (0, 0) with no address.
      expect(wp(6, 'drop_off').hasCoordinates, isFalse);
    });
  });

  group('TripWaypoint.fromJson', () {
    test('survives a row with everything missing', () {
      final w = TripWaypoint.fromJson({'id': 'a', 'trip_id': 'b'});
      expect(w.sequenceOrder, 0);
      expect(w.locationType, WaypointType.dropOff);
      expect(w.name, '');
      expect(w.latitude, 0);
      expect(w.isCompleted, isFalse);
      expect(w.completedAt, isNull);
    });

    test('accepts ints where doubles are expected (Postgres numerics)', () {
      final w = TripWaypoint.fromJson({
        'id': 'a',
        'trip_id': 'b',
        'sequence_order': 2,
        'location_type': 'weighbridge',
        'latitude': -26,
        'longitude': 28,
      });
      expect(w.latitude, -26.0);
      expect(w.longitude, 28.0);
      expect(w.isTareWeighbridge, isTrue);
    });

    test('treats a non-true is_completed as not completed', () {
      expect(
          TripWaypoint.fromJson(
              {'id': 'a', 'trip_id': 'b', 'is_completed': null}).isCompleted,
          isFalse);
      expect(
          TripWaypoint.fromJson(
              {'id': 'a', 'trip_id': 'b', 'is_completed': 'yes'}).isCompleted,
          isFalse);
    });

    test('an unparseable timestamp becomes null rather than throwing', () {
      final w = TripWaypoint.fromJson(
          {'id': 'a', 'trip_id': 'b', 'completed_at': 'not a date'});
      expect(w.completedAt, isNull);
    });

    test('toJson round-trips through fromJson', () {
      final original = TripWaypoint(
        id: 'wp-2',
        tripId: 'trip-9',
        sequenceOrder: 4,
        locationType: WaypointType.weighbridge,
        name: 'Weighbridge',
        latitude: -26.2041,
        longitude: 28.0473,
        address: 'Iron Hills',
        isCompleted: true,
        completedAt: DateTime.utc(2026, 8, 15, 9, 30),
      );
      final round = TripWaypoint.fromJson(original.toJson());
      expect(round.id, original.id);
      expect(round.sequenceOrder, original.sequenceOrder);
      expect(round.locationType, original.locationType);
      expect(round.latitude, original.latitude);
      expect(round.address, original.address);
      expect(round.isCompleted, isTrue);
      expect(round.completedAt, original.completedAt);
      expect(round.isGrossWeighbridge, isTrue);
    });
  });

  group('SecurityConfirmation — both parties, or it is not confirmed', () {
    SecurityConfirmation conf({bool driver = false, bool security = false}) =>
        SecurityConfirmation(
          id: 'c1',
          tripId: 't1',
          confirmationType: SecurityConfirmationType.arrival,
          driverConfirmed: driver,
          securityConfirmed: security,
        );

    test('needs both sides', () {
      expect(conf().isFullyConfirmed, isFalse);
      expect(conf(driver: true).isFullyConfirmed, isFalse);
      expect(conf(security: true).isFullyConfirmed, isFalse);
      expect(conf(driver: true, security: true).isFullyConfirmed, isTrue);
    });

    test('type parse round-trips and tolerates junk', () {
      for (final t in SecurityConfirmationType.values) {
        expect(SecurityConfirmationType.parse(t.wire), t);
      }
      expect(SecurityConfirmationType.parse('EXIT'),
          SecurityConfirmationType.exit);
      expect(SecurityConfirmationType.parse('  exit '),
          SecurityConfirmationType.exit);
      // Lossy default, pinned for the same reason as WaypointType's.
      expect(SecurityConfirmationType.parse('departure'),
          SecurityConfirmationType.arrival);
      expect(SecurityConfirmationType.parse(null),
          SecurityConfirmationType.arrival);
    });

    test('fromJson defaults both flags to false on a sparse row', () {
      final c = SecurityConfirmation.fromJson({'id': 'a', 'trip_id': 'b'});
      expect(c.driverConfirmed, isFalse);
      expect(c.securityConfirmed, isFalse);
      expect(c.isFullyConfirmed, isFalse);
      expect(c.confirmationType, SecurityConfirmationType.arrival);
    });

    test('toJson round-trips', () {
      final original = SecurityConfirmation(
        id: 'c9',
        tripId: 't9',
        confirmationType: SecurityConfirmationType.exit,
        driverConfirmed: true,
        securityConfirmed: true,
        driverConfirmedAt: DateTime.utc(2026, 8, 15, 10),
        securityConfirmedAt: DateTime.utc(2026, 8, 15, 10, 5),
        securityUserId: 'u-1',
      );
      final round = SecurityConfirmation.fromJson(original.toJson());
      expect(round.confirmationType, SecurityConfirmationType.exit);
      expect(round.isFullyConfirmed, isTrue);
      expect(round.driverConfirmedAt, original.driverConfirmedAt);
      expect(round.securityUserId, 'u-1');
    });
  });
}
