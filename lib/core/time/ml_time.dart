/// One clock for the whole product: **Africa/Johannesburg**.
///
/// Jean's ruling, 2026-08-17, asked for a single basis everywhere. Before it
/// there were three, and they disagreed:
///
///  * **The device.** Every dashboard window, every "today", every day bucket
///    came from `DateTime.now()` and `.toLocal()` — so the numbers depended on
///    how the reader's laptop was configured. A phone left on UTC put a
///    22:30 SAST load on the previous day.
///  * **UTC, in Postgres.** No migration ever set the database timezone, so
///    `current_date` is a UTC calendar day and every boundary that reads it
///    flips at **02:00 SAST** — including the day a twelve-month target cycle
///    starts, and the check that refuses a production entry "in the future".
///  * **UTC, pinned explicitly**, in the four `at time zone 'UTC'` bucket sites.
///
/// A comment in `20260808120000_targets_and_cycles.sql` promised targets and
/// recon "could never disagree" because both were UTC. Recon later moved to
/// `.toLocal()`; the promise was quietly void, and nothing said so.
///
/// ## Why a fixed offset and not the `timezone` package
///
/// South Africa is **UTC+02:00 and has never observed daylight saving**, so the
/// offset is a constant, not a rule that needs a database of transitions.
/// `Duration(hours: 2)` is exact here and stays exact. That is worth stating
/// plainly because the shortcut is only safe for this one zone: **if MineLink
/// ever operates outside South Africa, this file is the one place to change,
/// and it must become a real timezone lookup rather than a bigger constant.**
///
/// ## What the returned DateTime is
///
/// [sast] returns a DateTime whose *fields* (`.year`, `.month`, `.day`,
/// `.hour`) are the South African wall clock, flagged non-UTC so `DateFormat`
/// prints them as-is. It is a wall clock, not an instant — do not send one back
/// to the server. Use [toServer] for that, which re-derives the true UTC
/// instant.
library;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:intl/intl.dart' show DateFormat;
import 'package:flutter_application_1/core/utils/ml_count.dart';

/// South Africa's offset from UTC. Fixed, and no daylight saving.
const Duration kSastOffset = Duration(hours: 2);

/// The South African wall clock, for display and for day boundaries.
abstract final class MlTime {
  /// [instant] as it reads on a clock in South Africa.
  ///
  /// Accepts a UTC or a local DateTime and normalises through UTC first, so the
  /// answer does not depend on the device's own zone.
  static DateTime sast(DateTime instant) {
    final utc = instant.toUtc();
    return DateTime(
      utc.year,
      utc.month,
      utc.day,
      utc.hour,
      utc.minute,
      utc.second,
      utc.millisecond,
      utc.microsecond,
    ).add(kSastOffset);
  }

  /// Nullable [sast], for the many `DateTime?` columns.
  static DateTime? sastOrNull(DateTime? instant) =>
      instant == null ? null : sast(instant);

  /// The instant [now] is measured from. `null` means the real one.
  ///
  /// Set it in a test and the WHOLE PRODUCT's clock freezes, because every
  /// "today", every window edge and every displayed time in this app already
  /// comes through here — that is the point of §7.1, and this is the dividend.
  ///
  /// Written for the render harness. A golden of the driver's navigation screen
  /// prints an ETA — a real clock time — so the image changed every minute and
  /// the comparison could never pass twice. Any screen with a relative date,
  /// a rolling window or a countdown has the same problem; one hook settles all
  /// of them rather than each one growing its own injectable clock.
  ///
  /// **Never set outside a test.** Nothing in `lib/` writes it.
  @visibleForTesting
  static DateTime Function()? debugClock;

  /// Now, on the South African wall clock.
  static DateTime now() => sast(debugClock?.call() ?? DateTime.now());

  /// Now, as the real **instant** in UTC — for measuring a DURATION, never for
  /// display.
  ///
  /// [now] is a wall clock flagged non-UTC, so its `millisecondsSinceEpoch`
  /// depends on the reader's device offset. Subtracting a server timestamp from
  /// it is therefore wrong everywhere except South Africa, which is the one
  /// place nobody would notice. Anything that computes "how long is left" wants
  /// this instead.
  ///
  /// It honours [debugClock], which is the other half of why it exists: the
  /// organisations registry printed a token countdown straight off
  /// `DateTime.now()`, so its golden read `102d 09h left` in the morning and
  /// `102d 08h left` an hour later. A render that cannot be reproduced is not
  /// evidence of anything, and it fails the suite for whoever runs it next.
  static DateTime instant() => (debugClock?.call() ?? DateTime.now()).toUtc();

  /// Midnight today, South African. The start of every "today" in the product.
  static DateTime today() => startOfDay(now());

  /// Midnight on the day [wallClock] falls in.
  ///
  /// Takes a value already in SAST — pass [sast] output, not a raw server
  /// instant, or the day will be a UTC one wearing a South African label.
  static DateTime startOfDay(DateTime wallClock) =>
      DateTime(wallClock.year, wallClock.month, wallClock.day);

  /// The `YYYY-MM-DD` a server `date` column should receive for [wallClock].
  ///
  /// `DateTime.toIso8601String().substring(0, 10)` on a device-local value is
  /// how a load recorded at 01:00 SAST got filed under the previous day: the
  /// truncation silently used whatever zone the object happened to be in.
  static String dateParam(DateTime wallClock) =>
      '${wallClock.year.toString().padLeft(4, '0')}-'
      '${wallClock.month.toString().padLeft(2, '0')}-'
      '${wallClock.day.toString().padLeft(2, '0')}';

  /// How long ago [instant] was, in ONE vocabulary for the whole product.
  ///
  /// ```
  ///   just now      under a minute
  ///   N min ago     under an hour
  ///   N h ago       under a day
  ///   yesterday     exactly one day
  ///   N days ago    under a week
  ///   3 Aug         older, same calendar year
  ///   3 Aug 2025    older still
  /// ```
  ///
  /// ## Why this exists
  ///
  /// There were **nine** hand-rolled copies of this in `lib/` and they agreed
  /// on almost nothing. Six vocabularies for the same idea — `5m ago` and
  /// `5 min ago`; `3h ago` and `3 h ago`; `2d ago`, `2 d ago` and `2 days ago`
  /// — three different "just now" thresholds (45s, 60s, one minute), one screen
  /// with a `yesterday` and eight without, and three different date fallbacks
  /// (`13/8/2026`, `13 Aug`, `13 Aug`). A reader moving between the console's
  /// audit log and its live map was reading two dialects of the same sentence.
  ///
  /// **And six of the nine read `DateTime.now()`** — the DEVICE's opinion of
  /// the hour, which CLAUDE.md §7.1 exists to keep out of anything a user
  /// reads. The audit log is the one where it showed: rendered against a frozen
  /// clock its newest three entries — 22 minutes, 3 hours and 9 hours old —
  /// all printed **"5d ago"**, because the subtraction was against the real
  /// wall clock and not against the data. On a handset with a wrong date it
  /// does the same thing to a real admin, on the screen whose entire job is
  /// saying when something happened.
  ///
  /// [asOf] is for callers that already hold a reference instant (a "data
  /// fetched at" stamp, a table rendering every row against one moment) so
  /// every row in one paint agrees. It defaults to [instant]'s own clock.
  static String ago(DateTime at, {DateTime? asOf}) {
    final d = (asOf?.toUtc() ?? MlTime.instant()).difference(at.toUtc());
    // A timestamp in the future is a clock disagreement, not a negative age.
    if (d.isNegative || d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    if (d.inDays == 1) return 'yesterday';
    // `mlCount`, even though the branch above already returned for
    // `== 1`: the `count-without-plural-agreement` guard cannot see a
    // guard clause, and a site that is only correct because of the line
    // above it is one edit away from not being.
    if (d.inDays < 7) return '${mlCount(d.inDays, 'day')} ago';
    final on = sast(at);
    final now = sast(asOf ?? MlTime.instant());
    return on.year == now.year
        ? _dayMonth.format(on)
        : _dayMonthYear.format(on);
  }

  /// [ago] for a column too narrow for a sentence: `now`, `5m`, `3h`, `2d`.
  ///
  /// Past a week it falls back to the same date [ago] uses, because `412d` is
  /// not more informative than `3 Aug 2025` and is harder to read. The two
  /// forms therefore never disagree about WHEN something happened, only about
  /// how much room they take to say it.
  static String agoTag(DateTime at, {DateTime? asOf}) {
    final d = (asOf?.toUtc() ?? MlTime.instant()).difference(at.toUtc());
    if (d.isNegative || d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return ago(at, asOf: asOf);
  }

  /// A full timestamp a reader can act on: `15 Aug 2026 · 09:30`.
  ///
  /// ONE vocabulary, and the reason it has to be one is the same reason [ago]
  /// does. Counted 2026-08-21 across `lib/`, a moment in time was written
  /// SEVEN different ways:
  ///
  ///     dd MMM yyyy · HH:mm      7 sites
  ///     MMM d, yyyy, h:mm a      the chat dock
  ///     MMM d, yyyy • h:mm a     a bullet instead of a middot
  ///     MMM d • h:mm a           no year
  ///     MMM d · h:mm a           a middot again, still no year
  ///     d MMM · HH:mm            2 sites
  ///     yyyy-MM-dd HH:mm:ss      the audit log
  ///
  /// plus `MaterialLocalizations.formatShortDate` on the trip detail, which is
  /// the reader's LOCALE — so an American buyer's screen said `8/15/2026` and
  /// a South African one `15/08/2026` for the same load.
  ///
  /// Four of those put the month first and used a 12-hour clock, in a product
  /// whose every other surface is day-first and 24-hour and whose §7.1 rule
  /// exists because a printed waybill once carried the wrong DATE.
  ///
  /// The trip detail was worse than inconsistent. It formatted the DATE from
  /// the raw UTC instant and the TIME from [sast], so a trip updated at 01:30
  /// SAST — 23:30 UTC the previous day — printed the previous day's date
  /// beside 01:30. Exactly the fault §7.1 was written for, on the screen that
  /// says when a load moved.
  ///
  /// Takes the INSTANT, not a wall clock: it converts. Held by the
  /// `one-vocabulary-for-a-timestamp` release guard.
  static String stamp(DateTime instant) => _stamp.format(sast(instant));

  /// [stamp] without the time — `15 Aug 2026`.
  static String day(DateTime instant) => _dayMonthYear.format(sast(instant));

  /// A compact day for a LIST — `15 Aug`, or `10 Feb 2025` when the date is
  /// not in the current South African year.
  ///
  /// The year is the part that cannot be dropped unconditionally. A mine's
  /// "Recent waybills" card printed `dd MMM` for every row, and its last two
  /// rows read "28 Jan" then "10 Feb" — correctly sorted, because the second
  /// is 2025, and completely unreadable as such. A list that can span a year
  /// boundary has to say when it does.
  ///
  /// [asOf] is for tests and for a caller that has already resolved "now";
  /// it defaults to the product's clock, never the device's.
  static String listDay(DateTime instant, {DateTime? asOf}) {
    final local = sast(instant);
    final today = asOf == null ? now() : sast(asOf);
    return local.year == today.year
        ? _dayMonth.format(local)
        : _dayMonthYear.format(local);
  }

  /// [stamp] without the date — `09:30`. For a column whose rows are already
  /// grouped by day.
  static String clock(DateTime instant) => _clock.format(sast(instant));

  /// A value that is ALREADY a calendar date, formatted as it stands.
  ///
  /// [day] converts, and converting twice moves a date. Three kinds of value
  /// in this product have already been converted, or never were an instant at
  /// all:
  ///
  ///   * a Postgres `date` column. Supabase returns `2026-08-15`, and
  ///     `DateTime.parse` on a string with no zone gives **device-local
  ///     midnight** — `TransportationRequest.startingDate` and `endingDate`
  ///     are these.
  ///   * a `showDatePicker` result, which is likewise a local midnight the
  ///     user chose on a calendar.
  ///   * a model that ran [sast] at parse time. `MaintenanceRecord` and
  ///     `ServiceSchedule` both do (`MlTime.sastOrNull`), so their fields are
  ///     South African wall clocks before any screen sees them.
  ///
  /// Handing any of those to [day] adds two more hours: a wall clock at 23:00
  /// becomes 01:00 the next day, and the date on screen moves. That is the
  /// exact failure §7.1 exists to prevent, arrived at from the other side.
  static String calendarDay(DateTime dateOnly) => _dayMonthYear.format(dateOnly);

  /// [stamp] for a value already on the South African clock — see
  /// [calendarDay] for which those are.
  static String calendarStamp(DateTime wallClock) => _stamp.format(wallClock);

  // ZERO-PADDED, and that is the majority spelling rather than a preference:
  // eighteen sites in `lib/` already write `dd MMM yyyy` and seven write
  // `dd MMM yyyy · HH:mm`. `ago`'s own fallback was the odd one out at
  // `d MMM yyyy`, so a list mixing "yesterday" with "3 Aug 2026" disagreed
  // with the table beside it saying "03 Aug 2026". A padded day also lines up
  // in a column, which is where most of these live.
  static final DateFormat _dayMonth = DateFormat('dd MMM');
  static final DateFormat _dayMonthYear = DateFormat('dd MMM yyyy');
  static final DateFormat _stamp = DateFormat('dd MMM yyyy · HH:mm');
  static final DateFormat _clock = DateFormat('HH:mm');

  /// Turn a South African wall clock back into the instant it names.
  ///
  /// The inverse of [sast]. Use this for anything written back to the server —
  /// a wall clock posted as if it were UTC lands two hours early, which is a
  /// live bug in several write paths today.
  static DateTime toServer(DateTime wallClock) => DateTime.utc(
        wallClock.year,
        wallClock.month,
        wallClock.day,
        wallClock.hour,
        wallClock.minute,
        wallClock.second,
        wallClock.millisecond,
        wallClock.microsecond,
      ).subtract(kSastOffset);

  /// [wallClock] as the ISO-8601 string a `timestamptz` filter should receive.
  ///
  /// Every window edge in the product used to reach Postgres as
  /// `DateTime(y, m, 1).toIso8601String()` — a **naive** string with no offset,
  /// which Postgres then reads in the session zone (UTC). So "the 1st at 00:00"
  /// arrived meaning 02:00 SAST, and the month window was two hours late at
  /// both ends. This carries the offset, so the filter means what it says.
  static String serverParam(DateTime wallClock) =>
      toServer(wallClock).toIso8601String();

  /// True when the two instants fall on the same South African day.
  static bool sameDay(DateTime a, DateTime b) {
    final x = sast(a);
    final y = sast(b);
    return x.year == y.year && x.month == y.month && x.day == y.day;
  }
}
