// A truck is weighed empty, then loaded, then weighed again.
//
// Jean, 2026-08-17: the recorded sequence must be the real one. Before that the
// Load Controller typed the tare and the gross into one sheet and submitted it
// once, so nothing forced two visits to the weighbridge and nothing recorded
// that they happened — and the difference between those two numbers is what the
// whole product bills on.
//
// `MineTrip` decides which half of the sheet is shown, from the trip record
// rather than from local state, so reopening the sheet an hour later resumes
// where it was. These pin that decision and the shape
// `list_mine_inbound_trips` now returns (migration 20260817230000).
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/models/mine_trip.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';

Map<String, dynamic> row({
  String status = 'arrived_at_mine',
  num? tare,
  num? gross,
  num? net,
  String? loadingAt,
}) =>
    {
      'trip_id': '11111111-1111-4111-8111-111111111111',
      'status': status,
      'transaction_id': '22222222-2222-4222-8222-222222222222',
      'seal_required': false,
      'net_tons': net,
      'tare_tons': tare,
      'gross_tons': gross,
      'loading_at': loadingAt,
      'updated_at': '2026-08-17T05:51:31.000Z',
    };

void main() {
  group('the first weigh has not happened', () {
    final t = MineTrip.fromJson(row());

    test('the trip is on site and the sheet asks for the tare', () {
      expect(t.isOnSite, isTrue);
      expect(t.isTareCaptured, isFalse,
          reason: 'nothing has been weighed, so step 1 is what to show');
      expect(t.tareTons, isNull);
      expect(t.loadingAt, isNull);
    });
  });

  group('the truck has been weighed empty and is away loading', () {
    final t = MineTrip.fromJson(row(
      status: 'loading',
      tare: 14.8,
      loadingAt: '2026-08-17T04:12:00.000Z',
    ));

    test('the sheet resumes at the second weigh, from the record', () {
      expect(t.status, TripStatus.loading);
      expect(t.isOnSite, isTrue, reason: 'still at the mine, mid-cycle');
      expect(t.isTareCaptured, isTrue);
      expect(t.tareTons, 14.8);
      expect(t.grossTons, isNull, reason: 'the second weigh has not happened');
    });

    test('the tare time is shown in local time, not UTC', () {
      // The controller reads this against the clock on the wall next to them.
      expect(t.loadingAt, isNotNull);
      expect(t.loadingAt!.isUtc, isFalse);
      expect(t.loadingAt!.toUtc(), DateTime.utc(2026, 8, 17, 4, 12));
    });
  });

  group('both weighs are in', () {
    final t = MineTrip.fromJson(row(
      status: 'loaded',
      tare: 14.8,
      gross: 48.5,
      net: 33.7,
      loadingAt: '2026-08-17T04:12:00.000Z',
    ));

    test('both readings are kept, not just their difference', () {
      expect(t.tareTons, 14.8);
      expect(t.grossTons, 48.5);
      expect(t.netTons, 33.7);
      expect(t.grossTons! - t.tareTons!, closeTo(t.netTons!, 1e-9),
          reason: 'the stored net must be the difference of the two weighs');
    });

    test('it has left the on-site queue', () {
      expect(t.isLoaded, isTrue);
      expect(t.isOnSite, isFalse);
    });
  });

  test('a trip loaded before the split still reads correctly', () {
    // Historical rows have a net and no tare. They must not look like a truck
    // waiting for its first weigh.
    final t = MineTrip.fromJson(row(status: 'completed', net: 35));
    expect(t.netTons, 35);
    expect(t.tareTons, isNull);
    expect(t.isLoaded, isTrue);
    expect(t.isOnSite, isFalse,
        reason: 'a completed trip is never asked to be weighed again');
  });
}
