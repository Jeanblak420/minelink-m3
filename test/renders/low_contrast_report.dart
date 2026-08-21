// Contrast measured off the PIXELS a render actually painted.
//
// Companion to `redesign_renders_test.dart`, which calls
// [reportLowContrast] on every render. The reasoning for why this exists
// alongside `test/design/token_contrast_test.dart` is at the call site; the
// short version is that a token-pair audit cannot see a ground no token names,
// and the leaderboard's winner card drew at 2.2:1 on a gradient it built
// itself.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG relative luminance of an opaque colour, from 0-255 channels.
double _luminance(int r, int g, int b) {
  double ch(int v) {
    final f = v / 255.0;
    return f <= 0.03928 ? f / 12.92 : math.pow((f + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b);
}

double _ratio(double a, double b) {
  final hi = math.max(a, b);
  final lo = math.min(a, b);
  return (hi + 0.05) / (lo + 0.05);
}

/// One paragraph that came out too faint.
class LowContrastHit {
  LowContrastHit(this.text, this.ratio, this.required, this.where, this.ink,
      this.ground, this.rect);

  final String text;
  final double ratio;
  final double required;
  final String where;
  final int ink;
  final int ground;

  /// Where in the captured image, so a finding can be cropped and looked at.
  /// A report that cannot be checked against the picture is a report nobody
  /// can argue with.
  final Rect rect;

  String get inkHex =>
      '#${(ink & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  String get groundHex =>
      '#${(ground & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

/// Measures every laid-out paragraph in the tree against the pixels behind it
/// and prints the ones under WCAG AA.
///
/// Returns the hits so a caller can assert on them; the render harness only
/// prints.
Future<List<LowContrastHit>> reportLowContrast(
  WidgetTester tester,
  GlobalKey captureKey,
  String name,
  Size size,
) async {
  final boundary =
      captureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return const [];

  // `toImage` is genuinely asynchronous — the raster has to come back from the
  // engine — so it needs the real clock. Inside the fake-async zone the future
  // never completes and the test times out at ten minutes.
  ui.Image? image;
  ByteData? raw;
  await tester.runAsync(() async {
    image = await boundary.toImage();
    raw = await image!.toByteData(format: ui.ImageByteFormat.rawRgba);
  });
  if (raw == null || image == null) return const [];

  final pixels = raw!.buffer.asUint8List();
  final iw = image!.width;
  final ih = image!.height;
  image!.dispose();

  int at(int x, int y) {
    final i = (y * iw + x) * 4;
    return (pixels[i] << 16) | (pixels[i + 1] << 8) | pixels[i + 2];
  }

  final scaler = tester.platformDispatcher.textScaleFactor;
  final hits = <LowContrastHit>[];
  final seen = <String>{};

  void visit(Element e) {
    final ro = e.renderObject;
    if (ro is RenderParagraph && !ro.debugNeedsLayout && ro.hasSize) {
      final text = ro.text.toPlainText().trim();
      // An `Icon` is a RenderParagraph too — one private-use codepoint in a
      // font that has no notion of contrast the way a word does. Measuring
      // them reported a dozen empty-looking strings per screen.
      // Both private-use blocks: the BMP one (0xE000-0xF8FF, where Material
      // Icons live) and the two SUPPLEMENTARY planes, which is where the
      // icon fonts this app also ships put theirs. Checking only the first
      // let a 22px glyph through reporting `#9FB2CC on #DC2626`, which is a
      // white-ish icon on a red badge and not a string at all.
      final isIcon = text.runes.every((r) =>
          (r >= 0xE000 && r <= 0xF8FF) ||
          (r >= 0xF0000 && r <= 0xFFFFD) ||
          (r >= 0x100000 && r <= 0x10FFFD));
      if (text.isNotEmpty && !isIcon) {
        final hit = _measure(ro, text, at, iw, ih, scaler, e);
        if (hit != null && seen.add('${hit.text}|${hit.where}')) hits.add(hit);
      }
    }
    e.visitChildren(visit);
  }

  tester.allElements.first.visitAncestorElements((a) {
    visit(a);
    return false;
  });

  if (hits.isNotEmpty) {
    hits.sort((a, b) => a.ratio.compareTo(b.ratio));
    // ignore: avoid_print
    print('LOW CONTRAST [$name] ${hits.length} string(s) at '
        '${size.width.toInt()}x${size.height.toInt()}:');
    for (final h in hits) {
      // ignore: avoid_print
      print('  ~ ${h.text}');
      // ignore: avoid_print
      print('      ${h.ratio.toStringAsFixed(2)}:1 '
          '(needs ${h.required.toStringAsFixed(1)})  '
          'ink ${h.inkHex} on ${h.groundHex}   '
          'at ${h.rect.left.toInt()},${h.rect.top.toInt()} '
          '${h.rect.width.toInt()}x${h.rect.height.toInt()}   ${h.where}');
    }
  }
  return hits;
}

LowContrastHit? _measure(
  RenderParagraph ro,
  String text,
  int Function(int, int) at,
  int iw,
  int ih,
  double scaler,
  Element e,
) {
  final origin = ro.localToGlobal(Offset.zero);
  final left = origin.dx.floor();
  final top = origin.dy.floor();
  final right = (origin.dx + ro.size.width).ceil();
  final bottom = (origin.dy + ro.size.height).ceil();

  final x0 = math.max(0, left);
  final y0 = math.max(0, top);
  final x1 = math.min(iw, right);
  final y1 = math.min(ih, bottom);
  // Off-screen, clipped away, or too small to hold a glyph.
  if (x1 - x0 < 4 || y1 - y0 < 4) return null;

  // A stride keeps a full-page paragraph from costing a million samples while
  // still landing inside strokes: text is denser than 3px in both axes.
  final stride = ((x1 - x0) * (y1 - y0) > 240000) ? 2 : 1;

  // The declared ink, resolved first — it is needed to work out the ground.
  //
  // Two earlier versions took the ink from the pixels too, and both
  // under-reported badly at the sizes that matter most. At 9px a mono digit's
  // stroke is barely a pixel wide and anti-aliasing means it NEVER reaches the
  // declared colour anywhere in the raster: the axis label "05" is painted in
  // a slate the palette defines, and the strongest pixel the image contains
  // for it is `#B2BAC6` — lighter than the real ink, so the measured ratio was
  // 1.80:1 against a true value several times that.
  //
  // The ink does not need measuring. `RenderParagraph.text` carries the
  // resolved style, so the colour is known exactly — and knowing it exactly is
  // the point, because a colour is what somebody would change.
  final spanColors = <Color>{};
  ro.text.visitChildren((span) {
    if (span is TextSpan) {
      final c = span.style?.color;
      if (c != null) spanColors.add(c);
    }
    return true;
  });
  final rootColor = ro.text.style?.color;
  if (rootColor != null) spanColors.add(rootColor);
  if (spanColors.isEmpty) return null;

  bool nearInk(int c, int tol) {
    for (final ink in spanColors) {
      final dr = ((c >> 16) & 0xFF) - (ink.r * 255).round();
      final dg = ((c >> 8) & 0xFF) - (ink.g * 255).round();
      final db = (c & 0xFF) - (ink.b * 255).round();
      if (dr.abs() <= tol && dg.abs() <= tol && db.abs() <= tol) return true;
    }
    return false;
  }

  bool looksLikeInk(int c) => nearInk(c, 26);


  // THE GROUND IS THE MODAL COLOUR OF THE BOX, WITH THE INK EXCLUDED.
  //
  // Excluding it matters whenever the glyphs fill their box — a 32px bold
  // figure, a rank digit in a tight chip. Without the exclusion the mode IS
  // the ink, and the report said `ink #0B1526 on #0B1526 — 1.00:1` for
  // "+103%", which is not a contrast failure but a measurement eating itself.
  //
  // The ground is the half that genuinely needs the pixels, and it is the half
  // a token-pair audit cannot know: a gradient, a sheen over a panel, an alpha
  // stack, a card on a card. Taken inside the paragraph's own box, it is the
  // ground under THAT text, so a gradient reports differently for each string
  // sitting on a different part of it.
  final counts = <int, int>{};
  var considered = 0;
  for (var y = y0; y < y1; y += stride) {
    for (var x = x0; x < x1; x += stride) {
      final c = at(x, y);
      if (looksLikeInk(c)) continue;
      counts[c] = (counts[c] ?? 0) + 1;
      considered++;
    }
  }
  if (considered < 16) return null;

  var ground = 0xFFFFFF;
  var best = 0;
  counts.forEach((c, n) {
    if (n > best) {
      best = n;
      ground = c;
    }
  });

  final gl =
      _luminance((ground >> 16) & 0xFF, (ground >> 8) & 0xFF, ground & 0xFF);

  // A translucent ink is composited onto that measured ground before the
  // ratio, because a 60%-alpha slate on a white card and the same slate on a
  // navy one are different colours to a reader.
  var worst = double.infinity;
  var worstColor = ground;
  for (final c in spanColors) {
    final a = c.a;
    // Fully transparent ink is a deliberate blank — a spacer, a fade-out.
    if (a <= 0.02) continue;
    final r = ((c.r * 255).round() * a + ((ground >> 16) & 0xFF) * (1 - a));
    final g = ((c.g * 255).round() * a + ((ground >> 8) & 0xFF) * (1 - a));
    final b = ((c.b * 255).round() * a + (ground & 0xFF) * (1 - a));
    final ratio = _ratio(_luminance(r.round(), g.round(), b.round()), gl);
    if (ratio < worst) {
      worst = ratio;
      worstColor = (r.round() << 16) | (g.round() << 8) | b.round();
    }
  }
  if (worst == double.infinity) return null;

  // ── IS THE TEXT EVEN ON SCREEN? ─────────────────────────────────────────
  //
  // `localToGlobal` gives a paragraph's LAYOUT position, and a paragraph can
  // be laid out somewhere the raster never shows: inside a scrollable that is
  // scrolled past it, or under a clip. Sampling those coordinates measures
  // whatever IS painted there — a different widget entirely.
  //
  // That produced the worst-looking entries in the first full run: a rail
  // badge's `#450A0A` digit reported at 1.25:1 against `#020617`, in nine
  // renders. Cropping the picture at the coordinates it named showed an empty
  // stretch of rail. The digit was real, its colour was real, and it was
  // nowhere near that navy.
  //
  // Neither of the obvious guards catches it. "Is the box all one colour"
  // cannot: the rail carries a vertical gradient, so no two rows are
  // byte-identical. And it cannot move to the ground side either — once the
  // ink is excluded, a box with REAL text in it is also essentially one
  // colour.
  //
  // An ABSOLUTE tolerance on the ink does not work either: it has to be
  // generous enough for anti-aliasing at 9px, and `#020617` is within any such
  // tolerance of `#450A0A` — two dark colours are always near each other in
  // channel space.
  //
  // What does work is a RELATIVE test: a pixel belongs to this text if it is
  // closer to the ink than to the ground. Anti-aliased edges sit between the
  // two and are excluded by construction; glyph cores are past the midpoint
  // however faint the text is; and a box painted entirely in some third colour
  // has nothing closer to the ink than to its own ground.
  final ir = (worstColor >> 16) & 0xFF;
  final ig = (worstColor >> 8) & 0xFF;
  final ib = worstColor & 0xFF;
  final gr = (ground >> 16) & 0xFF;
  final gg = (ground >> 8) & 0xFF;
  final gb = ground & 0xFF;
  var inkPixels = 0;
  for (var y = y0; y < y1 && inkPixels < 3; y += stride) {
    for (var x = x0; x < x1 && inkPixels < 3; x += stride) {
      final c = at(x, y);
      final r = (c >> 16) & 0xFF;
      final g = (c >> 8) & 0xFF;
      final b = c & 0xFF;
      final di = (r - ir) * (r - ir) + (g - ig) * (g - ig) + (b - ib) * (b - ib);
      final dg2 = (r - gr) * (r - gr) + (g - gg) * (g - gg) + (b - gb) * (b - gb);
      if (di < dg2) inkPixels++;
    }
  }
  if (inkPixels < 3) return null;


  final style = ro.text.style;
  final px = (style?.fontSize ?? 14) * scaler;
  final bold = (style?.fontWeight?.value ?? FontWeight.w400.value) >=
      FontWeight.w700.value;
  final large = px >= 24 || (bold && px >= 18.66);
  final required = large ? 3.0 : 4.5;

  if (worst >= required) return null;

  final trail = <String>[];
  e.visitAncestorElements((a) {
    final n = a.widget.runtimeType.toString();
    if (n.startsWith('Ml') ||
        n.startsWith('_') ||
        n.endsWith('Screen') ||
        n.endsWith('Card') ||
        n.endsWith('Table') ||
        n.endsWith('Tile') ||
        n.endsWith('Row')) {
      if (trail.isEmpty || trail.last != n) trail.add(n);
    }
    return trail.length < 4;
  });

  return LowContrastHit(
    text.length > 60 ? '${text.substring(0, 60)}…' : text,
    worst,
    required,
    '${px.toStringAsFixed(0)}px${bold ? ' bold' : ''}  ${trail.join(' < ')}',
    worstColor,
    ground,
    Rect.fromLTRB(
        x0.toDouble(), y0.toDouble(), x1.toDouble(), y1.toDouble()),
  );
}

// ===========================================================================
// The ratchet
// ===========================================================================

/// Per-render hit counts recorded when the report was first trustworthy.
///
/// 1,859 strings across 190 renders, and they are real — the instrument was
/// checked against the pictures before this file was written, twice in each
/// direction: findings it named were cropped and looked at, and the ones it
/// named wrongly were tracked down to a cause and fixed rather than excluded.
///
/// **It is a baseline, not a target.** Clearing 1,859 of anything is not a
/// commit, and a check that fails until somebody does that is a check people
/// turn off. Recorded per render so it can only shrink, exactly as
/// `release_guards.dart` ratchets and for the same reason.
///
/// The concentration is the useful part. Two token pairs account for a large
/// share of it, and both are one decision each:
///
///   * `#FFFFFF` on `#22D3EE` — **1.81:1, in 18 renders.** White on the brand
///     accent: selected chips, filled buttons, count badges. The accent is a
///     LIGHT cyan, and white on it was never going to read. The product
///     already has the right ink for this — `MlAuth.onAccent` `#04202A` — and
///     the sign-in button uses it.
///   * `#22D3EE` on `#FFFFFF` — **1.81:1**, the same pair inverted: the accent
///     used as link text on a light card, e.g. every waybill number.
final Map<String, int> _baseline = () {
  final f = File('test/renders/low_contrast_baseline.json');
  if (!f.existsSync()) return <String, int>{};
  final raw = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  return raw.map((k, v) => MapEntry(k, v as int));
}();

/// Fails when a render gets FAINTER than it was.
///
/// Only for renders that actually ran, so a filtered run still checks what it
/// ran instead of failing over the ones it skipped.
void expectNoNewLowContrast(String render, int found) {
  final allowed = _baseline[render] ?? 0;
  expect(
    found,
    lessThanOrEqualTo(allowed),
    reason: '"$render" now has $found string(s) under WCAG AA, up from '
        '$allowed. Read the LOW CONTRAST block above — it names the ink, the '
        'ground it measured behind the text, and where in the image to crop. '
        'If the increase is deliberate, lower something else or update '
        'test/renders/low_contrast_baseline.json and say why in the commit.',
  );
}
