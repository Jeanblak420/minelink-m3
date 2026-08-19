// How the in-app text-size preference meets the platform's.
//
// The defect this pins (docs/future-work.md item 3, fixed 2026-08-17): both
// shells did `textScaler: TextScaler.linear(prefs.textScale)`, which REPLACES
// the platform scaler. The recorded symptom was "an admin who runs their OS at
// 200% gets 130%". The unrecorded and worse one is the default case — the
// slider ships at 1.0, so a user who had never opened it got exactly 100% no
// matter what they had set at the OS level.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/core/layout/text_scale.dart';

/// A platform scaler that is NOT linear, so composition can be checked against
/// something that would survive being multiplied but not being replaced.
class _StepScaler extends TextScaler {
  const _StepScaler();

  /// Grows small text hard and large text gently — roughly what the
  /// non-linear platform curves do.
  @override
  double scale(double fontSize) => fontSize < 20 ? fontSize * 2 : fontSize + 20;

  @override
  double get textScaleFactor => 2;
}

void main() {
  group('mlTextScaler', () {
    test('leaves text alone when neither side asks for a change', () {
      final s = mlTextScaler(TextScaler.noScaling, 1.0);
      expect(s.scale(14), 14);
      expect(s.scale(9), 9);
    });

    test('honours the platform when the in-app slider was never touched', () {
      // The whole defect, in one assertion. 1.0 is the shipped default.
      final s = mlTextScaler(TextScaler.linear(2.0), 1.0);
      expect(s.scale(14), 28,
          reason: 'an OS setting of 200% must reach the text, not be replaced '
              'by the untouched in-app default');
    });

    test('honours the in-app slider when the platform asks for nothing', () {
      final s = mlTextScaler(TextScaler.noScaling, 1.3);
      expect(s.scale(10), closeTo(13, 0.001));
    });

    test('multiplies the two rather than picking one', () {
      final s = mlTextScaler(TextScaler.linear(1.5), 1.2);
      expect(s.scale(10), closeTo(18, 0.001)); // 10 * 1.2 * 1.5
    });

    test('caps the COMPOSED result at the scale the sweep proves', () {
      // 2.0 x 1.3 = 2.6, which no layout in this repo has been rendered at.
      final s = mlTextScaler(TextScaler.linear(2.0), 1.3);
      expect(s.scale(10), closeTo(10 * kMaxEffectiveTextScale, 0.001));
      expect(kMaxEffectiveTextScale, 2.0);
    });

    test('the cap is on the result, not on the preference', () {
      // Capping the preference alone is what produced the original defect: it
      // is why 200% became 130%. A platform scale at the ceiling must arrive
      // at the ceiling, not at the preference's ceiling.
      final atCeiling = mlTextScaler(
          TextScaler.linear(kMaxEffectiveTextScale), 1.0);
      expect(atCeiling.scale(10), closeTo(10 * kMaxEffectiveTextScale, 0.001));
    });

    test('a non-linear platform scaler keeps its own curve', () {
      // Composed by scaling the INPUT size, so the platform still decides how
      // a font of that size should be treated.
      final s = ComposedTextScaler(const _StepScaler(), 1.5);
      expect(s.scale(10), 30); // 10 * 1.5 = 15, still "small" -> doubled
      expect(s.scale(20), 50); // 20 * 1.5 = 30, "large" -> +20
    });

    test('equal scalers compare equal, so MediaQuery does not thrash', () {
      // MediaQueryData equality decides whether every descendant rebuilds. A
      // scaler that is never equal to itself makes the shell rebuild the whole
      // subtree on every frame.
      const a = ComposedTextScaler(TextScaler.noScaling, 1.1);
      const b = ComposedTextScaler(TextScaler.noScaling, 1.1);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(MediaQueryData(textScaler: a) == MediaQueryData(textScaler: b),
          isTrue);
      expect(a, isNot(equals(const ComposedTextScaler(
          TextScaler.noScaling, 1.2))));
    });
  });
}
