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
      expect(MlTime.sast(instant), MlTime.sast(instant.toLocal().toUtc()));
    });

    test('it REFUSES a value that is not an instant', () {
      // The whole reason the answer cannot depend on the device zone: a wall
      // clock never gets in. `sast` returns a NON-UTC DateTime by design (so
      // `DateFormat` prints it as-is), which makes a second conversion look
      // exactly like a first one — the identity on a South African machine and
      // two hours out everywhere else. Six sites in the recon table, including
      // the export of the billing record, and three in the console were doing
      // it undetected until this assert existed.
      final alreadySast = MlTime.sast(DateTime.utc(2026, 8, 17, 5, 51));
      expect(alreadySast.isUtc, isFalse);
      expect(() => MlTime.sast(alreadySast), throwsA(isA<AssertionError>()));
      expect(() => MlTime.sast(DateTime(2026, 8, 17, 7, 51)),
          throwsA(isA<AssertionError>()));

      // And the `calendar*` family is the way to render one, without
      // converting it again.
      expect(MlTime.calendarClock(alreadySast), '07:51');
      expect(MlTime.calendarDay(alreadySast), '17 Aug 2026');
      expect(MlTime.calendarStamp(alreadySast), '17 Aug 2026 · 07:51');
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

  group('stamp, day and clock', () {
    // 23:29 UTC on the 16th is 01:29 on the 17th at the mine. This is THE case
    // CLAUDE.md §7.1 exists for — a printed waybill once carried
    // "DATE 2026-08-16 · TIME 23:29" for a hand-off at 01:29 on the 17th — and
    // it is the case the trip-detail screen got wrong from the other
    // direction, formatting the DATE off the raw instant while formatting the
    // TIME through `sast`.
    final crossesMidnight = DateTime.utc(2026, 8, 16, 23, 29);

    test('a stamp is the South African day AND the South African hour', () {
      expect(MlTime.stamp(crossesMidnight), '17 Aug 2026 · 01:29');
    });

    test('day and clock are the two halves of the same stamp', () {
      expect(MlTime.day(crossesMidnight), '17 Aug 2026');
      expect(MlTime.clock(crossesMidnight), '01:29');
      expect(
        MlTime.stamp(crossesMidnight),
        '${MlTime.day(crossesMidnight)} · ${MlTime.clock(crossesMidnight)}',
      );
    });

    test("the day is zero-padded, and agrees with ago's own fallback", () {
      final early = DateTime.utc(2026, 8, 3, 9, 0);
      expect(MlTime.day(early), '03 Aug 2026');
      expect(
        MlTime.ago(early, asOf: DateTime.utc(2027, 1, 1)),
        contains('03 Aug'),
      );
    });

    test('a stamp never reads the device clock', () {
      // No debugClock set: the answer must depend only on the argument.
      expect(MlTime.day(DateTime.utc(2026, 1, 1)), '01 Jan 2026');
    });
  });

  group('calendarDay — the value that has already been converted', () {
    test('it does NOT convert again', () {
      // A model that ran `MlTime.sast` at parse time hands out a wall clock —
      // `MaintenanceRecord` and `ServiceSchedule` both do. An hour before
      // midnight is the case that moves: convert it twice and the date on
      // screen becomes tomorrow.
      final wallClock = MlTime.sast(DateTime.utc(2026, 8, 16, 21, 30));
      expect(wallClock.hour, 23);
      expect(MlTime.calendarDay(wallClock), '16 Aug 2026');
      // The FIELDS are what it reads, whatever flag they arrive wearing.
      expect(MlTime.calendarDay(DateTime.utc(2026, 8, 16, 23, 30)),
          '16 Aug 2026');

      // What `day` would do to the same value is deliberately NOT asserted
      // here, and the reason is worth writing down: `sast` normalises through
      // `toUtc()`, and `toUtc()` on a non-UTC DateTime uses THE MACHINE'S
      // zone. On a developer machine already running SAST the second
      // conversion cancels out and the wrong call gives the right answer; on a
      // UTC machine the same expression returns 17 Aug. It is the failure mode
      // this file's own header warns about — "the one place nobody would
      // notice" — so a test asserting it would pass or fail by geography.
    });

    test('a Postgres date column keeps its own day', () {
      // Supabase returns "2026-08-15" for a `date`, and `DateTime.parse` on a
      // string with no zone gives DEVICE-LOCAL midnight — so it must not be
      // routed through a converter either.
      final dateOnly = DateTime.parse('2026-08-15');
      expect(MlTime.calendarDay(dateOnly), '15 Aug 2026');
    });

    test('calendarStamp is the same rule with a time on it', () {
      final wallClock = MlTime.sast(DateTime.utc(2026, 8, 16, 21, 30));
      expect(MlTime.calendarStamp(wallClock), '16 Aug 2026 · 23:30');
    });

    group('listDay', () {
      final asOf = DateTime.utc(2026, 8, 15, 9, 30);

      test('drops the year inside the current one', () {
        expect(MlTime.listDay(DateTime.utc(2026, 1, 28, 5, 55), asOf: asOf),
            '28 Jan');
      });

      test('KEEPS the year outside it', () {
        // The whole point. A mine's "Recent waybills" card ended "28 Jan"
        // then "10 Feb" — correctly sorted, because the second is 2025, and
        // unreadable as such. Remove the year branch and this row reads
        // "10 Feb", one line under "28 Jan", in a list sorted newest first.
        expect(MlTime.listDay(DateTime.utc(2025, 2, 10, 8, 5), asOf: asOf),
            '10 Feb 2025');
      });

      test('the year boundary is decided on the SOUTH AFRICAN clock', () {
        // 31 Dec 2025 22:30 UTC is 1 Jan 2026 00:30 in Johannesburg. Read as
        // UTC this is last year and would carry a year it does not need.
        expect(MlTime.listDay(DateTime.utc(2025, 12, 31, 22, 30), asOf: asOf),
            '01 Jan');
      });
    });

    group('listStamp', () {
      // 22 Aug 2026, 10:47 in Johannesburg.
      final asOf = DateTime.utc(2026, 8, 22, 8, 47);

      test('today is the time of day', () {
        expect(MlTime.listStamp(DateTime.utc(2026, 8, 22, 8, 10), asOf: asOf),
            '10:10');
        expect(MlTime.listStamp(DateTime.utc(2026, 8, 22, 2, 51), asOf: asOf),
            '04:51');
      });

      test('another day is the DATE, not a bare time', () {
        // The load controller's Recent Loads, measured on live data. Three
        // rows sorted newest first read 10:10, 04:51 and 13:39 — out of order,
        // and the only thing that explained it was that the third load was six
        // days old and nothing on screen said so.
        expect(MlTime.listStamp(DateTime.utc(2026, 8, 16, 11, 39), asOf: asOf),
            '16 Aug');
      });

      test('another year keeps the year, exactly as listDay does', () {
        expect(MlTime.listStamp(DateTime.utc(2025, 2, 10, 8, 5), asOf: asOf),
            '10 Feb 2025');
      });

      test('the day boundary is the SOUTH AFRICAN one', () {
        // 21 Aug 22:30 UTC is 00:30 on the 22nd at the pit, so it is TODAY and
        // reads as a time. Bucketed on the UTC day it would print "21 Aug",
        // which is the §7.1 fault this whole file exists for.
        expect(MlTime.listStamp(DateTime.utc(2026, 8, 21, 22, 30), asOf: asOf),
            '00:30');
        // And 22 Aug 22:30 UTC is 00:30 on the 23rd — tomorrow at the pit, so
        // it is NOT today and must carry its date.
        expect(MlTime.listStamp(DateTime.utc(2026, 8, 22, 22, 30), asOf: asOf),
            '23 Aug');
      });
    });
  });
}
