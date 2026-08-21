// The insights board reports on the same hauliers the leaderboard does, and it
// has to say the same things about them.
//
// Photographed for the first time on 2026-08-20. Three of the figures on it
// were wrong in a way no layout test could see, because all three were
// perfectly laid out:
//
//   * A row labelled **On-time** was fed the waybill-COMPLETION rate. The
//     source said so in a comment and the screen did not. A haulier with 6 of
//     20 loads delivered on time rendered 91%, while the transporter
//     leaderboard — the other screen in this console reporting on-time for the
//     same companies — read the real measure and said 30%.
//   * A company with **nothing judgeable** (0 of 0) drew a 0% bar.
//     `CompanyMonthlyOpsStats` is explicit that this must be a dash: "only a
//     reader holding both can tell 'nothing to measure yet' from 'every load
//     was late'". Under the old figure it rendered 0% — 0 waybills of 3 trips —
//     which is why "is there a dash somewhere on the screen" is not the
//     question. The question is what THIS company's On-time row says.
//   * The meta line read **"1 routes"**.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/screens/super_admin_org_insights_screen.dart';

import '../../fixtures/console_capture_fixtures.dart';
import '../../fixtures/portal_capture_fixtures.dart';
import '../../fixtures/screen_fixtures.dart';
import '../../test_helpers/real_fonts.dart';
import '../../test_helpers/frozen_clock.dart';

void main() {
  setUpAll(() async {
    freezeCaptureClock();
    await loadRealFonts();
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'http://localhost:54321',
      anonKey: 'org-insights-figures',
    );
  });

  Future<void> pumpInsights(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...companyScopeOverrides(),
        ...consoleCaptureOverrides(),
        ...portalCaptureOverrides(),
      ],
      // The APP's theme, not a bare MaterialApp. A bare one renders in stock
      // Material's type scale and font family — a measurement of text this app
      // never draws — and `test-renders-under-the-app-theme` caught exactly
      // that here.
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: SuperAdminOrgInsightsScreen(orgType: 'transporter'),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  /// The value printed at the end of every meter row whose label is [label].
  ///
  /// A meter is `Row[ SizedBox(78, Text(label)), Expanded(bar), SizedBox(44,
  /// Text(value)) ]`, so this climbs from the label to that Row and takes the
  /// last `Text` under it. Reading the row rather than searching the page for a
  /// string is the whole point: `0%` and `—` both appear elsewhere on this
  /// screen, and the question is what THIS row says.
  List<String> meterValues(WidgetTester tester, String label) {
    final out = <String>[];
    for (final e in find.text(label).evaluate()) {
      Element? row;
      e.visitAncestorElements((a) {
        if (a.widget is Row) {
          row = a;
          return false;
        }
        return true;
      });
      final found = row;
      if (found == null) continue;
      final texts = <String>[];
      void visit(Element el) {
        final w = el.widget;
        if (w is Text && w.data != null) texts.add(w.data!);
        el.visitChildren(visit);
      }

      visit(found);
      if (texts.length >= 2) out.add(texts.last);
    }
    return out;
  }

  testWidgets('On-time is the measured on-time rate', (tester) async {
    await pumpInsights(tester);
    final values = meterValues(tester, 'On-time');

    expect(values, isNotEmpty,
        reason: 'no On-time meter rendered at all, so this proves nothing.');
    // `kTransporterInsights`, in board order: Roadhaul 112/121, Northline
    // 39/44, Vaal 6/20, Kopano 0/0.
    expect(values, containsAll(<String>['93%', '89%', '30%', '—']),
        reason: 'the On-time rows are:\n  $values\n'
            'Expected the measured rate for each haulier and a DASH for the one '
            'with nothing judgeable. If these read 95 / 94 / 91 / 0 the row is '
            'showing the waybill-completion rate under an On-time label, which '
            'is what it did until 2026-08-20 — and the transporter leaderboard '
            'in this same console reads the real measure, so the two boards '
            'then disagree about the same company.');
  });

  testWidgets('nothing judgeable renders a dash, never 0%', (tester) async {
    await pumpInsights(tester);
    final values = meterValues(tester, 'On-time');

    // Kopano Freight is 0 of 0 and is the only company in the fixture that is.
    expect(values.where((v) => v == '—').length, 1,
        reason: 'exactly one haulier in this fixture has nothing judgeable and '
            'its On-time row must be a dash. Rows: $values. A 0% bar there says '
            '"every load was late" when it means "nothing has been measured".');
  });

  testWidgets('a company with one route does not have "1 routes"',
      (tester) async {
    await pumpInsights(tester);
    expect(find.textContaining('1 routes'), findsNothing,
        reason: 'the meta line is interpolating a count without pluralising. '
            '`mlCount` is the shared formatter and the leaderboard beside this '
            'screen already uses the rule.');
    expect(find.textContaining('· 1 route'), findsWidgets,
        reason: 'Kopano Freight has exactly one route, so its meta line is the '
            'case this test is about — if the fixture changed, this proves '
            'nothing.');
  });

  /// The figure printed above the readout labelled [label].
  ///
  /// A readout tile is `Column[ RichText(value + unit), Text(LABEL) ]`, so this
  /// climbs from the label to that Column and takes the FIRST `RichText` under
  /// it — the value comes before the label in tree order.
  ///
  /// It has to be a `RichText`, and that matters: the first version of this
  /// test looked for a `Text` matching `^0\d$` anywhere on the page. The value
  /// is a `TextSpan`, so it never matched the thing it was written for — and it
  /// DID match the sparkline's day axis, which is legitimately "01 · 05 · 09".
  /// A test that fails on the wrong widget is not a test.
  String? readoutValue(WidgetTester tester, String label) {
    for (final e in find.text(label).evaluate()) {
      Element? column;
      e.visitAncestorElements((a) {
        if (a.widget is Column) {
          column = a;
          return false;
        }
        return true;
      });
      final found = column;
      if (found == null) continue;
      RichText? first;
      void visit(Element el) {
        if (first != null) return;
        final w = el.widget;
        if (w is RichText) {
          first = w;
          return;
        }
        el.visitChildren(visit);
      }

      visit(found);
      final span = first?.text;
      if (span is TextSpan) {
        final kids = span.children;
        if (kids != null && kids.isNotEmpty) return kids.first.toPlainText();
        return span.text;
      }
    }
    return null;
  }

  testWidgets('the control-room readouts are not zero-padded', (tester) async {
    await pumpInsights(tester);
    // "Routes rested" was the only one of the four readouts in its block padded
    // to two digits, so a quiet week printed "00" beside "4" and "10".
    // Asserted by SHAPE rather than by the literal "00", because "03" beside
    // "4" is the same fault.
    final value = readoutValue(tester, 'ROUTES RESTED');
    expect(value, isNotNull,
        reason: 'the Routes rested readout is not on the board, so this proves '
            'nothing.');
    expect(RegExp(r'^0\d$').hasMatch(value!), isFalse,
        reason: 'Routes rested reads "$value" — zero-padded, while Priority '
            'alerts, Reviews needed and Anomalies beside it are not. A padded '
            'count in a row of unpadded ones reads as a broken value rather '
            'than as a small number.');
  });
}
