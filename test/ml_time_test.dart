// One clock: Africa/Johannesburg.
//
// These assert the SAST wall clock explicitly rather than "is not UTC", so they
// mean the same thing on a developer's machine, on CI, and on a laptop somebody
// left on UTC. That is the whole point of having a basis: the answer must not
// depend on who is looking.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

void main() {
  group('sast', () {
    test('a UTC instant reads as the South African wall clock', () {
      // The measured waybill defect: loaded_at 05:51 UTC printed as 05:51 while
      // the clock at the mine said 07:51.
      final w = MlTime.sast(DateTime.utc(2026, 8, 17, 5, 51, 31));
      expect(w.hour, 7);
      expect(w.minute, 51);
      expect(w.day, 17);
      expect(w.isUtc, isFalse, reason: 'it is a wall clock, ready to format');
    });

    test('it crosses the date line the right way', () {
      // 23:29 UTC on the 16th is 01:29 on the 17th at the mine. The completed
      // waybill printed DATE 2026-08-16 for a hand-off that happened on the
      // 17th — a whole day out on the document governing the delivery.
      final w = MlTime.sast(DateTime.utc(2026, 8, 16, 23, 29));
      expect(w.day, 17);
      expect(w.month, 8);
      expect(w.hour, 1);
      expect(w.minute, 29);
    });

    test('the answer does not depend on the device zone', () {
      final instant = DateTime.utc(2026, 8, 17, 5, 51);
      // Same instant, expressed two ways. A device-dependent implementation
      // would give different wall clocks for these.
      expect(MlTime.sast(instant), MlTime.sast(instant.toLocal()));
    });

    test('no daylight saving — midwinter and midsummer are both +02:00', () {
      expect(MlTime.sast(DateTime.utc(2026, 1, 15, 12)).hour, 14);
      expect(MlTime.sast(DateTime.utc(2026, 7, 15, 12)).hour, 14);
    });
  });

  group('day boundaries', () {
    test('a load at 00:30 SAST belongs to that day, not the one before', () {
      // 22:30 UTC on the 16th. Under the old UTC `current_date` this fell on
      // the 16th; on the pit's clock it is the 17th, and the 17th is the day
      // the driver, the supervisor and the recon row all mean.
      final day = MlTime.startOfDay(MlTime.sast(DateTime.utc(2026, 8, 16, 22, 30)));
      expect(day, DateTime(2026, 8, 17));
    });

    test('01:59 and 02:01 SAST are the same day', () {
      // 02:00 SAST is where the UTC calendar flipped. Nothing should happen
      // there any more.
      final a = MlTime.startOfDay(MlTime.sast(DateTime.utc(2026, 8, 16, 23, 59)));
      final b = MlTime.startOfDay(MlTime.sast(DateTime.utc(2026, 8, 17, 0, 1)));
      expect(a, b);
      expect(a, DateTime(2026, 8, 17));
    });

    test('sameDay compares on the pit clock', () {
      expect(
        MlTime.sameDay(
            DateTime.utc(2026, 8, 16, 22, 30), DateTime.utc(2026, 8, 17, 5, 0)),
        isTrue,
      );
      expect(
        MlTime.sameDay(
            DateTime.utc(2026, 8, 16, 21, 30), DateTime.utc(2026, 8, 17, 5, 0)),
        isFalse,
      );
    });
  });

  group('writing back', () {
    test('dateParam files the load under the pit day', () {
      // `toIso8601String().substring(0, 10)` on a device-local value is how a
      // production entry made just after midnight got filed under yesterday.
      final w = MlTime.sast(DateTime.utc(2026, 8, 16, 22, 30));
      expect(MlTime.dateParam(w), '2026-08-17');
    });

    test('toServer is the exact inverse of sast', () {
      final instant = DateTime.utc(2026, 8, 17, 5, 51, 31, 286);
      expect(MlTime.toServer(MlTime.sast(instant)), instant);
    });

    test('a wall clock posted as UTC would land two hours early', () {
      // The failure toServer exists to prevent, stated as a fact rather than a
      // warning: this is what several write paths do today.
      final w = MlTime.sast(DateTime.utc(2026, 8, 17, 5, 51));
      final wrong = DateTime.utc(w.year, w.month, w.day, w.hour, w.minute);
      expect(MlTime.toServer(w).isBefore(wrong), isTrue);
      expect(wrong.difference(MlTime.toServer(w)), kSastOffset);
    });
  });

  group('serverParam', () {
    test('a window edge carries its offset instead of arriving naive', () {
      // The insights month window: 1 August, 00:00 at the mine.
      final edge = MlTime.serverParam(DateTime(2026, 8, 1));
      expect(edge, '2026-07-31T22:00:00.000Z');
      // What it used to send — the same digits, no offset, read by Postgres as
      // UTC. Two hours late at both ends of every month.
      expect(DateTime(2026, 8, 1).toIso8601String(), '2026-08-01T00:00:00.000');
    });

    test('it round-trips through sast', () {
      final wall = MlTime.sast(DateTime.utc(2026, 8, 17, 5, 51));
      expect(DateTime.parse(MlTime.serverParam(wall)).toUtc(),
          DateTime.utc(2026, 8, 17, 5, 51));
    });
  });

  test('sastOrNull passes null through', () {
    expect(MlTime.sastOrNull(null), isNull);
    expect(MlTime.sastOrNull(DateTime.utc(2026, 8, 17, 5))!.hour, 7);
  });

  // ------------------------------------------------------------------------
  // instant() — the real UTC instant, for durations
  // ------------------------------------------------------------------------
  group('instant', () {
    test('it is an instant, not a wall clock', () {
      // `now()` is SAST FIELDS flagged non-UTC. Subtracting a server timestamp
      // from it is off by the reader's own offset everywhere except South
      // Africa. `instant()` is the thing to subtract.
      MlTime.debugClock = () => DateTime.utc(2026, 8, 17, 5, 51);
      addTearDown(() => MlTime.debugClock = null);
      expect(MlTime.instant(), DateTime.utc(2026, 8, 17, 5, 51));
      expect(MlTime.instant().isUtc, isTrue);
      // The wall clock says 07:51 for the same moment. Both are right; they
      // answer different questions.
      expect(MlTime.now().hour, 7);
    });

    test('it honours debugClock, which is what makes a render reproducible',
        () {
      MlTime.debugClock = () => DateTime.utc(2026, 1, 1);
      addTearDown(() => MlTime.debugClock = null);
      expect(MlTime.instant().year, 2026);
      expect(MlTime.instant().month, 1);
    });
  });

  // ------------------------------------------------------------------------
  // ago() / agoTag() — ONE vocabulary, replacing nine
  // ------------------------------------------------------------------------
  //
  // There were nine hand-rolled copies of this in `lib/`, six of them reading
  // `DateTime.now()`. The one that showed was the console's audit log: rendered
  // against a frozen clock, its newest three entries — 22 minutes, 3 hours and
  // 9 hours old — all printed "5d ago", because the subtraction was against the
  // real wall clock rather than against the data.
  group('ago', () {
    // Fixed so the thresholds are asserted, not sampled.
    final now = DateTime.utc(2026, 8, 21, 12, 0);
    String at(Duration d) => MlTime.ago(now.subtract(d), asOf: now);

    test('the whole ladder', () {
      expect(at(const Duration(seconds: 5)), 'just now');
      expect(at(const Duration(seconds: 59)), 'just now');
      expect(at(const Duration(minutes: 1)), '1 min ago');
      expect(at(const Duration(minutes: 59)), '59 min ago');
      expect(at(const Duration(hours: 1)), '1 h ago');
      expect(at(const Duration(hours: 23)), '23 h ago');
      expect(at(const Duration(days: 1)), 'yesterday');
      expect(at(const Duration(days: 2)), '2 days ago');
      expect(at(const Duration(days: 6)), '6 days ago');
    });

    test('past a week it names the day, in this year and in another', () {
      // 21 Aug minus 8 days is 13 Aug, and 12:00 UTC is 14:00 SAST — the same
      // calendar day either way, so this is not a date-line case.
      expect(at(const Duration(days: 8)), '13 Aug');
      expect(at(const Duration(days: 400)), '17 Jul 2025');
    });

    test('a timestamp in the FUTURE is a clock disagreement, not a negative age',
        () {
      // Server and device disagree by a few seconds all the time. "-3 min ago"
      // is not a thing to show anybody.
      expect(MlTime.ago(now.add(const Duration(minutes: 3)), asOf: now),
          'just now');
    });

    test('the date it falls back to is the SOUTH AFRICAN day', () {
      // 23:29 UTC on the 16th is 01:29 on the 17th at the mine — the exact
      // date-line case that put a printed waybill a day out.
      expect(
        MlTime.ago(DateTime.utc(2026, 8, 16, 23, 29),
            asOf: DateTime.utc(2026, 8, 30, 12)),
        '17 Aug',
      );
    });

    test('with no asOf it reads the frozen clock, not the device', () {
      MlTime.debugClock = () => now;
      addTearDown(() => MlTime.debugClock = null);
      expect(MlTime.ago(now.subtract(const Duration(minutes: 22))),
          '22 min ago');
    });
  });

  group('agoTag', () {
    final now = DateTime.utc(2026, 8, 21, 12, 0);
    String at(Duration d) => MlTime.agoTag(now.subtract(d), asOf: now);

    test('the compact ladder', () {
      expect(at(const Duration(seconds: 30)), 'now');
      expect(at(const Duration(minutes: 22)), '22m');
      expect(at(const Duration(hours: 9)), '9h');
      expect(at(const Duration(days: 3)), '3d');
    });

    test('past a week it agrees with the sentence form', () {
      // Never "412d". The two forms differ in length, never in WHEN.
      expect(at(const Duration(days: 400)), '17 Jul 2025');
      expect(at(const Duration(days: 400)),
          MlTime.ago(now.subtract(const Duration(days: 400)), asOf: now));
    });
  });
}
