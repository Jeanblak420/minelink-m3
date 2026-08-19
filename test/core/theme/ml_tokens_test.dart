import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_scheme.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

void main() {
  group('MlTokens', () {
    test('brand and chrome colors match the design tokens', () {
      // S5-5, 2026-08-14: the accent moved from #00B5D8 to #22D3EE, and
      // accentHover from #0496B6 to #0891B2, to match the design reference
      // captured in docs/design-reference/ — the super-admin dashboard and
      // transporters overview, which the client designated as THE reference.
      //
      // This test failing on that change is the test working. It is pinned
      // deliberately so an accent can never drift by accident; updating it is
      // a decision, not a formality. See docs/design-reference.md §2.
      expect(MlTokens.accent, const Color(0xFF22D3EE));
      expect(MlTokens.accentHover, const Color(0xFF0891B2));
      expect(MlTokens.navy800, const Color(0xFF0B192E));
      expect(MlTokens.navy950, const Color(0xFF020617));
      expect(MlTokens.sidebarGradientTop, const Color(0xFF0C1C34));
      expect(MlTokens.sidebarGradientBottom, const Color(0xFF050B18));
      expect(MlTokens.sidebarActiveBlue, const Color(0xFF6AB8FF));
    });

    test('font families are the bundled ones', () {
      expect(MlTokens.fontSans, 'PlusJakartaSans');
      expect(MlTokens.fontMono, 'JetBrainsMono');
      expect(MlTokens.fontSerif, 'Fraunces');
    });

    test('radii ladder matches radius.css', () {
      expect(MlTokens.rSm, 8.0);
      expect(MlTokens.rMd, 12.0);
      expect(MlTokens.rLg, 16.0);
      expect(MlTokens.rXl, 20.0);
      expect(MlTokens.r2xl, 24.0);
    });
  });

  group('MlTone', () {
    test('light status pairs match semantic.css', () {
      final done = MlTone.done.colors(Brightness.light);
      expect(done.fg, const Color(0xFF15803D));
      expect(done.bg, const Color(0xFFDCFCE7));

      final transit = MlTone.transit.colors(Brightness.light);
      expect(transit.fg, const Color(0xFF2563EB));
      expect(transit.bg, const Color(0xFFEFF6FF));

      final atMine = MlTone.atMine.colors(Brightness.light);
      expect(atMine.fg, const Color(0xFFB45309));
      expect(atMine.bg, const Color(0xFFFEF3C7));
    });

    test('dark status pairs are the brightened remaps', () {
      final done = MlTone.done.colors(Brightness.dark);
      expect(done.fg, const Color(0xFF5CC487));
    });
  });

  group('MlSemantic', () {
    test('light surfaces', () {
      final s = MlSemantic.from(Brightness.light);
      expect(s.surfaceApp, const Color(0xFFF8FAFC));
      expect(s.surfaceCard, const Color(0xFFFFFFFF));
      expect(s.borderCard, const Color(0xFFE7EDF3));
      expect(s.textStrong, const Color(0xFF0F172A));
    });

    test('the three hairline greys are now one', () {
      // `borderSubtle`, `borderCard` and `divider` were #E2E8F0, #E7EDF3 and
      // #E9EEF4 — three separately-authored greys for one job, all within a
      // couple of steps of each other. Nothing ever depended on the
      // difference; it is below the threshold at which a 1px line is
      // distinguishable. They now all read `ColorScheme.outlineVariant`.
      //
      // This is the collapse working, not a value being lost. Asserted so a
      // future edit that re-splits them has to say why.
      for (final b in Brightness.values) {
        final s = MlSemantic.from(b);
        expect(s.borderSubtle, s.borderCard);
        expect(s.borderCard, s.divider);
      }
    });

    test('MlSemantic is a view onto the ColorScheme, not a parallel palette', () {
      // The point of the redesign in one assertion. These used to be
      // hand-authored constants sitting beside a ColorScheme seeded from a
      // different colour entirely, so `surfaceCard` and any scheme role that
      // also meant "card" were unrelated values.
      for (final b in Brightness.values) {
        final scheme = MlScheme.of(b);
        final s = MlSemantic.fromScheme(scheme);
        expect(s.surfaceApp, scheme.surface);
        expect(s.textStrong, scheme.onSurface);
        expect(s.textMuted, scheme.onSurfaceVariant);
        expect(s.borderStrong, scheme.outline);
        expect(s.divider, scheme.outlineVariant);
      }
    });

    test('dark surfaces match the [data-theme=dark] remap', () {
      final s = MlSemantic.from(Brightness.dark);
      expect(s.surfaceApp, const Color(0xFF0A1424));
      expect(s.surfaceCard, const Color(0xFF111C30));
      expect(s.surfaceRaised, const Color(0xFF16243C));
    });
  });
}
