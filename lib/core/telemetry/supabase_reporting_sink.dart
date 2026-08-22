/// Ships crash reports to `public.crash_reports` on the main Supabase project.
///
/// This is the one file that names a destination. [ReportingSink] is the whole
/// vendor surface (see `crash_reporter.dart`), and adopting a different one
/// means writing another implementation of it and changing one line in
/// `main()`. Nothing else in the app refers to a destination.
///
/// ## The three properties that matter more than delivery
///
/// 1. **[report] cannot throw.** It is called from inside crash handlers. A
///    sink that throws converts a handled error into an uncaught one inside
///    the handler meant to contain it.
/// 2. **A sink failure is never itself reported.** That is an unbounded loop
///    which takes the app down harder than the bug that started it. Sink
///    errors go to `debugPrint` and nowhere else — the same deliberate silence
///    as `CrashReporter.recordError`.
/// 3. **It buffers offline and drains on recovery.** The crashes worth seeing
///    are disproportionately the ones on a truck with no signal.
///
/// ## Duplicate collapsing
///
/// `crash_reports` went from 0 to 36 rows in one session, all the identical
/// non-fatal `ListTile` framework advisory, inside a 7-second window, 35 of
/// them sharing one millisecond — one list render, 36 rows. Neither `report`
/// nor `flush` had any notion of "this is the same failure as the one still
/// sitting in the queue", so every repeat became its own insert.
///
/// [report] now fingerprints on `context` + the already-truncated `error`
/// text (see [_clip]) and, while the first occurrence's row has not yet left
/// the device, folds further occurrences into it — bumping a trailing
/// `(xN)` marker on the `error` field — instead of enqueueing a new row.
/// `crash_reports` has no `occurrences` column and this deliberately does not
/// add one: a migration for a marker a human reads in a text column is more
/// machinery than the problem needs. The marker is re-derived from the
/// clipped-but-unmarked text every time (never appended to an
/// already-marked string), and is bounded so `(xN)` can never push the
/// stored `error` past the `crash_reports_error_length` CHECK (`<= 4096`,
/// see `_maxErrorChars`) — see `_withCount`.
///
/// Collapsing never delays the FIRST occurrence: the very first report for a
/// fingerprint is enqueued and flushed exactly as before. Only a genuine
/// repeat — arriving while the representative row is still pending — is
/// folded in. See [_dedupWindow] for how long a fingerprint stays open.
///
/// ## The send budget, and why collapsing was not enough
///
/// 🚨 **Collapsing bounds repeats only while a row has not been sent.** The
/// paragraph above says so, and the note on [_dedupWindow] called that
/// "almost entirely the offline case". Online it is the whole failure:
/// `flush()` posts immediately, the representative leaves [_pending], and the
/// very next identical occurrence has nothing to fold into and starts a fresh
/// row. The rate of ROWS is then the rate of occurrences divided by however
/// many happen to arrive during one network round trip — which is not a
/// bound at all.
///
/// This was measured, not reasoned about. On 2026-08-22 three browser tabs
/// left signed in overnight hit a CanvasKit `Aborted()` failure during
/// `paint()` and re-threw it on every frame for four hours. They wrote
/// **204,539 rows — 293 MB** into a `crash_reports` table this file's own doc
/// describes as having reached 36 rows. Main is a 500 MB free-plan project
/// (CLAUDE.md §10.2): it went from 24 MB to 319 MB, 59% of the ceiling, on
/// telemetry about one bug. Peak was 60,680 rows in a single hour.
///
/// Two details make that incident immune to fingerprinting, which is why the
/// bound has to be on rows rather than on repeats:
///
///   * `Bad state: RenderBox was not laid out: minified:aAN#5ab90` carries a
///     per-instance object hash. It changed three times over the four hours,
///     so each spell was a different fingerprint.
///   * A fold writes ` (xN)` into the stored text, so the rows that DID reach
///     Postgres are spread across `(x31)`, `(x32)`, `(x33)` — each one a
///     separate row that folded ~32 occurrences before its flush completed.
///     The folding worked perfectly and still let 17,809 rows through.
///
/// So [report] now also spends from a budget, and the budget is on rows
/// LEAVING THE DEVICE, across every fingerprint:
///
///   * [_maxRowsPerWindow] rows per [_rateWindow], and
///   * [_maxRowsPerSession] rows in the life of this sink, ever.
///
/// Nothing is silently dropped: occurrences the budget refuses are counted,
/// and the count rides out on the next row that IS sent, as
/// `(+N not sent)`. The magnitude survives even though the rows do not.
/// Under those bounds the incident above costs at most 500 rows per tab
/// instead of 204,539 — and the first twenty seconds of it, which is the part
/// that actually tells you what broke, are unaffected.
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/telemetry/crash_reporter.dart';

/// Caps, applied before anything leaves the device.
///
/// Main is a 500 MB free-plan project and an error loop can generate reports
/// faster than anyone reads them. A truncated stack is still actionable; an
/// exhausted database is not.
const int _maxErrorChars = 4096;
const int _maxStackChars = 16384;

String _clip(String s, int max) =>
    s.length <= max ? s : '${s.substring(0, max - 3)}...';

/// How long a burst of identical reports collapses into one row.
///
/// ## Why 60 seconds
///
/// The incident this exists for was 35 identical rows sharing one
/// millisecond and a 7-second total span — a single list render re-asserting
/// the same advisory on every frame. 60s comfortably absorbs that (and a much
/// laggier repeat of it) while staying short enough that a genuinely
/// recurring failure a few minutes apart still gets its own row: the same
/// error 10 minutes later is a fact about the app's current health, not an
/// echo of the first one, and collapsing it away would hide a real pattern
/// (e.g. "this keeps happening on every checkout") behind a single stale row.
///
/// ## Why this only bounds the OFFLINE case in practice
///
/// Dedup only folds a duplicate into an existing row while that row is still
/// sitting in [SupabaseReportingSink._pending] — i.e. it has not been sent
/// yet. Online, a flush typically completes in well under this window, so
/// the practical effect of the window is almost entirely: *while the
/// destination is unreachable*, do not let one wedged row silently keep
/// absorbing an unbounded amount of recurrence forever. Once it lapses, the
/// next occurrence starts a fresh representative row with its own window.
const Duration _dedupWindow = Duration(seconds: 60);

/// The send budget. See the library doc for the incident that set these.
///
/// **20 rows a minute** leaves the first seconds of a real crash fully
/// reported — a genuine fault rarely produces twenty DISTINCT failures in a
/// minute, and repeats are collapsed before they ever reach the budget — while
/// making a per-frame loop cost one row every three seconds instead of
/// thirteen a second.
///
/// **500 rows per session** is the backstop, and it is the one that actually
/// bounds the damage: a client can never write more than about 700 KB no
/// matter how long it is left running or how fast it fails. Five hundred
/// distinct reports in one session already says more than the five hundred
/// and first would.
///
/// Both are counted against the incoming report's own `at`, never the wall
/// clock, so this is testable without faking time — the same choice
/// [_dedupWindow] makes and for the same reason.
const Duration _rateWindow = Duration(minutes: 1);
const int _maxRowsPerWindow = 20;
const int _maxRowsPerSession = 500;

/// Builds the `error` value a row actually stores: the clipped text, plus an
/// occurrence marker when repeats were folded into it, plus a note when the
/// send budget refused rows in the run-up to this one.
///
/// Composed from the UNMARKED text every time — never from a previously
/// composed string — so re-stamping a row as more occurrences fold in
/// produces `(x2)`, `(x3)`, ... rather than `(x2) (x3)`, and can never
/// duplicate or lose the suppressed note.
///
/// Re-clips if needed so no marker can push the result past [_maxErrorChars],
/// the exact bound `crash_reports_error_length` enforces in Postgres.
String composeErrorText(String clippedError, {int count = 1, int notSent = 0}) {
  final marker = StringBuffer();
  if (count > 1) marker.write(' (x$count)');
  if (notSent > 0) marker.write(' (+$notSent not sent)');
  final suffix = marker.toString();
  if (suffix.isEmpty) return clippedError;
  if (clippedError.length + suffix.length <= _maxErrorChars) {
    return '$clippedError$suffix';
  }
  final keep = _maxErrorChars - suffix.length;
  final base = keep <= 3 ? '' : '${clippedError.substring(0, keep - 3)}...';
  return '$base$suffix';
}

class SupabaseReportingSink implements ReportingSink {
  SupabaseReportingSink({
    Future<void> Function(List<Map<String, dynamic>> rows)? postBatch,
    this.queueLimit = 50,
    String? appVersion,
  }) : _postBatch = postBatch ?? _defaultPost,
       _appVersion = appVersion;

  /// Injected so the queueing and truncation rules can be tested without a
  /// live database — which is the half most likely to be wrong.
  final Future<void> Function(List<Map<String, dynamic>> rows) _postBatch;

  final int queueLimit;
  final String? _appVersion;

  /// Each queued report carries a monotonic id so a completed post can
  /// remove EXACTLY the reports it sent — never "however many were sent",
  /// which is wrong the moment the live queue has been mutated (a new
  /// report arriving, or overflow eviction) while the send was in flight.
  /// See the regression test `an in-flight flush does not let overflow
  /// eviction delete an unsent report` for the exact interleaving this
  /// guards against.
  final Queue<_PendingReport> _pending = Queue<_PendingReport>();
  int _nextId = 0;
  bool _draining = false;

  /// One open dedup group per fingerprint (`context` + clipped `error`).
  /// See the class doc for why this exists and [_dedupWindow] for the bound.
  final Map<String, _DedupEntry> _dedup = <String, _DedupEntry>{};

  /// When each row was CREATED, oldest first, pruned to [_rateWindow].
  /// Rows, not occurrences — a fold costs nothing, because it does not add a
  /// row.
  final Queue<DateTime> _rowTimes = Queue<DateTime>();

  /// Rows this sink has created since it was constructed, and occurrences the
  /// budget refused since the last row that got through.
  int _rowsThisSession = 0;
  int _notSent = 0;

  /// Set once the session ceiling is reached, after the one row that says so.
  bool _budgetSpent = false;

  int get pendingCount => _pending.length;

  /// Occurrences the budget has refused and not yet accounted for on a row.
  /// Exposed so a test can prove nothing is being silently thrown away.
  int get notSentCount => _notSent;

  /// Rows created since construction, for the same reason.
  int get rowsThisSession => _rowsThisSession;
  List<Map<String, dynamic>> get pending =>
      List.unmodifiable(_pending.map((p) => p.row));

  static Future<void> _defaultPost(List<Map<String, dynamic>> rows) =>
      SupabaseConfig.client.from('crash_reports').insert(rows);

  static String get _platform {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  /// Best-effort — never lets a missing/uninitialized auth state stop the
  /// report itself from being queued. Isolated from the `try` in [report] on
  /// purpose: `SupabaseConfig.client` throws until `Supabase.initialize()` has
  /// run (true in unit tests, and momentarily true in production before
  /// `_initializeApplication()` reaches the point that swaps this sink in),
  /// and that must degrade to "no user id" rather than drop the whole report.
  static String? _currentUserId() {
    try {
      return SupabaseConfig.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  @override
  void report(CrashReport r) {
    try {
      // Prune dedup groups whose window has lapsed, using the incoming
      // report's own timestamp as "now". Deterministic (no wall-clock
      // dependence, so this is testable without faking time) and it is what
      // keeps `_dedup` bounded over a long session with many distinct
      // one-off errors: a fingerprint with no activity in the last
      // [_dedupWindow] is dropped rather than held forever.
      _dedup.removeWhere(
        (_, e) => r.at.difference(e.firstAt).abs() > _dedupWindow,
      );

      final clippedError = _clip(r.error.toString(), _maxErrorChars);
      final fingerprint = '${r.context ?? ''} $clippedError';

      final existing = _dedup[fingerprint];
      _PendingReport? representative;
      if (existing != null) {
        for (final p in _pending) {
          if (p.id == existing.pendingId) {
            representative = p;
            break;
          }
        }
      }

      if (existing != null &&
          representative != null &&
          r.at.difference(existing.firstAt).abs() <= _dedupWindow) {
        // A genuine repeat of a report whose row has not left the device
        // yet: fold it into that row instead of adding a new one. The count
        // is re-derived from the clipped-but-unmarked text every time, so
        // repeated folding never compounds markers like "(x2) (x3)".
        existing.count++;
        representative.count = existing.count;
        representative.row['error'] = composeErrorText(
          representative.baseError,
          count: representative.count,
          notSent: representative.notSent,
        );
        // The representative may have been enqueued while offline; nudge a
        // flush in case connectivity has since returned. Harmless to call
        // again if one is already in flight — flush() no-ops while draining.
        unawaited(flush());
        return;
      }

      // Either the first time this fingerprint has been seen, or the
      // previous representative already left the device (sent, or evicted
      // by overflow), or the window lapsed — in every case this occurrence
      // needs its own row, and a row is what the budget is denominated in.
      //
      // Everything above this line is free: a fold changes an existing row and
      // costs nothing. Only from here does an occurrence become a write.
      if (_budgetSpent) {
        _notSent++;
        return;
      }

      _rowTimes.removeWhere((t) => r.at.difference(t).abs() > _rateWindow);
      if (_rowTimes.length >= _maxRowsPerWindow) {
        _notSent++;
        return;
      }

      final id = _nextId++;
      final atTheCeiling = _rowsThisSession + 1 >= _maxRowsPerSession;
      final baseError = atTheCeiling
          ? 'Crash reporting stopped for this session: '
                '$_maxRowsPerSession reports is the per-session ceiling. '
                'Further errors are still handled, just not sent. '
                'Last one was: $clippedError'
          : clippedError;

      final row = _PendingReport(
        id,
        <String, dynamic>{
          'user_id': _currentUserId(),
          'at': r.at.toUtc().toIso8601String(),
          'platform': _platform,
          'app_version': _appVersion,
          'error': null, // composed below, so there is one code path for it
          'stack': r.stack == null
              ? null
              : _clip(r.stack.toString(), _maxStackChars),
          'context': r.context,
          'fatal': r.fatal,
        },
        baseError: _clip(baseError, _maxErrorChars),
        notSent: _notSent,
      );
      row.row['error'] = composeErrorText(row.baseError, notSent: row.notSent);
      _pending.addLast(row);
      _notSent = 0;
      _rowTimes.addLast(r.at);
      _rowsThisSession++;
      if (atTheCeiling) _budgetSpent = true;

      // A ceiling row is a statement about the sink, not a recurrence of the
      // error that triggered it, so it is deliberately NOT registered as a
      // dedup representative: nothing should ever fold into it.
      if (!atTheCeiling) {
        _dedup[fingerprint] = _DedupEntry(pendingId: id, firstAt: r.at);
      }

      // Oldest-first: during a storm the newest reports are the ones still
      // describing the live state of the app.
      while (_pending.length > queueLimit) {
        _pending.removeFirst();
      }
      unawaited(flush());
    } catch (e) {
      // See property 2 above. Never report this.
      debugPrint('SupabaseReportingSink.report failed: $e');
    }
  }

  /// Attempts to send everything queued. Never throws.
  Future<void> flush() async {
    if (_draining || _pending.isEmpty) return;
    _draining = true;
    final batch = _pending.toList(growable: false);
    try {
      await _postBatch(batch.map((p) => p.row).toList(growable: false));
      // Remove exactly the reports that were sent, by id — not "the first
      // N", which would be wrong if the queue's shape changed while this
      // post was in flight (new reports arriving, or overflow eviction
      // dropping one of the reports this very batch already snapshotted).
      final sentIds = batch.map((p) => p.id).toSet();
      _pending.removeWhere((p) => sentIds.contains(p.id));
    } catch (e) {
      debugPrint(
        'SupabaseReportingSink.flush failed, ${_pending.length} held: $e',
      );
    } finally {
      _draining = false;
    }
  }
}

class _PendingReport {
  _PendingReport(
    this.id,
    this.row, {
    required this.baseError,
    this.notSent = 0,
  });

  final int id;
  final Map<String, dynamic> row;

  /// The clipped, UNMARKED error text. Kept so [composeErrorText] can be
  /// re-run from the original every time a fold bumps the count, rather than
  /// appending to a string that already carries a marker.
  final String baseError;

  /// Occurrences the send budget refused before this row was created. Rides
  /// out with it so the magnitude of a suppressed burst is not lost.
  final int notSent;

  int count = 1;
}

/// Tracks one open dedup group: which pending row is the representative for
/// a fingerprint, when the group started (for [_dedupWindow]), and how many
/// occurrences have been folded into it so far.
class _DedupEntry {
  _DedupEntry({required this.pendingId, required this.firstAt});

  final int pendingId;
  final DateTime firstAt;
  int count = 1;
}
