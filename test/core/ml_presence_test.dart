// One presence rule, measured on the product's clock.
//
// Every assertion here passes an INSTANT and freezes `MlTime.debugClock`, which
// is the whole point: the four private copies this replaced measured with
// `DateTime.now()` against values that had already been converted to a South
// African wall clock, so the answer depended on the reader's device offset —
// and on the render harness's frozen clock not reaching it. The register
// photographed the result on 2026-08-21: a row reading "Last seen 11 min ago"
// beside a counter reading AWAY 0.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/presence/ml_presence.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

void main() {
  final now = DateTime.utc(2026, 8, 15, 9, 30);

  setUp(() => MlTime.debugClock = () => now);
  tearDown(() => MlTime.debugClock = null);

  group('mlPresenceOf', () {
    test('membership of the live set wins over any stamp', () {
      expect(
        mlPresenceOf(
          online: true,
          dbLastSeen: now.subtract(const Duration(days: 400)),
        ),
        MlPresence.online,
      );
    });

    test('inside the away window is away', () {
      expect(
        mlPresenceOf(
            online: false, dbLastSeen: now.subtract(const Duration(minutes: 11))),
        MlPresence.away,
      );
    });

    test('the window edge itself is still away', () {
      expect(
        mlPresenceOf(online: false, dbLastSeen: now.subtract(kPresenceAwayWindow)),
        MlPresence.away,
      );
    });

    test('one second past the window is offline', () {
      expect(
        mlPresenceOf(
          online: false,
          dbLastSeen:
              now.subtract(kPresenceAwayWindow + const Duration(seconds: 1)),
        ),
        MlPresence.offline,
      );
    });

    test('never seen at all is offline, not away', () {
      expect(mlPresenceOf(online: false), MlPresence.offline);
    });

    // The exact shape of the old bug. A South African wall clock read on a
    // device that is not in South Africa lands in the FUTURE, and
    // `now.difference(future) <= 30 minutes` is trivially true — so EVERYBODY
    // was "Away", including someone last seen a year ago.
    test('a stamp in the future is a clock disagreement, not recent activity',
        () {
      expect(
        mlPresenceOf(
            online: false, dbLastSeen: now.add(const Duration(hours: 2))),
        MlPresence.offline,
      );
    });

    test('it measures against the product clock, not the device', () {
      // `asOf` and `debugClock` must agree; if `mlPresenceOf` reached for
      // `DateTime.now()` this would be offline (the real date is not 2026).
      expect(
        mlPresenceOf(
            online: false, dbLastSeen: now.subtract(const Duration(minutes: 5))),
        MlPresence.away,
      );
    });

    test('asOf pins a whole list to one moment', () {
      final asOf = now.subtract(const Duration(days: 1));
      expect(
        mlPresenceOf(
          online: false,
          dbLastSeen: asOf.subtract(const Duration(minutes: 5)),
          asOf: asOf,
        ),
        MlPresence.away,
      );
    });
  });

  group('mlLastSeen', () {
    final db = now.subtract(const Duration(hours: 3));
    final live = now.subtract(const Duration(minutes: 2));

    test('takes the newer of the two', () {
      expect(mlLastSeen(dbLastSeen: db, liveLastSeen: live), live);
      expect(mlLastSeen(dbLastSeen: live, liveLastSeen: db), live);
    });

    test('either alone', () {
      expect(mlLastSeen(dbLastSeen: db), db);
      expect(mlLastSeen(liveLastSeen: live), live);
    });

    // `live ?? dbLastSeen` — the chat dock's old fold — reported the moment
    // somebody LEFT the tab in preference to a newer database heartbeat.
    test('a stale live stamp does not beat a newer database heartbeat', () {
      expect(
        mlLastSeen(
          dbLastSeen: now.subtract(const Duration(minutes: 1)),
          liveLastSeen: now.subtract(const Duration(hours: 6)),
        ),
        now.subtract(const Duration(minutes: 1)),
      );
    });

    test('neither', () {
      expect(mlLastSeen(), isNull);
    });
  });
}
