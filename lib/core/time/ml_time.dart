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
