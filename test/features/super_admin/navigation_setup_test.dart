// The "Navigation setup" guide (Jean's go-ahead, 2026-10-24): how to put a
// mine's own haul roads into the app's turn-by-turn navigation. Written for
// THIS app; the oldest `ML` tree's guide was read as reference only.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/super_admin/screens/navigation_setup_screen.dart';

import '../../test_helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  Future<List<String>> pump(WidgetTester tester,
      {required double width, double textScale = 1.0}) async {
    final overflows = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) {
      final m = d.exception.toString();
      m.contains('overflowed') ? overflows.add(m.split('\n').first) : previous?.call(d);
    };
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(
            size: Size(width, 900), textScaler: TextScaler.linear(textScale)),
        child: const Scaffold(body: NavigationSetupScreen()),
      ),
    ));
    await tester.pumpAndSettle();
    FlutterError.onError = previous;
    return overflows;
  }

  String everything(WidgetTester tester) {
    final out = StringBuffer();
    for (final ro in tester.allRenderObjects.whereType<RenderParagraph>()) {
      out.writeln(ro.text.toPlainText());
    }
    // The commands are SelectableText, which paints through RenderEditable.
    for (final w in tester.widgetList<SelectableText>(find.byType(SelectableText))) {
      out.writeln(w.data);
    }
    return out.toString();
  }

  testWidgets('it names what this app actually reads', (tester) async {
    await pump(tester, width: 1280);
    final text = everything(tester);
    // The app routes through Valhalla first (routing_service.dart), so the
    // setting that matters is VALHALLA_BASE_URL — the old guide said OSRM.
    expect(text, contains('VALHALLA_BASE_URL'));
    expect(text, isNot(contains('OSRM_BASE_URL=')));
    // The image the old guide named has moved to the Valhalla project.
    expect(text, contains('ghcr.io/valhalla/valhalla-scripted'));
    // Truck access is the hgv key; the app routes with truck costing.
    expect(text, contains('hgv'));
    // And it ends with a check, not an assumption.
    expect(text, contains('Test a route'));
  });

  testWidgets('it says plainly that the app does not run these steps',
      (tester) async {
    await pump(tester, width: 1280);
    expect(everything(tester), contains('outside the app'));
  });

  for (final scale in [1.0, 1.3]) {
    testWidgets('phone width, text ×$scale: nothing overflows', (tester) async {
      expect(await pump(tester, width: 360, textScale: scale), isEmpty);
    });
  }
}
