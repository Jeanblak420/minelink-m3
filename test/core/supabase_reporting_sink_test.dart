import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/telemetry/crash_reporter.dart';
import 'package:flutter_application_1/core/telemetry/supabase_reporting_sink.dart';

CrashReport _r(String message, {bool fatal = false}) => CrashReport(
      error: message,
      stack: StackTrace.current,
      at: DateTime.utc(2026, 8, 19, 12),
      fatal: fatal,
    );

/// Like [_r] but with a controllable timestamp and context — needed to drive
/// the dedup window explicitly rather than relying on the fixed clock above.
CrashReport _rAt(String message, DateTime at, {String? context, bool fatal = false}) =>
    CrashReport(
      error: message,
      stack: StackTrace.current,
      at: at,
      context: context,
      fatal: fatal,
    );

void main() {
  test('posts a reported crash', () async {
    final sent = <Map<String, dynamic>>[];
    final sink = SupabaseReportingSink(
      postBatch: (rows) async => sent.addAll(rows),
    );

    sink.report(_r('boom', fatal: true));
    await sink.flush();

    expect(sent, hasLength(1));
    expect(sent.single['error'], 'boom');
    expect(sent.single['fatal'], isTrue);
    expect(sent.single['at'], '2026-08-19T12:00:00.000Z');
  });

  test('a failing destination does not throw into the caller', () async {
    final sink = SupabaseReportingSink(
      postBatch: (_) async => throw StateError('offline'),
    );

    // report() is what a crash handler calls. If it can throw, it converts a
    // handled error into an uncaught one inside the handler meant to contain
    // it — the exact failure CrashReporter.recordError already guards against.
    expect(() => sink.report(_r('boom')), returnsNormally);
    await expectLater(sink.flush(), completes);
  });

  test('buffers while the destination is down and drains when it recovers',
      () async {
    var fail = true;
    final sent = <Map<String, dynamic>>[];
    final sink = SupabaseReportingSink(postBatch: (rows) async {
      if (fail) throw StateError('offline');
      sent.addAll(rows);
    });

    sink.report(_r('first'));
    sink.report(_r('second'));
    await sink.flush();
    expect(sent, isEmpty, reason: 'destination was down');
    expect(sink.pendingCount, 2, reason: 'nothing may be dropped while down');

    fail = false;
    await sink.flush();
    expect(sent.map((r) => r['error']), ['first', 'second']);
    expect(sink.pendingCount, 0);
  });

  test('an error storm drops oldest-first rather than exhausting memory',
      () async {
    final sink = SupabaseReportingSink(
      postBatch: (_) async => throw StateError('offline'),
      queueLimit: 3,
    );

    for (var i = 0; i < 10; i++) {
      sink.report(_r('e$i'));
    }
    await sink.flush();

    expect(sink.pendingCount, 3);
    expect(sink.pending.map((r) => r['error']), ['e7', 'e8', 'e9']);
  });

  // ── Required by controller Ruling 8 (2026-08-19) ──────────────────────────
  // crash_reports' INSERT policy is `to authenticated`. A genuine pre-auth
  // crash (splash, /login, before any session) runs as the `anon` Postgres
  // role and is REFUSED by RLS. An anon INSERT policy was considered and
  // deliberately rejected: the publishable key ships in every web bundle and
  // APK, so that would be an unauthenticated unmetered write endpoint into a
  // 500 MB free-plan database with a documented outage history.
  //
  // The sink is therefore what covers bootstrap crashes: it must HOLD them
  // and deliver them once the user signs in. That is not a happy accident of
  // the offline buffer -- it is the mitigation, so it gets its own test.
  test('holds a pre-auth crash and delivers it after sign-in', () async {
    var signedIn = false;
    final sent = <Map<String, dynamic>>[];
    final sink = SupabaseReportingSink(postBatch: (rows) async {
      // Stand-in for the RLS refusal an unauthenticated insert really gets.
      if (!signedIn) throw StateError('42501: new row violates row-level security');
      sent.addAll(rows);
    });

    sink.report(_r('crashed on the splash screen'));
    await sink.flush();
    expect(sent, isEmpty);
    expect(sink.pendingCount, 1, reason: 'a bootstrap crash must not be dropped');

    signedIn = true;
    await sink.flush();
    expect(sent.single['error'], 'crashed on the splash screen');
    expect(sink.pendingCount, 0);
  });

  // ── Fix round 1, Critical ──────────────────────────────────────────────
  // flush() used to remove `batch.length` items from the FRONT of the LIVE
  // queue after a successful post, instead of removing the specific reports
  // that were actually sent. If the queue overflows while a post is in
  // flight, overflow eviction removes reports the in-flight batch already
  // snapshotted; the post-success removal then deletes that many items off
  // the front of whatever is left — which, after the eviction, is reports
  // that were never sent. This test drives exactly that interleaving.
  test(
      'an in-flight flush does not let overflow eviction delete an unsent '
      'report', () async {
    final sent = <Map<String, dynamic>>[];
    final releaseFirstPost = Completer<void>();
    var calls = 0;

    final sink = SupabaseReportingSink(
      queueLimit: 3,
      postBatch: (rows) async {
        calls++;
        if (calls == 1) {
          // Block the first post mid-flight so B, C, D can enqueue and
          // overflow the queue while A's send is still outstanding.
          await releaseFirstPost.future;
        }
        sent.addAll(rows);
      },
    );

    // report() synchronously starts flush(), which snapshots [A] and then
    // suspends inside the blocked postBatch call — no explicit wait needed,
    // Dart runs an async function synchronously up to its first await.
    sink.report(_r('A'));

    sink.report(_r('B'));
    sink.report(_r('C'));
    sink.report(_r('D'));
    // Overflow (queueLimit 3, 4 queued) evicts the oldest from the LIVE
    // queue — A — even though A is the one already snapshotted and in
    // flight to be sent.
    expect(sink.pendingCount, 3, reason: 'A was evicted from the live queue');
    expect(sink.pending.map((r) => r['error']), ['B', 'C', 'D']);

    releaseFirstPost.complete();
    await Future<void>.delayed(Duration.zero);

    expect(sent.map((r) => r['error']), ['A'],
        reason: 'only the snapshotted batch was actually sent');
    expect(sink.pendingCount, 3,
        reason: 'B, C and D were never sent and must not be silently '
            'dropped just because A (already-sent) was evicted earlier');

    // Ordering property this all relies on: with no overflow, a drain
    // delivers oldest-first.
    await sink.flush();
    expect(sent.map((r) => r['error']), ['A', 'B', 'C', 'D']);
    expect(sink.pendingCount, 0);
  });

  test('truncates oversized payloads before they leave the device', () async {
    final sent = <Map<String, dynamic>>[];
    final sink = SupabaseReportingSink(postBatch: (rows) async => sent.addAll(rows));

    sink.report(CrashReport(
      error: 'x' * 10000,
      stack: StackTrace.fromString('y' * 40000),
      at: DateTime.utc(2026, 8, 19),
    ));
    await sink.flush();

    expect((sent.single['error'] as String).length, lessThanOrEqualTo(4096));
    expect((sent.single['stack'] as String).length, lessThanOrEqualTo(16384));
  });

  // ── Duplicate collapsing (Task 11b) ────────────────────────────────────
  // `crash_reports` went from 0 to 36 rows in one session, all the same
  // non-fatal ListTile framework advisory, in a 7-second window, 35 of them
  // sharing one millisecond. One list render produced 36 rows because
  // nothing in the sink recognised a repeat.
  group('duplicate collapsing', () {
    test(
        'a burst of identical reports collapses into one row carrying a count',
        () async {
      final sent = <Map<String, dynamic>>[];
      final releaseFirstPost = Completer<void>();
      var calls = 0;
      final sink = SupabaseReportingSink(postBatch: (rows) async {
        calls++;
        // Block the first post so the rest of the burst arrives while the
        // representative row is still "on the device" — the exact
        // interleaving of the real incident, where 35 reports landed
        // before any network round trip could have completed.
        if (calls == 1) await releaseFirstPost.future;
        sent.addAll(rows);
      });

      final at = DateTime.utc(2026, 8, 19, 12, 0, 0, 0);
      for (var i = 0; i < 36; i++) {
        sink.report(_rAt(
          'ListTile background color or ink splashes may be invisible.',
          at,
          context: 'ListTile',
        ));
      }

      expect(sink.pendingCount, 1,
          reason: '36 identical reports in one burst must become one row, '
              'not 36');
      expect(sink.pending.single['error'], endsWith('(x36)'));

      releaseFirstPost.complete();
      await Future<void>.delayed(Duration.zero);

      expect(sent, hasLength(1));
      expect(sent.single['error'], endsWith('(x36)'));
    });

    test('the first occurrence is available immediately, not held back', () {
      // A crash reporter that batches the first report waiting to see if
      // more are coming is worse than one that duplicates — the first
      // occurrence must be visible/flushable the instant it happens.
      final sink = SupabaseReportingSink(postBatch: (_) async {});
      sink.report(_rAt('boom', DateTime.utc(2026, 8, 19)));
      expect(sink.pendingCount, 1);
      expect(sink.pending.single['error'], 'boom',
          reason: 'no count marker on a single, un-duplicated occurrence');
    });

    test('two different errors are not collapsed together', () async {
      final sent = <Map<String, dynamic>>[];
      final sink =
          SupabaseReportingSink(postBatch: (rows) async => sent.addAll(rows));
      final at = DateTime.utc(2026, 8, 19, 12);

      // Different error text, same context.
      sink.report(_rAt('boom A', at, context: 'ctx'));
      await sink.flush();
      // Same error text, different context.
      sink.report(_rAt('boom A', at, context: 'other-ctx'));
      await sink.flush();

      expect(sent, hasLength(2),
          reason: 'fingerprint is context + error text; either differing is '
              'different information and must not be folded together');
      expect(sent.map((r) => r['error']), everyElement(isNot(contains('(x'))));
    });

    test('the same error after the dedup window is a new row', () async {
      final sent = <Map<String, dynamic>>[];
      final sink =
          SupabaseReportingSink(postBatch: (rows) async => sent.addAll(rows));

      final first = DateTime.utc(2026, 8, 19, 12, 0, 0);
      sink.report(_rAt('boom', first, context: 'ctx'));
      await sink.flush();
      expect(sent, hasLength(1));

      final later = first.add(const Duration(seconds: 61));
      sink.report(_rAt('boom', later, context: 'ctx'));
      await sink.flush();

      expect(sent, hasLength(2),
          reason: 'a recurrence outside the dedup window is new information, '
              'not an echo of the first row');
      expect(sent.last['error'], 'boom',
          reason: 'a fresh occurrence must not carry a stale (xN) marker');
    });

    test('the occurrence-count marker never pushes error past 4096 chars',
        () async {
      final sent = <Map<String, dynamic>>[];
      final releaseFirstPost = Completer<void>();
      var calls = 0;
      final sink = SupabaseReportingSink(postBatch: (rows) async {
        calls++;
        if (calls == 1) await releaseFirstPost.future;
        sent.addAll(rows);
      });

      // Longer than _maxErrorChars on its own, so it is already at the 4096
      // ceiling before any "(xN)" marker is considered.
      final longError = 'x' * 5000;
      final at = DateTime.utc(2026, 8, 19, 12);
      for (var i = 0; i < 5; i++) {
        sink.report(_rAt(longError, at));
      }

      final pendingRow = sink.pending.single['error'] as String;
      expect(pendingRow.length, lessThanOrEqualTo(4096));
      expect(pendingRow, endsWith('(x5)'));

      releaseFirstPost.complete();
      await Future<void>.delayed(Duration.zero);

      expect((sent.single['error'] as String).length, lessThanOrEqualTo(4096));
    });
  });
}
