// The portal's section header, against the design reference.
//
// `docs/design-reference.md` is the target, established 2026-08-14 by client
// instruction. Two of its rules land on this one widget:
//
//   §3  "display | Fraunces (serif) | section titles, and every large numeral"
//   §5.4 "Every section carries a header with a meta line, plus View → /
//        filter row / export where the screen has them" — this is S5-22.
//
// The console already has that component (`MlSectionHead`): display-face
// title, subtitle, right-aligned meta, `View →` link. The portal had
// `MlSectionTitle` — PlusJakartaSans ExtraBold, no subtitle, no meta, no link
// — used at 32 sites across 22 files. Two vocabularies for one job, which is
// what S5-13 exists to merge.
//
// Asserting on fontFamily rather than on a rendered pixel is deliberate: a
// golden here would fail on every legitimate design change and teach everyone
// to regenerate it without looking (the same reasoning recorded at the top of
// reference_capture_test.dart).
//
// Real fonts are loaded — CLAUDE.md §7. Without them the fallback face reports
// one em per glyph and any width assertion is meaningless.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/design/components/ml_section_title.dart';

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
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark
          ? AppTheme.darkTheme
          : AppTheme.lightTheme,
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: SizedBox(width: width, child: child)),
        ),
      ),
    ),
  );
  await tester.pump();
}

/// The style actually applied to the [text] run on screen.
TextStyle _styleOf(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

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

  testWidgets('the title renders in the display face, as the reference does',
      (tester) async {
    await _pump(tester, const MlSectionTitle('Stockpile levels'));
    expect(
      _styleOf(tester, 'Stockpile levels').fontFamily,
      MlGlass.display,
      reason: 'design-reference.md §3: section titles are Fraunces. The '
          'console renders them that way (MlSectionHead); the portal was '
          'using PlusJakartaSans, so one product spoke two type languages.',
    );
  });

  testWidgets('it carries a meta line — S5-22', (tester) async {
    await _pump(
      tester,
      const MlSectionTitle(
        'Recon table',
        subtitle: 'Every check-in → check-out exactly as captured.',
        meta: 'Last 24h · 14 loads',
      ),
    );
    expect(find.text('Recon table'), findsOneWidget);
    expect(find.text('Every check-in → check-out exactly as captured.'),
        findsOneWidget);
    expect(
      find.text('Last 24h · 14 loads'),
      findsOneWidget,
      reason: 'S5-22 requires a meta line on every section header. The portal '
          'header had nowhere to put one.',
    );
  });

  testWidgets('the meta line reaches the right edge', (tester) async {
    // Same fault as MlPageHeader's, different cause, found the same way — by
    // measuring the component capture instead of trusting it looked right.
    //
    // The trailing block was in a `Flexible`, and **Flexible defaults to
    // flex: 1**. So it competed with the title's Expanded for free space and
    // took half the row: in a 1000px header the meta started at x=507 and
    // ended at 642, nowhere near the edge. `Flexible` was there for the
    // ellipsis rule (CLAUDE.md §10.4 — a non-flex child in a Row gets
    // unbounded width so `overflow: ellipsis` never engages), but that rule
    // is about the *title*, which is the long one; the meta is short by
    // contract and is what the console's own MlSectionHead leaves unflexed.
    await _pump(
      tester,
      const MlSectionTitle('Stat cards', meta: 'Last 24h'),
      width: 1000,
    );
    expect(tester.getSize(find.byType(MlSectionTitle)).width, 1000);
    expect(tester.getRect(find.text('Last 24h')).right, closeTo(1000, 1));
  });

  testWidgets('the View link renders with the arrow and fires', (tester) async {
    var tapped = 0;
    await _pump(
      tester,
      MlSectionTitle(
        'Recent trips',
        link: 'View all',
        onLink: () => tapped++,
      ),
    );
    // The arrow is appended by the component, exactly as on the reference —
    // so no caller can ship "View all" without it and quietly break the tell.
    expect(find.text('View all →'), findsOneWidget);
    await tester.tap(find.text('View all →'));
    await tester.pump();
    expect(tapped, 1);
  });

  testWidgets('a long title ellipsises rather than overflowing',
      (tester) async {
    // 360px phone at the top of the accessibility range — the corner
    // CLAUDE.md §10.4 says rigid layouts break at, and where both real bugs
    // in the targets work were found.
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    await _pump(
      tester,
      const MlSectionTitle(
        'Contract quality specifications for every linked haul route',
        meta: 'Updated 2 minutes ago',
        action: Icon(Icons.refresh_rounded),
      ),
      width: 360,
      textScale: 1.3,
    );
    FlutterError.onError = previous;
    expect(
      errors.where((e) => e.exception.toString().contains('overflowed')),
      isEmpty,
      reason: 'a header must survive 360px at text scale 1.3 — the console '
          'lets every user set that scale via ConsolePrefs.',
    );
  });

  // design-reference.md §5.1: both themes are real, and a migrated screen has
  // to survive both. Resolving through MlSemantic/MlGlass is what makes that
  // true; a raw literal would render the same ink in both.
  //
  // ONE BRIGHTNESS PER TEST, and that is not stylistic. Pumping both into a
  // single test reports the dark ink for the light theme too, and the widget
  // is innocent: re-pumping the same widget identity lets the element
  // short-circuit, so it never rebuilds against the new theme. Written the
  // obvious way first, this "found" a hardcoded colour that does not exist —
  // the third time on this project a harness has impersonated a product
  // defect (CLAUDE.md §10.5). Split, it reads correctly.
  for (final (brightness, expected) in <(Brightness, Color)>[
    (Brightness.dark, Color(0xFFEEF3FA)),
    (Brightness.light, Color(0xFF0F172A)),
  ]) {
    testWidgets('the title ink follows the $brightness theme', (tester) async {
      await _pump(tester, const MlSectionTitle('Production'),
          brightness: brightness);
      expect(_styleOf(tester, 'Production').color, expected);
    });
  }

  // Phase 3 mine-portal pass, 2026-08-23. Two alignment faults no overflow
  // sweep can see, found by three reviewers on three screens each.
  testWidgets('stacked on a phone, the action goes RIGHT and the meta stays '
      'left', (tester) async {
    // 360px is under the stacking floor, so the trailing block goes under
    // the title. It used to carry the action in an `Align(centerLeft)`:
    // a lone refresh icon / "Add location" button stranded at the far left.
    await _pump(
      tester,
      MlSectionTitle(
        'Contract quality specs',
        meta: '2 routes',
        action: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {},
        ),
      ),
      width: 360,
    );
    final meta = tester.getRect(find.text('2 routes'));
    final title = tester.getRect(find.text('Contract quality specs'));
    final action = tester.getRect(find.byType(IconButton));
    expect(meta.top, greaterThan(title.bottom - 1),
        reason: 'the meta should be under the title at 360px');
    expect(action.right, closeTo(360, 1),
        reason: 'action should reach the right edge, ends at ${action.right}');
    expect(meta.left, closeTo(0, 1));
    // And on the SAME line as the meta, not a third row.
    expect((action.center.dy - meta.center.dy).abs(), lessThan(4));
  });

  testWidgets('an icon action is level with its meta on a one-line heading',
      (tester) async {
    // With `CrossAxisAlignment.start` a 48px IconButton hung 18px below a
    // 14px meta: the quality screen's "2 routes" sat above its refresh glyph.
    await _pump(
      tester,
      MlSectionTitle(
        'Contract quality specs',
        meta: '2 routes',
        action: IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () {},
        ),
      ),
      width: 1000,
    );
    final meta = tester.getRect(find.text('2 routes'));
    final glyph = tester.getRect(find.byIcon(Icons.refresh));
    expect((glyph.center.dy - meta.center.dy).abs(), lessThan(3),
        reason: 'meta centre ${meta.center.dy} vs glyph centre '
            '${glyph.center.dy}');
    // The meta still sits immediately left of the action.
    expect(meta.right, lessThan(glyph.left));
    expect(meta.right, greaterThan(glyph.left - 60));
  });
}
