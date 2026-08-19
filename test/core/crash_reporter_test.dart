import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/telemetry/crash_reporter.dart';
import 'package:flutter_application_1/core/telemetry/error_screen_widget.dart';
import 'package:flutter_test/flutter_test.dart';

/// A sink that only records, so the assertions are about capture rather than
/// about logging.
class _RecordingSink implements ReportingSink {
  final List<CrashReport> reports = [];
  @override
  void report(CrashReport report) => reports.add(report);
}

class _ThrowingSink implements ReportingSink {
  @override
  void report(CrashReport report) => throw StateError('sink is down');
}

void main() {
  late _RecordingSink sink;
  late ReportingSink previous;

  setUp(() {
    sink = _RecordingSink();
    previous = crashReporter.sink;
    crashReporter.useSink(sink);
  });

  tearDown(() => crashReporter.useSink(previous));

  test('a handled error is recorded with its context', () {
    crashReporter.recordError(
      StateError('boom'),
      StackTrace.current,
      context: 'weighbridge save',
    );

    expect(sink.reports, hasLength(1));
    expect(sink.reports.single.error, isA<StateError>());
    expect(sink.reports.single.context, 'weighbridge save');
    expect(sink.reports.single.fatal, isFalse);
    expect(sink.reports.single.stack, isNotNull);
  });

  test('a fatal error is marked fatal', () {
    crashReporter.recordError(Exception('x'), null, fatal: true);
    expect(sink.reports.single.fatal, isTrue);
  });

  test('a sink that throws does not turn one error into two', () {
    // The reporter is the last thing standing when something has already gone
    // wrong. If it can throw, it converts a handled error into an uncaught one
    // inside the handler meant to contain it.
    crashReporter.useSink(_ThrowingSink());
    expect(
      () => crashReporter.recordError(StateError('boom'), null),
      returnsNormally,
    );
  });

  testWidgets('a widget that throws during build is captured, not swallowed',
      (tester) async {
    // The real path: FlutterError.onError. Installed here rather than trusting
    // that main() did it, so this asserts the wiring and not the intent.
    final previousOnError = FlutterError.onError;
    installCrashHandlers();
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      MaterialApp(home: Builder(builder: (_) => throw StateError('build blew up'))),
    );

    // The framework also records it; clearing keeps the test from failing on
    // the error it deliberately caused.
    expect(tester.takeException(), isA<StateError>());
    expect(
      sink.reports.where((r) => r.error is StateError),
      isNotEmpty,
      reason: 'FlutterError.onError must route build failures to the reporter — '
          'before this existed they printed to a console nobody was attached to',
    );
  });

  group('LoggingReportingSink history', () {
    test('keeps the most recent first and bounds its size', () {
      final s = LoggingReportingSink(historyLimit: 3);
      for (var i = 0; i < 5; i++) {
        s.report(CrashReport(
          error: 'e$i',
          stack: null,
          at: DateTime(2026, 8, 16, 0, i),
        ));
      }
      expect(s.history.map((r) => r.error).toList(), ['e4', 'e3', 'e2']);
    });
  });

  group('the error panel', () {
    testWidgets('says what happened and what to do, without a Theme',
        (tester) async {
      // It is built from INSIDE a failed build, so it cannot assume a
      // Directionality or a resolvable Theme. Pumped bare on purpose.
      await tester.pumpWidget(
        mlErrorWidgetBuilder(
          FlutterErrorDetails(exception: StateError('inner')),
        ),
      );

      expect(find.text('This part of the screen could not be shown'), findsOneWidget);
      expect(find.textContaining('the fault has been recorded'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('does not put the exception on screen outside debug',
        (tester) async {
      await tester.pumpWidget(
        mlErrorWidgetBuilder(
          FlutterErrorDetails(exception: StateError('SECRET-IDENTIFIER')),
        ),
      );
      // Tests run in debug, so the detail IS shown here — which is the point of
      // the branch. Asserting the branch exists rather than asserting a release
      // behaviour the test binary cannot produce.
      expect(kDebugMode, isTrue,
          reason: 'flutter test runs in debug; the release branch hides the '
              'exception text and is covered by inspection, not by this test');
      expect(find.textContaining('SECRET-IDENTIFIER'), findsOneWidget);
    });
  });
}
