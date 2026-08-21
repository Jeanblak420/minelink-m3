// Freeze the product's clock at the instant the fixtures are stamped from.
//
// ## The failure this ends
//
// `kCaptureNow` is a fixed instant — `2026-08-15 09:30Z` — and every capture
// fixture dates its rows relative to it (`_ago(Duration(days: 2))`). The
// product's rolling windows are measured from `MlTime.now()`, which is the
// REAL clock. So a test that pumps a capture fixture without freezing the
// clock is asserting on an arithmetic that changes with the calendar.
//
// It goes off silently and late. `recon_table_legibility_test.dart` asserted a
// period total of `103.22 t` and passed every day until **2026-08-21**, when
// the wall clock walked a fixture row out of the seven-day window and the
// figure became something else. Nothing about the test or the product had
// changed; the date had.
//
// Twelve test files were in that position when this was written. The render
// harness was not — it has frozen the clock since the driver's ETA made every
// golden differ by the minute, and the reasoning there is the same one:
//
//   > `kCaptureNow` is the same instant the portal fixtures are stamped from,
//   > so "5 days ago" in a render means five days from the data beside it.
//
// ## Use
//
// ```dart
// setUpAll(() async {
//   freezeCaptureClock();
//   ...
// });
// ```
//
// Held by the `capture-fixture-without-a-frozen-clock` release guard, so a new
// test cannot pick up the fixtures and inherit the flake.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/time/ml_time.dart';

import '../fixtures/portal_capture_fixtures.dart' show kCaptureNow;

/// Pins `MlTime.now()` to [kCaptureNow] for the rest of the file.
///
/// Registers its own teardown, so a file that calls this cannot leak a frozen
/// clock into whatever runs next in the same process.
void freezeCaptureClock() {
  MlTime.debugClock = () => kCaptureNow;
  addTearDown(() => MlTime.debugClock = null);
}
