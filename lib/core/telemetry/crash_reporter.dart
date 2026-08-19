/// Where uncaught errors go.
///
/// ## Why this exists
///
/// Before it, the app had **no global error handling of any kind** — measured,
/// not assumed: `FlutterError.onError`, `PlatformDispatcher.instance.onError`,
/// `runZonedGuarded` and `ErrorWidget.builder` all returned zero hits across
/// `lib/`. In a release build that means:
///
/// * an uncaught async error printed to a console nobody is attached to, and
///   was gone;
/// * a widget that threw during build showed the user Flutter's grey error box;
/// * nothing anywhere retained a record of either.
///
/// So the first anyone heard of a failure was the client phoning, with nothing
/// to look at when they did (S9-1).
///
/// ## What is deliberately NOT decided here
///
/// **Which telemetry vendor to use is the client's call** and is the `ASK` on
/// S9-1. This file is the seam, not the answer: capturing errors and shipping
/// them somewhere are separate problems, and only the first one is engineering.
/// [ReportingSink] is the whole vendor surface — adopting Sentry, Crashlytics
/// or a self-hosted endpoint means writing one implementation of it and one
/// line in `main()`. Nothing else in the app refers to a vendor.
///
/// The default sink logs and keeps the recent history in memory, which is
/// strictly better than the previous nothing and commits to no one.
library;

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:flutter_application_1/core/utils/logger.dart';

/// One captured failure.
@immutable
class CrashReport {
  const CrashReport({
    required this.error,
    required this.stack,
    required this.at,
    this.context,
    this.fatal = false,
  });

  final Object error;
  final StackTrace? stack;
  final DateTime at;

  /// Where it happened, in words a support conversation can use — the widget
  /// library's own description, or a caller-supplied label.
  final String? context;

  /// True for an error that reached the top of the app rather than one a
  /// screen caught and handled.
  final bool fatal;

  @override
  String toString() =>
      '[${at.toIso8601String()}] ${fatal ? 'FATAL ' : ''}'
      '${context == null ? '' : '$context: '}$error';
}

/// The vendor surface. One implementation per destination.
abstract class ReportingSink {
  void report(CrashReport report);
}

/// The default: log it, and keep the last [historyLimit] in memory.
///
/// The in-memory history is the half that matters while there is no vendor. It
/// turns "the app did something odd this morning" into a list somebody can
/// read, which is exactly what was missing when the client phoned.
class LoggingReportingSink implements ReportingSink {
  LoggingReportingSink({this.historyLimit = 50});

  static final _log = LoggerFactory.getLogger('Crash');

  final int historyLimit;
  final Queue<CrashReport> _history = Queue<CrashReport>();

  /// Most recent first.
  List<CrashReport> get history => _history.toList().reversed.toList();

  @override
  void report(CrashReport r) {
    _history.addLast(r);
    while (_history.length > historyLimit) {
      _history.removeFirst();
    }
    _log.e(
      '${r.fatal ? 'Uncaught' : 'Handled'}'
      '${r.context == null ? '' : ' in ${r.context}'}',
      r.error,
      r.stack,
    );
  }
}

/// The process-wide reporter.
class CrashReporter {
  CrashReporter(this._sink);

  ReportingSink _sink;

  /// Swap the destination — the one line a vendor adoption touches.
  void useSink(ReportingSink sink) => _sink = sink;

  ReportingSink get sink => _sink;

  void recordError(
    Object error,
    StackTrace? stack, {
    String? context,
    bool fatal = false,
  }) {
    // A reporter that can throw is worse than no reporter: it would turn a
    // handled error into an uncaught one, inside the very handler meant to
    // contain it.
    try {
      _sink.report(CrashReport(
        error: error,
        stack: stack,
        at: DateTime.now(),
        context: context,
        fatal: fatal,
      ));
    } catch (_) {
      // Nothing useful is left to do — the destination is the thing that
      // failed. Deliberately silent, and the only empty catch in the app that
      // is correct.
      debugPrint('CrashReporter sink threw while reporting: $error');
    }
  }
}

/// The single instance the app reports through.
final CrashReporter crashReporter = CrashReporter(LoggingReportingSink());

/// Routes every framework and platform error into [crashReporter].
///
/// Call once from `main()`, before `runApp`. Returns nothing and cannot fail:
/// installing telemetry must never be the reason an app does not start.
void installCrashHandlers({
  Widget Function(FlutterErrorDetails details)? errorWidgetBuilder,
}) {
  // Errors the widget framework catches — build, layout, paint.
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    // `FlutterErrorDetails.silent` (default `false`) is the framework's own
    // verdict on whether a diagnostic is worth surfacing outside debug mode —
    // e.g. the HTTP library sets it on expected-in-the-wild errors like a 404
    // so they don't flood a release console. Respect that verdict here too,
    // rather than forwarding every detail unconditionally: it is a real,
    // structural signal from the code that raised the error, not a guess.
    //
    // This is NOT what stopped the `crash_reports` flood on its own — the
    // ListTile background-color advisory that produced all 36 rows is raised
    // with the default `silent: false` (it is asserted only inside debug/
    // profile builds, but it does not mark itself silent), so it still
    // reaches here and is still reported. Collapsing THAT flood is what the
    // dedup in `SupabaseReportingSink` is for; this check only stops the
    // separate, real class of diagnostics that already opt out.
    if (!details.silent) {
      crashReporter.recordError(
        details.exception,
        details.stack,
        context: details.context?.toDescription(),
        fatal: false,
      );
    }
    // Keep the default behaviour (it prints in debug) rather than replacing it.
    previousOnError?.call(details);
  };

  // Errors that reach the engine with no Dart handler — the async ones that
  // used to vanish entirely.
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    crashReporter.recordError(error, stack, fatal: true);
    return true; // handled: do not also crash the isolate
  };

  if (errorWidgetBuilder != null) {
    ErrorWidget.builder = errorWidgetBuilder;
  }
}

/// Runs [body] inside a guarded zone so uncaught async errors are captured too.
///
/// `PlatformDispatcher.onError` covers most of them on modern Flutter; this
/// catches what escapes a zone boundary. Both are installed because the cost of
/// double-reporting one error is a duplicate line, and the cost of missing one
/// is the failure nobody hears about.
void runGuarded(void Function() body) {
  runZonedGuarded(body, (error, stack) {
    crashReporter.recordError(error, stack, fatal: true);
  });
}
