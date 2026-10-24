// The admin menu on a phone names every entry in full (admin phone audit,
// 2026-10-24): the drawer read "Communicatio…", "Account deactivati…",
// "Mine/Supplier tran…", "Request tracking l…", "Transporter driver li…" and
// "Margin ledger histo…". The drawer is now wider (up to 320dp) and its labels
// wrap to two lines; the desktop rail keeps one.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/shell/ml_nav_rail.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/nav/console_nav.dart';

import '../../test_helpers/real_fonts.dart';

/// Every label paragraph inside the rail that was cut short.
List<String> _cut(WidgetTester tester) => [
      for (final e in find
          .descendant(of: find.byType(MlNavRail), matching: find.byType(RichText))
          .evaluate())
        if ((e.renderObject! as RenderParagraph).didExceedMaxLines)
          (e.widget as RichText).text.toPlainText(),
    ];

Future<void> _pump(WidgetTester tester,
    {required double scale, required bool wrap, required double width}) async {
  tester.view.physicalSize = const Size(360, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  // The phone's own menu (what the drawer shows).
  final tree = consoleNavTree(phone: true);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.darkTheme,
    home: MediaQuery(
      data: MediaQueryData(
          size: const Size(360, 2400), textScaler: TextScaler.linear(scale)),
      child: Scaffold(
        body: Row(children: [
          MlNavRail(
            tree: tree,
            selectedRoute: null,
            showSearch: false,
            width: width,
            wrapLabels: wrap,
            onNavigate: (_) {},
          ),
          const Expanded(child: SizedBox()),
        ]),
      ),
    ),
  ));
  await tester.pump();
  // Open every group so every entry is laid out.
  for (final g in tree.where((n) => n.isGroup)) {
    final header = find.descendant(
        of: find.byType(MlNavRail), matching: find.text(g.label));
    if (header.evaluate().isEmpty) continue;
    final childShown = g.children.any((c) => find
        .descendant(of: find.byType(MlNavRail), matching: find.text(c.label))
        .evaluate()
        .isNotEmpty);
    if (!childShown) {
      await tester.ensureVisible(header.first);
      await tester.tap(header.first);
      await tester.pumpAndSettle();
    }
  }
}

void main() {
  setUpAll(loadRealFonts);

  for (final scale in <double>[1.0, 1.15, 1.3, 1.5]) {
    testWidgets('phone drawer (304dp, wrapping): every label whole at text $scale',
        (tester) async {
      await _pump(tester, scale: scale, wrap: true, width: 304);
      // The entries that were cut on the phone are actually laid out here.
      for (final label in ['Account deactivations', 'Communications',
          'Transporter driver limits', 'Platform users']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(_cut(tester), isEmpty);
      expect(tester.takeException(), isNull, reason: 'no overflow either');
    });
  }

  testWidgets('the test bites: the old drawer (280dp, one line) cut labels at 1.3',
      (tester) async {
    await _pump(tester, scale: 1.3, wrap: false, width: MlNavRail.expandedWidth);
    expect(_cut(tester), isNotEmpty);
  });
}
