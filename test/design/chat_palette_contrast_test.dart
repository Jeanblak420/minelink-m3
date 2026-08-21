// The eighteen chat palettes, as arithmetic.
//
// The dock is the chat of this product — mounted on every portal screen and
// every console screen — and until 2026-08-22 it had NO renders at all. So
// while the rest of the app went from 1,812 low-contrast strings to zero, the
// palette table behind the one surface users actually type into was never
// measured even once. The moment the dock was photographed it reported white
// on `#5E81AC` at 4.03:1 for every outgoing message, on the DEFAULT palette.
//
// Renders alone cannot close this, and that is the reason this file exists: a
// render photographs the ONE palette that happens to be selected. There are
// eighteen, the user picks among them, and seventeen would stay unmeasured
// however many pictures were taken. This asks the machine about all of them.
//
// The bar is 4.5:1 — WCAG AA for normal text. Every pair here is body copy,
// a sender name, or a timestamp, all of it under 24px, so the large-text
// allowance of 3.0 never applies. That allowance being taken for an 11px
// label is the exact mistake `ink_ladder_test.dart` was written to stop.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/design/tokens/ml_chat_palettes.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color ink, Color ground) {
  final a = _lum(ink), b = _lum(ground);
  final hi = a > b ? a : b;
  final lo = a > b ? b : a;
  return (hi + 0.05) / (lo + 0.05);
}

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';


void main() {
  /// Every (ink, ground) the dock actually paints, named the way the failure
  /// message should read.
  List<({String what, Color ink, Color ground})> pairsFor(ChatPalette p) => [
        (what: 'headerText on header', ink: p.headerText, ground: p.header),
        (what: 'bodyText on body', ink: p.bodyText, ground: p.body),
        (what: 'bodySubtle on body', ink: p.bodySubtle, ground: p.body),
        (
          what: 'incomingText on incomingBubble',
          ink: p.incomingText,
          ground: p.incomingBubble
        ),
        (
          what: 'outgoingText on outgoingBubble',
          ink: p.outgoingText,
          ground: p.outgoingBubble
        ),
        (
          what: 'senderName on incomingBubble',
          ink: p.senderName,
          ground: p.incomingBubble
        ),
        (what: 'accentText on accent', ink: p.accentText, ground: p.accent),
        // The reply quote, on the ground the widget actually paints.
        //
        // Both sides come from [ChatPalette] itself rather than being
        // recomputed here, so the widget and this test cannot drift — the
        // fault that made this necessary was a quote tinting its ground with
        // its own ink, and a test that re-derived the tint independently
        // could have kept agreeing with a broken widget.
        (
          what: 'reply-quote name, on the quote ground over outgoingBubble',
          ink: p.quoteNameInk(mine: true),
          ground: p.quoteGround(mine: true)
        ),
        (
          what: 'reply-quote preview, on the quote ground over outgoingBubble',
          ink: p.quotePreviewInk(mine: true),
          ground: p.quoteGround(mine: true)
        ),
        (
          what: 'reply-quote name, on the quote ground over incomingBubble',
          ink: p.quoteNameInk(mine: false),
          ground: p.quoteGround(mine: false)
        ),
        (
          what: 'reply-quote preview, on the quote ground over incomingBubble',
          ink: p.quotePreviewInk(mine: false),
          ground: p.quoteGround(mine: false)
        ),
      ];

  group('every chat palette is legible', () {
    for (final p in ChatThemes.palettes) {
      test('${p.name} (${p.id})', () {
        final failures = <String>[];
        for (final pair in pairsFor(p)) {
          final ratio = contrast(pair.ink, pair.ground);
          if (ratio < 4.5) {
            failures.add(
              '  ${pair.what}\n'
              '      ${ratio.toStringAsFixed(2)}:1 (needs 4.5)  '
              'ink ${_hex(pair.ink)} on ${_hex(pair.ground)}',
            );
          }
        }
        expect(
          failures,
          isEmpty,
          reason: 'Palette "${p.name}" paints text that cannot be read:\n'
              '${failures.join('\n')}\n\n'
              'Fix it in lib/core/design/tokens/ml_chat_palettes.dart by '
              'DEEPENING THE FILL or changing the ink — not by lowering this '
              'bar. `py -3 tool/contrast_calc.py solve-tint <ink> <ground> '
              '4.6` derives a replacement. Note that a named external palette '
              '(Nord, Dracula, Solarized) may legitimately need its FILL '
              'darkened rather than its ink changed: the ink is usually white '
              'and there is nowhere lighter for it to go.',
        );
      });
    }
  });

  // A guard on the guard. If `pairsFor` ever silently stops covering a field,
  // every palette passes and this file becomes decoration.
  test('the pair list covers every colour a palette can paint text on', () {
    // The fields that are GROUNDS (something is written on them) and the
    // fields that are INKS. `divider`, `tabSelectedBg` and `bubbleSeparator`
    // are hairlines and fills that carry no text of their own.
    const grounds = {
      'header',
      'body',
      'incomingBubble',
      'outgoingBubble',
      'accent',
    };
    final covered = pairsFor(ChatThemes.palettes.first)
        .map((p) => p.what.split(' on ').last)
        .toSet();
    for (final g in grounds) {
      expect(
        covered.any((c) => c.contains(g)),
        isTrue,
        reason: 'Nothing in this file measures anything written on "$g". '
            'Either text is never drawn there — in which case say so here — '
            'or a pairing is going unmeasured.',
      );
    }
  });
}
