import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/super_admin/data/models/models.dart';
import 'package:flutter_application_1/features/super_admin/screens/crash_reports_screen.dart';
import '../test_helpers/real_fonts.dart';

/// A single 300-character unbroken token — no spaces, so nothing offers a
/// soft-wrap point. This is what actually overflows a `Row`; a long sentence
/// with spaces wraps and hides the bug a solid token exposes.
final String _longToken = List.generate(300, (i) => 'x').join();

const String _longPlatform =
    'android-arm64-v8a-emulator-api34-quite-long-build-flavor';
const String _longVersion = '12.34.56-beta.789+build.20260819.abcdef0123456789';

/// One very long, unbroken line per stack frame — 220 chars, monospace —
/// so the expanded stack box is exercised by something genuinely wider than
/// any of the three swept viewport widths, at any of the three text scales.
String _longStackLine(int i) =>
    'at someDeeplyNestedFunctionNumber$i (${List.generate(200, (j) => 'f').join()}:$i:$i)';

final List<CrashReportRow> _populatedReports = <CrashReportRow>[
  CrashReportRow(
    id: 'fatal-1',
    at: DateTime.utc(2026, 8, 18, 10, 30),
    platform: _longPlatform,
    appVersion: _longVersion,
    error: _longToken,
    stack: List.generate(6, _longStackLine).join('\n'),
    fatal: true,
    createdAt: DateTime.utc(2026, 8, 18, 10, 30),
  ),
  CrashReportRow(
    id: 'handled-1',
    at: DateTime.utc(2026, 8, 17, 9, 15),
    platform: 'ios',
    appVersion: '1.0.0',
    error: 'A normal handled error with ordinary spaces in it',
    stack: null,
    fatal: false,
    createdAt: DateTime.utc(2026, 8, 17, 9, 15),
  ),
];

Future<void> _pumpAt(
  WidgetTester tester, {
  required double width,
  required double scale,
  required List<CrashReportRow> reports,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: CrashReportsScreen(reports: reports)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadRealFonts);

  for (final width in <double>[360, 800, 1440]) {
    for (final scale in <double>[0.85, 1.0, 1.3, 1.6, 2.0]) {
      testWidgets('renders without overflow at ${width}px / scale $scale', (
        tester,
      ) async {
        await _pumpAt(tester, width: width, scale: scale, reports: const []);

        expect(tester.takeException(), isNull);
        // An empty store must say so, not render a blank panel that reads as
        // a broken screen.
        expect(find.textContaining('No crash reports'), findsOneWidget);
      });
    }
  }

  // Fix round 1 — the sweep above only ever proved the empty state, which
  // exercises none of the real screen: no filter chips, no card `Row`s, no
  // expanded stack box. This sweep pumps a hostile, populated fixture
  // through the same width x scale matrix and asserts real content rendered
  // — not merely that nothing threw.
  for (final width in <double>[360, 800, 1440]) {
    for (final scale in <double>[0.85, 1.0, 1.3, 1.6, 2.0]) {
      testWidgets(
        'renders a populated list without overflow at ${width}px / scale $scale',
        (tester) async {
          await _pumpAt(
            tester,
            width: width,
            scale: scale,
            reports: _populatedReports,
          );

          expect(tester.takeException(), isNull);

          // The collapsed row shows the full `error` string as its Text data
          // (ellipsis only affects painting, not the widget's data), so this
          // proves the unbroken 300-char token actually reached the card.
          expect(find.text(_longToken), findsOneWidget);
          expect(
            find.text('A normal handled error with ordinary spaces in it'),
            findsOneWidget,
          );

          // Fatal vs handled pills — MlStatusBadge uppercases its label.
          expect(find.text('FATAL'), findsOneWidget);
          expect(find.text('HANDLED'), findsOneWidget);

          // Facet chips built from the long platform/app_version combination.
          expect(find.text(_longPlatform), findsOneWidget);
          expect(find.text('v$_longVersion'), findsOneWidget);
        },
      );
    }
  }

  testWidgets('the screen opens in the shared page header, with its count',
      (tester) async {
    // 'Crash reports' was a 16px PlusJakartaSans ExtraBold title set by hand
    // while every other console screen opens in the Fraunces display face
    // through MlPageHeader. Found 2026-08-23 in the Phase 3 pass.
    await _pumpAt(tester, width: 1600, scale: 1.0, reports: _populatedReports);
    final header = find.byType(MlPageHeader);
    expect(header, findsOneWidget);
    final title = tester.widget<Text>(
        find.descendant(of: header, matching: find.text('Crash reports')));
    expect(title.style?.fontFamily, MlTokens.fontSerif);
    // "N reports", not "N fingerprints": the rows are reports, and the
    // figure is their real count (2026-10-24).
    expect(tester.widget<MlPageHeader>(header).meta,
        '${_populatedReports.length} reports');
  });

  testWidgets('expanding a fatal report scrolls its stack trace instead of '
      'widening the page', (tester) async {
    const width = 360.0;
    await _pumpAt(tester, width: width, scale: 1.0, reports: _populatedReports);

    // Tap the fatal row (its title is the long token) to expand it and
    // actually build the stack-trace scroll box.
    await tester.tap(find.text(_longToken));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final stackText = List.generate(6, _longStackLine).join('\n');
    final stackTextFinder = find.text(stackText);
    expect(
      stackTextFinder,
      findsOneWidget,
      reason: 'expanding the card must build the stack Text widget',
    );

    // The page itself must not have grown to accommodate the stack trace —
    // it stays exactly the viewport width the test set up.
    final scaffoldRect = tester.getRect(find.byType(Scaffold));
    expect(scaffoldRect.width, closeTo(width, 1));

    // The stack scroll box's own container is bounded to the page (it is a
    // SizedBox(width: double.infinity) inside the card's content column) —
    // not stretched out to the width of the text it holds.
    final scrollBoxRect = tester.getRect(
      find.byKey(const ValueKey('stack-scroll-fatal-1')),
    );
    expect(scrollBoxRect.width, lessThanOrEqualTo(scaffoldRect.width + 1));

    // But the TEXT inside that box is genuinely wider than the viewport —
    // proving the long stack line is there to scroll, not wrapped or
    // clipped away. This is what an overflow sweep alone would never catch:
    // nothing here throws either way.
    final stackTextRect = tester.getRect(stackTextFinder);
    expect(stackTextRect.width, greaterThan(scaffoldRect.width));
  });

  testWidgets('a report with no stack trace says so instead of expanding '
      'into nothing', (tester) async {
    await _pumpAt(tester, width: 360, scale: 1.0, reports: _populatedReports);

    await tester.tap(
      find.text('A normal handled error with ordinary spaces in it'),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('No stack trace recorded.'), findsOneWidget);
  });
}
