// Crash reports (admin phone audit, 2026-10-24): the header said "500
// fingerprints" \u2014 the length of the newest-500 page \u2014 over 9,243 reports,
// and nothing showed that nothing had arrived since 17 Oct.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/telemetry/crash_reporter.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/data/models/models.dart';
import 'package:flutter_application_1/features/super_admin/data/repositories/super_admin_repository.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/screens/crash_reports_screen.dart';

class _Capture implements ReportingSink {
  final reports = <CrashReport>[];
  @override
  void report(CrashReport r) => reports.add(r);
}

/// A server that has received whatever the capture sink was given.
class _EchoRepo extends SuperAdminRepository {
  _EchoRepo(this.capture)
      : super(SupabaseClient('http://crash.test', 'anon',
            authOptions: const AuthClientOptions(autoRefreshToken: false)));
  final _Capture capture;
  @override
  Future<List<CrashReportRow>> getCrashReports({
    bool fatalOnly = false,
    String? platform,
    String? appVersion,
    int limit = 500,
  }) async => [
        for (final r in capture.reports)
          CrashReportRow.fromJson({
            'id': 'echo', 'user_id': null, 'at': r.at.toUtc().toIso8601String(),
            'platform': 'android', 'app_version': '1.0.0', 'error': '${r.error}',
            'stack': null, 'fatal': false,
            'created_at': r.at.toUtc().toIso8601String(),
          }),
      ];
}

CrashReportRow _row(int i) => CrashReportRow.fromJson({
      'id': 'r$i',
      'user_id': null,
      'at': DateTime.utc(2026, 10, 17, 17, 43).subtract(Duration(minutes: i)).toIso8601String(),
      'platform': 'android',
      'app_version': '1.0.0',
      'error': 'Duplicate GlobalKey detected in widget tree.',
      'stack': null,
      'fatal': false,
      'created_at': DateTime.utc(2026, 10, 17, 17, 43).toIso8601String(),
    });

Future<void> _pump(WidgetTester tester,
    {required int shown, required int total, SuperAdminRepository? repo}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      crashReportsProvider.overrideWith((ref, f) async => [for (var i = 0; i < shown; i++) _row(i)]),
      crashReportTotalProvider.overrideWith((ref, f) async => total),
      crashReportFacetsProvider
          .overrideWith((ref) async => (platforms: {'android'}, appVersions: {'1.0.0'})),
      if (repo != null) superAdminRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
        theme: AppTheme.darkTheme, home: const Scaffold(body: CrashReportsScreen())),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('the header gives the real total, and says the list is the newest',
      (tester) async {
    await _pump(tester, shown: 500, total: 9243);
    expect(find.text('9,243 reports \u00b7 newest 500 shown'), findsOneWidget);
    expect(find.textContaining('fingerprint'), findsNothing);
  });

  testWidgets('a short list says its own count', (tester) async {
    await _pump(tester, shown: 3, total: 3);
    expect(find.text('3 reports'), findsOneWidget);
  });

  testWidgets('it says when the last report arrived', (tester) async {
    await _pump(tester, shown: 3, total: 3);
    expect(find.textContaining('Last report received'), findsOneWidget);
  });

  testWidgets('the test button sends through the app\u2019s own reporter',
      (tester) async {
    final capture = _Capture();
    final previous = crashReporter.sink;
    crashReporter.useSink(capture);
    addTearDown(() => crashReporter.useSink(previous));
    await _pump(tester, shown: 3, total: 3);
    await tester.tap(find.text('Send a test report'));
    await tester.pump();
    expect(capture.reports, hasLength(1));
    expect(capture.reports.single.context, 'test report');
    expect('${capture.reports.single.error}', startsWith('Test report sent from the Crash reports screen'));
    // Let the arrival check run out (no server in a test) and say so.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    expect(find.textContaining('did not arrive'), findsOneWidget);
  });

  testWidgets('and when the server has it, the screen says reporting works',
      (tester) async {
    final capture = _Capture();
    final previous = crashReporter.sink;
    crashReporter.useSink(capture);
    addTearDown(() => crashReporter.useSink(previous));
    await _pump(tester, shown: 3, total: 3, repo: _EchoRepo(capture));
    await tester.tap(find.text('Send a test report'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.textContaining('crash reporting works'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
  });
}
