// ============================================================================
// MineLink — how the in-app text size meets the platform's
// ----------------------------------------------------------------------------
// The app has its own text-size control (Settings → User Preferences,
// `UiPrefs.textScale`, 0.85–1.3). The operating system has one too, and it is
// the one people with low vision actually use.
//
// Both shells used to REPLACE the platform scaler:
//
//     textScaler: TextScaler.linear(prefs.textScale)
//
// which discards the OS setting outright. Two consequences, and the second is
// the worse one:
//
//   * An admin running their OS at 200% got 130%, the app's ceiling.
//   * Anybody who had never touched the in-app slider — which is everybody,
//     since it defaults to 1.0 — got exactly 100%. The OS accessibility
//     setting was not merely capped, it was **ignored**, for every user, on
//     every screen of the product.
//
// Noted in docs/future-work.md as console-only. It had stopped being: the
// portal shell picked up the same line when the setting was extended to
// non-admin roles, so it applied to mines, buyers, transporters and drivers
// too. That file also set the order of work, which is the part that matters —
// composing without first proving the layouts survive the larger scale trades
// a readability defect for a set of layout ones.
//
// So: compose, then clamp at a bound the sweep actually proves.
// ============================================================================

import 'package:flutter/widgets.dart';

/// The largest effective text scale MineLink renders.
///
/// This is a **proof boundary, not a preference.**
/// `test/widgets/super_admin_overflow_sweep_test.dart` renders every console
/// screen at each of its widths up to this value, so raising it means
/// extending that sweep first and fixing what it finds. The sweep asserts that
/// its own top scale is >= this constant, so the two cannot drift apart.
///
/// Four real overflows were found and fixed on 2026-08-17 when the sweep was
/// first raised from 1.3 to 2.0 — an org-type pill, an "Open workspace"
/// button, two chart legends starved by an unflexed axis caption, and a
/// leaderboard row. None were visible below 1.6.
const double kMaxEffectiveTextScale = 2.0;

/// [base] with [factor] applied on top, rather than instead of it.
///
/// Scales the *input* font size rather than the base's output, so a non-linear
/// platform scaler keeps its own curve: asking for a bigger font is what the
/// user's preference means, and it is not the same as stretching whatever the
/// platform returned.
@immutable
class ComposedTextScaler extends TextScaler {
  const ComposedTextScaler(this.base, this.factor);

  final TextScaler base;
  final double factor;

  @override
  double scale(double fontSize) => base.scale(fontSize * factor);

  @override
  // ignore: deprecated_member_use
  double get textScaleFactor => base.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComposedTextScaler &&
          other.base == base &&
          other.factor == factor;

  @override
  int get hashCode => Object.hash(base, factor);

  @override
  String toString() => 'ComposedTextScaler($base x $factor)';
}

/// The scaler a MineLink shell should install: the platform's, multiplied by
/// the user's in-app preference, capped at [kMaxEffectiveTextScale].
///
/// The cap is on the COMPOSED result, not on either input. Capping the
/// preference alone is what produced the original defect.
TextScaler mlTextScaler(TextScaler platform, double appFactor) =>
    ComposedTextScaler(platform, appFactor)
        .clamp(maxScaleFactor: kMaxEffectiveTextScale);
