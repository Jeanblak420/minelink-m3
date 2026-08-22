// A crash reporter must not be able to fill the database it reports into.
//
// On 2026-08-22 three browser tabs left signed in overnight hit a CanvasKit
// `Aborted()` during paint() and re-threw it every frame for four hours. They
// wrote **204,539 rows / 293 MB** into `public.crash_reports`, taking the main
// production project — a 500 MB free plan — from 24 MB to 319 MB. Peak was
// 60,680 rows in one hour.
//
// The sink already had duplicate collapsing, and it worked. It just does not
// bound this, and its own doc said so before the incident: a fold only happens
// while the representative row is STILL IN THE QUEUE. Online, `flush()` posts
// straight away, the representative leaves, and the next occurrence starts a
// fresh row. The row rate is then (occurrence rate ÷ occurrences per round
// trip), which is not a bound.
//
// Two properties of the real burst put it beyond fingerprinting altogether,
// which is why the fix has to count ROWS rather than repeats:
//
//   * `RenderBox was not laid out: minified:aAN#5ab90` carries a per-instance
//     object hash, and it changed three times over the four hours.
//   * The rows that landed are spread over `(x31)`, `(x32)`, `(x33)` — each
//     one had folded ~32 occurrences before its own flush finished. Collapsing
//     did its job and 17,809 rows still got through.
//
// So these tests drive the sink the way production drove it — ONLINE, with the
// post completing between occurrences — and require the row count to stay
// bounded regardless.
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/telemetry/crash_reporter.dart';
import 'package:flutter_application_1/core/telemetry/supabase_reporting_sink.dart';

/// The budget, restated here so a change to it fails a test that names the
/// number rather than silently re-deriving it from the code under test.
const int kMaxRowsPerWindow = 20;
const int kMaxRowsPerSession = 500;

final _t0 = DateTime.utc(2026, 8, 22, 2, 54, 33);

CrashReport _at(String message, Duration since, {String? context}) =>
    CrashReport(
      error: message,
      stack: StackTrace.current,
      at: _t0.add(since),
      context: context,
      fatal: false,
    );

/// A sink whose post always succeeds immediately — i.e. ONLINE, which is the
/// state the sink was never bounded in.
({SupabaseReportingSink sink, List<Map<String, dynamic>> sent}) _online() {
  final sent = <Map<String, dynamic>>[];
  final sink = SupabaseReportingSink(
    postBatch: (rows) async => sent.addAll(rows),
  );
  return (sink: sink, sent: sent);
}

void main() {
  test('the real incident: a per-frame loop no longer writes a row per frame',
      () async {
    final t = _online();

    // Four hours at ~13 rows/second was the measured rate. Simulating four
    // hours literally would be 187,000 iterations, so this runs the same
    // SHAPE at the same rate for six minutes of simulated time: 60 Hz frames,
    // each re-throwing during paint, with the minified object hash rotating
    // the way the real one did so fingerprinting cannot save us.
    const frames = 6 * 60 * 60; // six minutes at 60 fps
    for (var i = 0; i < frames; i++) {
      final hash = ['5ab90', 'df4a8', 'ba514'][(i ~/ 1200) % 3];
      t.sink.report(_at(
        'Bad state: RenderBox was not laid out: minified:aAN#$hash',
        Duration(milliseconds: i * 1000 ~/ 60),
        context: 'during paint()',
      ));
      // Online: the post completes between frames, so the representative is
      // gone and there is nothing to fold into. This one await is what makes
      // the test reproduce the incident instead of the offline case.
      await Future<void>.delayed(Duration.zero);
    }
    await t.sink.flush();

    // Six simulated minutes, twenty rows a minute. Before the budget this
    // wrote a row per frame that could not fold — thousands.
    expect(t.sent.length, lessThanOrEqualTo(6 * kMaxRowsPerWindow + 1),
        reason: '21,600 frames must not become 21,600 rows');
    expect(t.sent.length, greaterThan(0),
        reason: 'and it must still report the failure at all');

    // Nothing was silently dropped: the magnitude rode out on the rows.
    final withCounts = t.sent
        .map((r) => r['error'] as String)
        .where((e) => e.contains('not sent'))
        .toList();
    expect(withCounts, isNotEmpty,
        reason: 'refused occurrences must be accounted for on a later row');
  });

  test('at most twenty rows leave the device in any one minute', () async {
    final t = _online();

    // A hundred DISTINCT errors inside one minute — distinct so that duplicate
    // collapsing cannot be what bounds this. Only the budget can.
    for (var i = 0; i < 100; i++) {
      t.sink.report(_at('distinct failure $i', Duration(milliseconds: i * 500)));
      await Future<void>.delayed(Duration.zero);
    }
    await t.sink.flush();

    expect(t.sent, hasLength(kMaxRowsPerWindow));
    expect(t.sink.notSentCount, 80);
  });

  test('the window is rolling, so a later minute reports again', () async {
    final t = _online();

    for (var i = 0; i < 100; i++) {
      t.sink.report(_at('early failure $i', Duration(milliseconds: i * 100)));
      await Future<void>.delayed(Duration.zero);
    }
    final afterFirstMinute = t.sent.length;

    // Ten minutes later the app fails again. This must be reported — a sink
    // that goes deaf after one bad minute is worse than one that floods.
    t.sink.report(_at('a completely new failure', const Duration(minutes: 10)));
    await t.sink.flush();

    expect(t.sent.length, afterFirstMinute + 1);
    expect(t.sent.last['error'], contains('a completely new failure'));
  });

  test('refused occurrences are counted onto the next row that gets through',
      () async {
    final t = _online();

    for (var i = 0; i < 25; i++) {
      t.sink.report(_at('failure $i', Duration(milliseconds: i * 100)));
      await Future<void>.delayed(Duration.zero);
    }
    // 20 sent, 5 refused.
    expect(t.sent, hasLength(kMaxRowsPerWindow));
    expect(t.sink.notSentCount, 5);

    // The next minute opens the window again; the first row through carries
    // what was missed.
    t.sink.report(_at('the next one', const Duration(minutes: 2)));
    await t.sink.flush();

    expect(t.sent.last['error'], 'the next one (+5 not sent)');
    expect(t.sink.notSentCount, 0, reason: 'the debt is settled by that row');
  });

  test('the session ceiling stops reporting, and says so once', () async {
    final t = _online();

    // Spread far enough apart that the per-minute window never binds, so the
    // SESSION ceiling is unambiguously the thing being tested.
    for (var i = 0; i < kMaxRowsPerSession + 50; i++) {
      t.sink.report(_at('failure $i', Duration(seconds: i * 10)));
      await Future<void>.delayed(Duration.zero);
    }
    await t.sink.flush();

    expect(t.sent, hasLength(kMaxRowsPerSession));
    expect(t.sink.rowsThisSession, kMaxRowsPerSession);

    // The last row explains the silence rather than just stopping.
    final last = t.sent.last['error'] as String;
    expect(last, contains('Crash reporting stopped for this session'));
    expect(last, contains('$kMaxRowsPerSession'));
    expect(last, contains('failure ${kMaxRowsPerSession - 1}'),
        reason: 'and still names the error that hit the ceiling');

    // And it is genuinely stopped, not merely throttled.
    final before = t.sent.length;
    t.sink.report(_at('long afterwards', const Duration(hours: 3)));
    await t.sink.flush();
    expect(t.sent.length, before);
    expect(t.sink.notSentCount, greaterThan(0));
  });

  test('the first seconds of a real crash are untouched by any of this',
      () async {
    final t = _online();

    // What a genuine fault looks like: a handful of distinct failures in the
    // first moments. Every one of them must arrive — the budget exists to stop
    // a loop, not to ration the report that matters.
    for (var i = 0; i < 8; i++) {
      t.sink.report(_at('genuine distinct failure $i',
          Duration(milliseconds: i * 120)));
      await Future<void>.delayed(Duration.zero);
    }
    await t.sink.flush();

    expect(t.sent, hasLength(8));
    for (final row in t.sent) {
      expect(row['error'], isNot(contains('not sent')));
    }
  });

  test('a fold is free — collapsing repeats does not spend the budget',
      () async {
    final sent = <Map<String, dynamic>>[];
    // Offline-ish: the post never completes, so the representative stays in
    // the queue and every repeat folds into it. That must cost ONE row.
    final sink = SupabaseReportingSink(
      postBatch: (_) async => throw StateError('offline'),
    );

    for (var i = 0; i < 200; i++) {
      sink.report(_at('the same failure', Duration(milliseconds: i * 10),
          context: 'during paint()'));
    }

    expect(sink.rowsThisSession, 1,
        reason: '200 folded occurrences are one row, so one unit of budget');
    expect(sink.pending.single['error'], 'the same failure (x200)');
    expect(sent, isEmpty);
  });
}
