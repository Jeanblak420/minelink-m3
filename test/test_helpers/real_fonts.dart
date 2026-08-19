// Registers the app's real fonts inside a `flutter test` run.
//
// This exists because `flutter test` does NOT render in the app's fonts. Unless
// a test loads them explicitly it uses a fallback font in which every glyph is
// one em wide, so a 9-character label at fontSize 9 measures 81px instead of
// ~45px. That breaks layout assertions in BOTH directions: it invents overflows
// for layouts that are fine in the real app, and it hides real ones whose
// strings happen to measure narrower under the fallback.
//
// CLAUDE.md §7 and §10.5 spell this out. Any test that asserts on layout —
// overflow sweeps, geometry measurements — has to call [loadRealFonts] first,
// or it is measuring the wrong thing.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registers a real font family from `assets/fonts` under [family].
///
/// Silently skips files that are not present, so adding a weight to
/// `pubspec.yaml` before the file lands does not break every layout test.
Future<void> loadFont(String family, List<String> files) async {
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

/// Every family the app registers in `pubspec.yaml`.
Future<void> loadRealFonts() async {
  await loadFont('PlusJakartaSans', [
    'PlusJakartaSans-Regular.ttf',
    'PlusJakartaSans-Medium.ttf',
    'PlusJakartaSans-SemiBold.ttf',
    'PlusJakartaSans-Bold.ttf',
    'PlusJakartaSans-ExtraBold.ttf',
  ]);
  await loadFont('JetBrainsMono', [
    'JetBrainsMono-Regular.ttf',
    'JetBrainsMono-Medium.ttf',
    'JetBrainsMono-Bold.ttf',
  ]);
  await loadFont('Fraunces', [
    'Fraunces-Medium.ttf',
    'Fraunces-SemiBold.ttf',
  ]);
  await loadFont('Sora', [
    'Sora-Regular.ttf',
    'Sora-Medium.ttf',
    'Sora-SemiBold.ttf',
    'Sora-Bold.ttf',
  ]);
}
