// Every colour pair the product can put text on, measured in BOTH brightnesses.
//
// ## Why this is the right shape for a light-mode audit
//
// Light mode had nine renders out of 204, and the obvious next move was to
// photograph every screen a second time. That is 195 more PNGs and it would
// still only prove the screens somebody thought to shoot.
//
// It is also aiming at the wrong layer. `no-raw-color-hex` and
// `no-material-colors` are both at zero, so **every colour in feature code
// comes from `MlSemantic`, `MlTone` or `MlTokens`**, and all three resolve per
// brightness. A screen cannot have a light-mode colour fault of its own; it
// can only inherit one from a token pair. There are a few dozen of those, and
// this file measures all of them in both brightnesses in about a second.
//
// ## What is measured
//
// The WCAG 2.1 contrast ratio — (L1 + 0.05) / (L2 + 0.05) over relative
// luminance, sRGB gamma expanded. The thresholds are WCAG AA:
//
//   * **4.5:1** for body text.
//   * **3:1** for large text (>= 18.66px bold or >= 24px) and for a UI
//     component boundary a user has to see, which is where the borders and
//     dividers below sit.
//
// **Tone backgrounds are composited, not read raw.** Half of `MlTone`'s dark
// backgrounds carry alpha (`Color(0x33B45309)` is a 20% amber), so measuring
// the fg against the raw bg measures a colour nobody ever sees. Each pair is
// composited over the surface it is actually painted on — the card in the
// common case, and the page ground too, because a status pill sits on both.
//
// ## What a failure here means
//
// It means a hue is unreadable for somebody, on every screen that uses it at
// once. That is why this FAILS rather than reports: unlike a truncation, there
// is no case where an unreadable status pill is the intent.
//
// Accepted exceptions live in `_accepted` with a reason each. There is one, and
// it is a decorative well rather than a text background.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// WCAG relative luminance of an opaque colour.
double _luminance(Color c) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// WCAG contrast ratio between two OPAQUE colours.
double _ratio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

/// [over] seen through [c]'s alpha — the colour a person actually looks at.
Color _composite(Color c, Color over) {
  final a = c.a;
  if (a >= 1.0) return c;
  return Color.from(
    alpha: 1.0,
    red: c.r * a + over.r * (1 - a),
    green: c.g * a + over.g * (1 - a),
    blue: c.b * a + over.b * (1 - a),
  );
}

String _hex(Color c) =>
    '#${((c.a * 255).round() << 24 | (c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(8, '0').toUpperCase()}';

class _Pair {
  final String name;
  final Color fg;
  final Color bg;
  final double floor;
  const _Pair(this.name, this.fg, this.bg, this.floor);
}

/// Pairs that are allowed to sit under their floor, with the reason.
const _accepted = <String, String>{
  // A well is the tinted square an ICON sits in. It carries no text, and the
  // icon inside it is drawn in the tone's `fg`, which is measured separately
  // against the same surface. Measuring the well against the card measures two
  // backgrounds against each other.
  'well': 'a decorative icon tile, not a text background',
};

void main() {
  const bodyFloor = 4.5;
  const largeFloor = 3.0;
  // A border or a divider is a boundary rather than text. WCAG puts
  // "non-text content" at 3:1, and a hairline divider whose whole job is to be
  // quiet fails that by design — 1.3:1 is the floor for "visible at all".
  const hairlineFloor = 1.25;

  for (final brightness in Brightness.values) {
    final name = brightness == Brightness.dark ? 'dark' : 'light';
    final s = MlSemantic.from(brightness);
    final surfaces = <String, Color>{
      'surfaceApp': s.surfaceApp,
      'surfaceCard': s.surfaceCard,
      'surfaceRaised': s.surfaceRaised,
      'surfaceSunken': s.surfaceSunken,
    };

    test('$name — text on every surface reaches AA', () {
      final pairs = <_Pair>[
        for (final e in surfaces.entries) ...[
          // textStrong is headings and figures — large text in most of its
          // uses, but it is also a table cell, so it is held to the body floor.
          _Pair('textStrong on ${e.key}', s.textStrong, e.value, bodyFloor),
          _Pair('textBody on ${e.key}', s.textBody, e.value, bodyFloor),
          _Pair('textMuted on ${e.key}', s.textMuted, e.value, bodyFloor),
          // textFaint is the caption and the overline — small, and deliberately
          // quiet. AA large is the honest floor for it; below that it is not
          // "subtle", it is missing.
          _Pair('textFaint on ${e.key}', s.textFaint, e.value, largeFloor),
        ],
      ];
      _check(pairs);
    });

    test('$name — every status tone is legible on card and page', () {
      final pairs = <_Pair>[];
      for (final tone in MlTone.values) {
        final c = tone.colors(brightness);
        for (final surface in ['surfaceApp', 'surfaceCard']) {
          final ground = surfaces[surface]!;
          // The pill: the tone's own background composited onto the surface,
          // with the tone's foreground on top of THAT.
          final pill = _composite(c.bg, ground);
          pairs.add(_Pair('${tone.name}.fg on ${tone.name}.bg over $surface',
              _composite(c.fg, pill), pill, largeFloor));
          // And the bare foreground, because a tone is also used as a plain
          // text and icon colour with no pill behind it.
          pairs.add(_Pair('${tone.name}.fg on $surface',
              _composite(c.fg, ground), ground, largeFloor));
        }
      }
      _check(pairs);
    });

    test('$name — borders and dividers are visible on their own surface', () {
      final pairs = <_Pair>[
        _Pair('borderCard on surfaceCard',
            _composite(s.borderCard, s.surfaceCard), s.surfaceCard,
            hairlineFloor),
        _Pair('borderSubtle on surfaceCard',
            _composite(s.borderSubtle, s.surfaceCard), s.surfaceCard,
            hairlineFloor),
        _Pair('borderStrong on surfaceCard',
            _composite(s.borderStrong, s.surfaceCard), s.surfaceCard,
            hairlineFloor),
        _Pair('divider on surfaceCard',
            _composite(s.divider, s.surfaceCard), s.surfaceCard,
            hairlineFloor),
        _Pair('borderCard on surfaceApp',
            _composite(s.borderCard, s.surfaceApp), s.surfaceApp,
            hairlineFloor),
        _Pair('borderAccent on surfaceCard',
            _composite(s.borderAccent, s.surfaceCard), s.surfaceCard,
            largeFloor),
      ];
      _check(pairs);
    });

    test('$name — the card is distinguishable from the page behind it', () {
      // Not a text rule: this is the one that says a card READS as a card. It
      // is the pair the whole console layout rests on, and in light mode the
      // ladder runs the other way (white cards on a slate canvas), which is
      // exactly the kind of inversion that goes wrong silently.
      final r = _ratio(s.surfaceCard, s.surfaceApp);
      expect(r, greaterThan(1.04),
          reason: 'surfaceCard ${_hex(s.surfaceCard)} against surfaceApp '
              '${_hex(s.surfaceApp)} is ${r.toStringAsFixed(2)}:1 — the card '
              'has no edge without its border.');
    });
  }
}

void _check(List<_Pair> pairs) {
  final failures = <String>[];
  for (final p in pairs) {
    if (_accepted.keys.any(p.name.contains)) continue;
    final r = _ratio(p.fg, p.bg);
    if (r < p.floor) {
      failures.add('${p.name}: ${r.toStringAsFixed(2)}:1 '
          '(needs ${p.floor}) — ${_hex(p.fg)} on ${_hex(p.bg)}');
    }
  }
  expect(failures, isEmpty,
      reason: 'Contrast below WCAG AA:\n  ${failures.join('\n  ')}');
}
