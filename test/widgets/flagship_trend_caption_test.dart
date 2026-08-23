// The flagship trend's TARGET caption must not sit under the period pill.
//
// Both live in the plot's top band: the pill (`7 days`) at the top-right
// corner, the caption riding 20px above its own dashed line. A target that
// outruns the data — the normal case, since a month's daily pace is pitched
// against the busiest day — puts that line in the top tenth of the plot, and
// right-anchored the caption rendered as "TARGET 9▮7 days" on the mine
// dashboard (Phase 3 mine-portal pass, 2026-08-23). The rule the reference
// card (`tons_moved_card.dart`) already applies: a line in the top 30% sends
// the caption to the LEFT end. Fonts are loaded so the chip widths are real.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_charts.dart';

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

Widget _chart({required List<double> current, required double target}) {
  return MaterialApp(
    theme: ThemeData(brightness: Brightness.dark),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 740,
          child: Builder(
            builder: (context) => MlFlagshipTrend(
              current: current,
              previous: current.map((v) => v * 0.9).toList(),
              tokens: MlGlass.of(context),
              target: target,
              targetLabel: 'TARGET ${target.round()} T/DAY',
              latestLabel: '7 days',
              priorLabel: 'Previous 7 days',
              unitCaption: 'Daily · Tons',
              xLabels: const {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    await _loadFont('JetBrainsMono', [
      'JetBrainsMono-Regular.ttf',
      'JetBrainsMono-Medium.ttf',
      'JetBrainsMono-Bold.ttf',
    ]);
    await _loadFont('PlusJakartaSans', [
      'PlusJakartaSans-Regular.ttf',
      'PlusJakartaSans-Medium.ttf',
      'PlusJakartaSans-SemiBold.ttf',
    ]);
  });

  test('a line in the top 30% of the plot anchors the caption left', () {
    expect(flagshipCaptionAnchorsLeft(14, 150), isTrue);
    expect(flagshipCaptionAnchorsLeft(44, 150), isTrue);
    expect(flagshipCaptionAnchorsLeft(45, 150), isFalse);
    expect(flagshipCaptionAnchorsLeft(120, 150), isFalse);
    expect(flagshipCaptionAnchorsLeft(10, 0), isFalse);
  });

  testWidgets('a target far above the data: caption left, clear of the pill',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // 903 t/day against days of 30-40 t — the mine dashboard's real shape.
    await tester.pumpWidget(_chart(
      current: const [34, 36, 0, 35, 33, 0, 37],
      target: 903,
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final caption = tester.getRect(find.text('TARGET 903 T/DAY'));
    // `.first`: the pill sits in the plot's Stack, ahead of the legend key
    // that now also reads "7 days".
    final pill = tester.getRect(find.text('7 days').first);
    expect(caption.overlaps(pill), isFalse,
        reason: 'caption $caption sits under the period pill $pill');
    // Not merely "not overlapping by luck" — it is at the LEFT end.
    final plot = tester.getRect(find.byType(MlFlagshipTrend));
    expect(caption.left, lessThan(plot.left + 40),
        reason: 'caption should be at the left end, is at ${caption.left}');
  });

  testWidgets('the legend has no Target key when no target is drawn',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.dark),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 740,
            child: Builder(
              builder: (context) => MlFlagshipTrend(
                current: const [34, 36, 0, 35],
                previous: const [30, 31, 0, 32],
                tokens: MlGlass.of(context),
                latestLabel: '7 days',
                priorLabel: 'Previous 7 days',
                xLabels: const {},
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Target'), findsNothing,
        reason: 'a Target key for a line that is not drawn');
    // The first key names the series the way the pill does.
    expect(find.text('7 days'), findsNWidgets(2)); // the pill and the key
    expect(find.text('This period'), findsNothing);
  });

  testWidgets('the legend keeps its Target key when a target is drawn',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_chart(
      current: const [34, 36, 0, 35, 33, 0, 37],
      target: 903,
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Target'), findsOneWidget);
  });

  testWidgets('a target inside the data band keeps the caption at the right',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Target and data on the same scale: the line runs mid-plot, nowhere
    // near the pill, and the caption keeps the reference's right anchor.
    await tester.pumpWidget(_chart(
      current: const [900, 1200, 600, 1100, 950, 700, 1000],
      target: 900,
    ));
    await tester.pump(const Duration(milliseconds: 300));

    final caption = tester.getRect(find.text('TARGET 900 T/DAY'));
    // `.first`: the pill sits in the plot's Stack, ahead of the legend key
    // that now also reads "7 days".
    final pill = tester.getRect(find.text('7 days').first);
    expect(caption.overlaps(pill), isFalse);
    final plot = tester.getRect(find.byType(MlFlagshipTrend));
    expect(caption.right, greaterThan(plot.right - 40),
        reason: 'caption should stay at the right end, ends at ${caption.right}');
  });
}
