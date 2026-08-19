// The portal's PAGE header, against the design reference.
//
// Every portal screen opens with a title and a one-line description, and all
// 36 of them hand-rolled it:
//
//     Text(title, style: textTheme.headlineSmall?.copyWith(w800))
//     SizedBox(height: 4)
//     Text(description, ...)
//
// Three problems follow from that being copied rather than shared. It is in
// the wrong face — `docs/design-reference.md` §3 puts section and page titles
// in Fraunces, and the console does. It has nowhere to put the meta line or
// the `View →`/export affordance S5-22 requires. And a rule applied 36 times
// by hand is a rule that holds in 34 places and quietly fails in two.
//
// MlPageHeader is the shared version. This pins the contract before the
// screens are moved onto it.
//
// Real fonts loaded (CLAUDE.md §7); one brightness per test, because pumping
// two into one test lets the element short-circuit and reports the first
// theme's ink for both — that already impersonated a hardcoded-colour bug once
// on this suite.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/components/ml_page_header.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  var loaded = false;
  for (final f in files) {
    final file = File('assets/fonts/$f');
    if (!file.existsSync()) continue;
    loaded = true;
    loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
  }
  if (loaded) await loader.load();
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.dark,
  double textScale = 1.0,
  double width = 1280,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: SizedBox(width: width, child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUpAll(() async {
    await _loadFont('PlusJakartaSans', [
      'PlusJakartaSans-Regular.ttf',
      'PlusJakartaSans-Medium.ttf',
      'PlusJakartaSans-SemiBold.ttf',
      'PlusJakartaSans-Bold.ttf',
      'PlusJakartaSans-ExtraBold.ttf',
    ]);
    await _loadFont('JetBrainsMono', [
      'JetBrainsMono-Regular.ttf',
      'JetBrainsMono-Medium.ttf',
      'JetBrainsMono-Bold.ttf',
    ]);
    await _loadFont(
        'Fraunces', ['Fraunces-Medium.ttf', 'Fraunces-SemiBold.ttf']);
  });

  testWidgets('the page title renders in the display face', (tester) async {
    await _pump(tester, const MlPageHeader(title: 'Production'));
    expect(
      tester.widget<Text>(find.text('Production')).style?.fontFamily,
      MlGlass.display,
      reason: 'design-reference.md §3 — page and section titles are Fraunces.',
    );
  });

  testWidgets('the description sits under the title in the body face',
      (tester) async {
    await _pump(
      tester,
      const MlPageHeader(
        title: 'Tons out',
        description: 'Every check-in → check-out as captured.',
      ),
    );
    final desc =
        tester.widget<Text>(find.text('Every check-in → check-out as captured.'));
    expect(desc.style?.fontFamily, MlGlass.sans);
  });

  testWidgets('it carries the meta line S5-22 requires', (tester) async {
    await _pump(
      tester,
      const MlPageHeader(
        title: 'Platform registry',
        description: 'Companies, users and throughput.',
        meta: 'Last 24h · +2 companies, +14 users',
      ),
    );
    expect(find.text('Last 24h · +2 companies, +14 users'), findsOneWidget);
  });

  testWidgets('the meta line is right-aligned, not glued to the title',
      (tester) async {
    // Caught by looking at docs/design-reference/portal-components-dark.png:
    // the meta sat immediately after the title instead of at the far right,
    // where §4 puts it. Measured rather than eyeballed — the header was
    // 516px wide inside a 1000px column.
    //
    // Cause: a Wrap sizes to its content, so WrapAlignment.spaceBetween had
    // no free space to distribute and "space between" meant nothing. The
    // component has to claim the row's full width first.
    await _pump(
      tester,
      const MlPageHeader(title: 'Portal components', meta: 'Last 24h'),
      width: 1000,
    );
    expect(tester.getSize(find.byType(MlPageHeader)).width, 1000);
    expect(
      tester.getRect(find.text('Last 24h')).right,
      closeTo(1000, 1),
      reason: 'the meta belongs at the right edge of the header.',
    );
  });

  testWidgets('actions render beside the title', (tester) async {
    var pressed = 0;
    await _pump(
      tester,
      MlPageHeader(
        title: 'Production',
        actions: [
          TextButton(
            onPressed: () => pressed++,
            child: const Text('Record production'),
          ),
        ],
      ),
    );
    await tester.tap(find.text('Record production'));
    await tester.pump();
    expect(pressed, 1);
  });

  testWidgets('a long title with actions survives 360px at scale 1.3',
      (tester) async {
    // The corner that matters: CLAUDE.md §10.4 — every user can set the text
    // scale, and both real bugs in the targets work only appeared at 1.3. A
    // header is the widest single row on most screens.
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    await _pump(
      tester,
      MlPageHeader(
        title: 'Reconciliations and delivered-tonnage variance',
        description: 'Side A raw capture and Side B the system cross-checks, '
            'with the two-version edit round-trip.',
        meta: 'Updated 2 minutes ago',
        actions: [
          TextButton(onPressed: () {}, child: const Text('Export')),
        ],
      ),
      width: 360,
      textScale: 1.3,
    );
    FlutterError.onError = previous;
    expect(
      errors.where((e) => e.exception.toString().contains('overflowed')),
      isEmpty,
    );
  });

  for (final (brightness, expected) in <(Brightness, Color)>[
    (Brightness.dark, Color(0xFFEEF3FA)),
    (Brightness.light, Color(0xFF0F172A)),
  ]) {
    testWidgets('the title ink follows the $brightness theme', (tester) async {
      await _pump(tester, const MlPageHeader(title: 'Quality'),
          brightness: brightness);
      expect(tester.widget<Text>(find.text('Quality')).style?.color, expected);
    });
  }
}
