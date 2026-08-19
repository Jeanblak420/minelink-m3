import 'dart:ui';

import 'package:flutter_application_1/core/design/tokens/ml_control_room_palette.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_test/flutter_test.dart';

/// S5-19. `MlControlRoom` exists because two super-admin screens each held a
/// private `_CrPalette` of the same name, transcribed by hand from two
/// different mocks, restating twenty-three values `MlGlass.dark` already held
/// — and disagreeing with each other on six of them.
///
/// The fix was to forward the shared keys to `MlGlass.dark`. This test is what
/// stops the fix being quietly undone: a forwarded member replaced by a
/// literal would still compile, still render, and be invisible in review. Each
/// case below asserts *identity with the source*, not equality with a value,
/// so pasting today's hex back in fails even though the pixels would match.
void main() {
  group('MlControlRoom forwards to MlGlass.dark and does not restate it', () {
    const g = MlGlass.dark;

    final forwarded = <String, (Color, Color)>{
      'pageBg': (MlControlRoom.pageBg, g.bg0),
      'bgRaised': (MlControlRoom.bgRaised, g.bg1),
      'bgPanelWash': (MlControlRoom.bgPanelWash, g.bg2),
      'glassSheenTop': (MlControlRoom.glassSheenTop, g.glassTop),
      'glassSheenBottom': (MlControlRoom.glassSheenBottom, g.glassBottom),
      'glassHighlight': (MlControlRoom.glassHighlight, g.line),
      'surfaceCard': (MlControlRoom.surfaceCard, g.panel),
      'surfaceCardDeep': (MlControlRoom.surfaceCardDeep, g.panel2),
      'tileBorder': (MlControlRoom.tileBorder, g.line),
      'borderCard': (MlControlRoom.borderCard, g.line2),
      'borderStrong': (MlControlRoom.borderStrong, g.lineStrong),
      'textStrong': (MlControlRoom.textStrong, g.inkHi),
      'textBody': (MlControlRoom.textBody, g.ink),
      'textMuted': (MlControlRoom.textMuted, g.inkMid),
      'textDim': (MlControlRoom.textDim, g.inkLo),
      'textFaint': (MlControlRoom.textFaint, g.inkXlo),
      'green': (MlControlRoom.green, g.good),
      'amber': (MlControlRoom.amber, g.warn),
      'red': (MlControlRoom.red, g.bad),
      'cyan': (MlControlRoom.cyan, g.accent),
      'cyanText': (MlControlRoom.cyanText, g.accent2),
      'teal': (MlControlRoom.teal, g.accent3),
      'violet': (MlControlRoom.violet, g.violet),
    };

    for (final e in forwarded.entries) {
      test('${e.key} is the same object as its MlGlass.dark source', () {
        expect(
          identical(e.value.$1, e.value.$2),
          isTrue,
          reason:
              'MlControlRoom.${e.key} must forward to MlGlass.dark, not restate '
              'its value. A literal here compiles and renders identically today '
              'and silently forks the palette the first time the glass surface '
              'is retuned — which is exactly how the two _CrPalette classes '
              'this token replaced came to disagree on six keys.',
        );
      });
    }

    test('the pre-composited glass base tracks its translucent source', () {
      // Written red first, against `glassBase = Color(0xFF0D1628)` — the
      // correct blend rounded to 8-bit channels — and it failed on a 1/255
      // difference in two channels. That is the whole argument for forwarding
      // rather than transcribing, in miniature, so the case is kept.
      expect(MlControlRoom.glassBase, Color.alphaBlend(g.glassBase, g.bg0));
      expect(
        MlControlRoom.glassBase.a,
        1.0,
        reason: 'the point of pre-compositing is that the result is opaque; '
            'Flutter cannot blur what is behind an opaque page.',
      );
    });

    test('both donut ramps start cyan → violet → pink', () {
      // The mock legend, and the reason the ramps are ordered rather than a
      // set. Guards against a reorder that would recolour every wedge.
      for (final ramp in [MlControlRoom.donutRamp, MlControlRoom.fleetRamp]) {
        expect(ramp.take(3).toList(),
            [MlControlRoom.cyan, MlControlRoom.violet, MlControlRoom.pink]);
        expect(ramp, hasLength(6));
      }
    });
  });
}
