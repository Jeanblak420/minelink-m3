// The portal's DISPLAY NUMERALS, against the design reference.
//
// `docs/design-reference.md` §3: "display | Fraunces (serif) | section titles,
// and **every large numeral**". S5-6's amended wording carries the same split —
// PlusJakartaSans for UI text, Fraunces for display numerals, JetBrainsMono for
// figures — and its own note says the numeral half is the part still untouched:
// *"display numerals are still in the sans face wherever a screen draws one."*
//
// Measured before writing this: `AppTheme._mlTextTheme` ends with
// `.apply(fontFamily: MlTokens.fontSans)`, which covers the WHOLE text theme.
// So every `textTheme.headlineSmall` / `headlineMedium` numeral in the portal
// renders in PlusJakartaSans, and there were 12 such sites. Six of them go
// through one widget — `AnimatedTons` — which took its style from the caller
// and therefore had no opinion of its own.
//
// The other rule this pins is S5-7: `FontFeature.tabularFigures()`. A tonnage
// that animates 0 → 128.4 reflows on every frame without it, because
// proportional digits are different widths — the number visibly jitters while
// it counts. Same reason a column of figures fails to line up.
//
// A PLATE is not a numeral. §3 puts codes, plates and references in
// JetBrainsMono, so `MlType.code` exists alongside `MlType.figure` and the two
// are asserted separately — collapsing them was the easy mistake here.
//
// Asserting on fontFamily rather than on a rendered pixel is deliberate, for
// the reason recorded at the top of reference_capture_test.dart: a golden fails
// on every legitimate design change and teaches everyone to regenerate it
// without looking.
//
// Real fonts are loaded — CLAUDE.md §7.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart';

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

Future<void> _loadRealFonts() async {
  await _loadFont('PlusJakartaSans', [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]);
  await _loadFont('JetBrainsMono', [
    'JetBrainsMono-Regular.ttf',
    'JetBrainsMono-Medium.ttf',
  ]);
  await _loadFont('Fraunces', ['Fraunces-Medium.ttf', 'Fraunces-SemiBold.ttf']);
}

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: Center(child: child)),
    );

/// The style on the single Text this widget renders.
TextStyle _style(WidgetTester tester) =>
    tester.widgetList<Text>(find.byType(Text)).first.style!;

void main() {
  setUpAll(_loadRealFonts);

  group('MlType.figure — the display numeral', () {
    test('is the display face, and carries tabular figures', () {
      final style = MlType.figure(color: Color(0xFFFFFFFF));
      expect(style.fontFamily, MlTokens.fontSerif);
      expect(style.fontFamily, 'Fraunces');
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    test('is NOT the UI sans — the whole point of the gate', () {
      final style = MlType.figure(color: Color(0xFFFFFFFF));
      expect(style.fontFamily, isNot(MlTokens.fontSans));
    });

    test('takes a size, defaulting to the H2 display step', () {
      expect(MlType.figure(color: Color(0xFFFFFFFF)).fontSize,
          MlTokens.fsH2);
      expect(
          MlType.figure(color: Color(0xFFFFFFFF), size: 64).fontSize, 64);
    });
  });

  group('MlType.code — a plate, reference or code is NOT a numeral', () {
    test('is the mono face, and also tabular', () {
      final style = MlType.code(color: Color(0xFFFFFFFF));
      expect(style.fontFamily, MlTokens.fontMono);
      expect(style.fontFamily, 'JetBrainsMono');
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });

    test('is distinct from the display face', () {
      expect(MlType.code(color: Color(0xFFFFFFFF)).fontFamily,
          isNot(MlType.figure(color: Color(0xFFFFFFFF)).fontFamily));
    });
  });

  group('AnimatedTons renders a display numeral without being told to', () {
    testWidgets('defaults to Fraunces with tabular figures', (tester) async {
      await tester.pumpWidget(_host(const AnimatedTons(value: 128.4)));
      await tester.pumpAndSettle();

      final style = _style(tester);
      expect(style.fontFamily, 'Fraunces',
          reason: 'six call sites passed it a headlineSmall/Medium, and the '
              'theme applies PlusJakartaSans to the whole text theme — so the '
              'portal drew every tonnage in the UI sans');
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()),
          reason: 'without tabular digits an animating tonnage reflows on '
              'every frame while it counts up');
    });

    testWidgets('an explicit style still wins, so callers can override',
        (tester) async {
      await tester.pumpWidget(_host(const AnimatedTons(
        value: 12,
        style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 11),
      )));
      await tester.pumpAndSettle();
      final text = tester.widgetList<Text>(find.byType(Text)).first;
      expect(text.style?.fontFamily, 'JetBrainsMono');
    });
  });
}
