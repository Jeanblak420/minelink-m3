// MlStatCard against the design reference.
//
// `docs/design-reference.md` §4 describes the reference's stat card:
//
//   tinted icon well · large **Fraunces** numeral with optional unit ·
//   PlusJakartaSans label · **mono sub-caption** ·
//   "**A coloured 3px bar runs down the left edge**, carrying the semantic tone"
//
// and §3 puts "**every large numeral**" in the display face. MlStatCard drew
// its value in PlusJakartaSans ExtraBold, had no sub-caption slot and no left
// bar. It renders 40 figures across 11 screens, so this is the portal's most
// repeated numeral.
//
// The three portal DASHBOARDS are not affected and were not touched — they
// already render through the console's own `SaStatTile` via
// `portal_dashboard_kit.dart`, which has the reference treatment and maps a
// downward move to amber. MlStatCard is what the non-dashboard screens use.
//
// Real fonts loaded (CLAUDE.md §7); one brightness per test, because two in
// one test lets the element short-circuit and reports the first theme's ink
// for both.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/core/design/components/ml_stat_card.dart';

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
  double width = 320,
}) async {
  tester.view.physicalSize = Size(width, 700);
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
          child: Scaffold(
            body: Center(child: SizedBox(width: width, child: child)),
          ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 900));
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

  testWidgets('the figure renders in the display face', (tester) async {
    await _pump(
      tester,
      const MlStatCard(
        label: 'Active Waybills',
        value: '1,240',
        icon: Icons.description_outlined,
      ),
    );
    expect(
      tester.widget<Text>(find.text('1,240')).style?.fontFamily,
      MlGlass.display,
      reason: 'design-reference.md §3 — every large numeral is Fraunces.',
    );
  });

  testWidgets('the label stays in the body face', (tester) async {
    await _pump(
      tester,
      const MlStatCard(
        label: 'Active Waybills',
        value: '6',
        icon: Icons.description_outlined,
      ),
    );
    expect(
      tester.widget<Text>(find.text('Active Waybills')).style?.fontFamily,
      MlTokens.fontSans,
    );
  });

  testWidgets('the mono sub-caption renders in the mono face', (tester) async {
    // §3: the sub-caption is the design's distinctive tell — lowercase,
    // underscored, monospaced (`across_4_org_types`, `tokens_valid · 100%_up`).
    await _pump(
      tester,
      const MlStatCard(
        label: 'Tons out',
        value: '1,193.7',
        icon: Icons.scale_outlined,
        caption: 'net_mass · all_time',
      ),
    );
    final caption = tester.widget<Text>(find.text('net_mass · all_time'));
    expect(caption.style?.fontFamily, MlTokens.fontMono);
  });

  testWidgets('the figure aligns down a column with tabular figures',
      (tester) async {
    // S5-7. Stat cards sit in grids, so proportional digits make adjacent
    // figures disagree by a glyph width.
    await _pump(
      tester,
      const MlStatCard(
        label: 'Loads',
        value: '111,111',
        icon: Icons.inventory_2_outlined,
      ),
    );
    final style = tester.widget<Text>(find.text('111,111')).style!;
    expect(
      style.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  testWidgets('a tall card at 360 / scale 1.3 does not overflow',
      (tester) async {
    final errors = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = errors.add;
    await _pump(
      tester,
      const MlStatCard(
        label: 'Pit-to-port loss across every dispatched order',
        value: '1,193.7',
        icon: Icons.trending_down_rounded,
        caption: 'mined_vs_dispatched · 30d',
        tone: MlTone.warn,
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
    testWidgets('the figure ink follows the $brightness theme', (tester) async {
      await _pump(
        tester,
        const MlStatCard(
          label: 'Trips',
          value: '24',
          icon: Icons.local_shipping_outlined,
        ),
        brightness: brightness,
      );
      expect(tester.widget<Text>(find.text('24')).style?.color, expected);
    });
  }
}
