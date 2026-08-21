// A ruler, not a test.
//
// Three fixed widths around text were "fixed" by estimating the text's width
// and were still cut afterwards, twice on the same field. Estimating is the
// fault; this lays the string out in the real font at the real size and prints
// what it actually measures.
//
// Run: flutter test test/renders/measure_strings_test.dart --plain-name ruler
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_helpers/real_fonts.dart';

void main() {
  setUpAll(loadRealFonts);

  testWidgets('ruler', (tester) async {
    double widthOf(String s, TextStyle style) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      return tp.width;
    }

    const sans = 'PlusJakartaSans';
    const mono = 'JetBrainsMono';

    final cases = <String, TextStyle>{
      'Search reg, transporter, customer…':
          const TextStyle(fontFamily: sans, fontSize: 14),
      'Roadhaul Logistics': const TextStyle(fontFamily: sans, fontSize: 14),
      'Atlas Buyer Group': const TextStyle(fontFamily: sans, fontSize: 14),
      'Northline Carriers, Vaal Bulk Movers':
          const TextStyle(fontFamily: sans, fontSize: 14),
      'Iron Hills Mining → Richards Bay':
          const TextStyle(fontFamily: sans, fontSize: 13),
      'Consolidated Mineral Offtake & Logistics Holdings':
          const TextStyle(fontFamily: sans, fontSize: 14),
      'CK 84 RT GP': const TextStyle(
          fontFamily: mono, fontSize: 13, letterSpacing: 0.8),
      'TRP-000123': const TextStyle(
          fontFamily: mono, fontSize: 13, letterSpacing: 0.8),
      '55,340 t': const TextStyle(
          fontFamily: mono, fontSize: 15, fontWeight: FontWeight.w700),
      'AVG PER ACTIVE HAULER': const TextStyle(
          fontFamily: sans, fontSize: 10, letterSpacing: 1.15),
    };

    // ignore: avoid_print
    print('RULER (font metrics, no scaling):');
    cases.forEach((s, style) {
      // ignore: avoid_print
      print('  ${widthOf(s, style).toStringAsFixed(1).padLeft(7)}px  '
          '[${style.fontFamily} ${style.fontSize}]  $s');
    });

    // And the same strings at the console's widest text scale, because a fixed
    // pixel floor under a user-controlled type size is the fault that keeps
    // coming back (CLAUDE.md §10.4).
    // ignore: avoid_print
    print('RULER at textScale 1.3:');
    cases.forEach((s, style) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(1.3),
      )..layout();
      // ignore: avoid_print
      print('  ${tp.width.toStringAsFixed(1).padLeft(7)}px  $s');
    });

    expect(ui.PlatformDispatcher.instance.views.isNotEmpty, isTrue);
  });
}
