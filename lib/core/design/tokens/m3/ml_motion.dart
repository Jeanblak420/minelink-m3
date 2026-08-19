import 'package:flutter/material.dart';

/// Motion, expressed in Material 3's own `Durations` and `Easing` tokens.
///
/// The shipping app had three durations (`durFast` 140 / `durBase` 200 /
/// `durSlow` 260) and exactly one curve (`Curves.easeOutCubic`) applied to
/// entrances, exits and state changes alike. One curve for all three is what
/// makes an interface feel uniformly "animated" rather than responsive: an
/// element leaving should accelerate away, an element arriving should
/// decelerate in, and neither should behave like a hover tint changing.
///
/// M3 names the pairs, and Flutter ships them as `Durations` and `Easing`
/// (`package:flutter/src/material/motion.dart`). This class picks which pair
/// belongs to which job so the choice is made once.
///
/// ## What is deliberately NOT here
///
/// There is **no spring/physics motion**. Material 3 Expressive specifies
/// spring-based motion, but Flutter 3.44.8 — the SDK this project is built
/// against — ships no `MotionScheme` and no `ThemeData.motionScheme`; the
/// material library's `motion.dart` contains `Durations` and `Easing` and
/// nothing else. Anything claiming otherwise here would be an API that does
/// not exist. Cubic easing is what is available, and it is what this uses.
abstract final class MlMotion {
  const MlMotion._();

  // ---------------------------------------------------------------- durations

  /// A hover tint, a focus ring, a checkbox tick — feedback that must feel
  /// instant. Anything longer reads as lag on a pointer device.
  static const Duration instant = Durations.short2; // 100ms

  /// A control changing state: a button pressing, a chip selecting, a switch
  /// throwing, a row highlighting.
  static const Duration stateChange = Durations.short4; // 200ms

  /// Something arriving on screen: a card fading in, a panel expanding, a
  /// snackbar rising.
  static const Duration enter = Durations.medium2; // 300ms

  /// Something leaving. Deliberately shorter than [enter] — M3's asymmetry.
  /// A dismissal that takes as long as an arrival feels reluctant.
  static const Duration exit = Durations.short4; // 200ms

  /// A large surface transforming: a dialog opening, a side sheet sliding, a
  /// rail expanding from 80dp to 280dp.
  static const Duration expand = Durations.medium4; // 400ms

  /// A full-screen route transition.
  static const Duration page = Durations.long2; // 500ms

  /// A number counting up on a stat card. Long on purpose: this one is not
  /// feedback, it is a small piece of theatre, and it is the only duration
  /// here allowed to be noticed.
  static const Duration count = Durations.extralong2; // 800ms

  // ------------------------------------------------------------------- curves

  /// Default for a change with no strong direction — a colour, an opacity, a
  /// selection. Symmetric.
  static const Curve standard = Easing.standard;

  /// For something **arriving**. Fast at first, settling gently.
  static const Curve decelerate = Easing.emphasizedDecelerate;

  /// For something **leaving**. Slow to release, then away quickly.
  static const Curve accelerate = Easing.emphasizedAccelerate;

  /// For an element that enters from off-screen with no exit in the same
  /// gesture — a route pushing in.
  static const Curve enterCurve = Easing.standardDecelerate;

  /// For an element leaving to off-screen.
  static const Curve exitCurve = Easing.standardAccelerate;

  /// Linear. Only for a continuously running indicator (a spinner, a progress
  /// bar in indeterminate mode) where easing would make the loop visibly pulse.
  static const Curve linear = Easing.linear;

  // ------------------------------------------------------------ reduce motion

  /// The floor a "disabled" animation is clamped to. **Never `Duration.zero`.**
  ///
  /// This is not a style preference, it is a crash. With a zero duration an
  /// `AnimationController` notifies its listeners *synchronously* on `forward()`,
  /// which lands `AnimatedSize` inside a `markNeedsLayout()` during its own
  /// `performLayout` and throws. One millisecond defers the notification to the
  /// next frame and costs nothing perceptible.
  static const Duration reducedFloor = Duration(milliseconds: 1);

  /// [duration], honouring the platform's reduce-motion accessibility setting.
  ///
  /// Pass every animation duration through this. Reduce-motion is a genuine
  /// accessibility need — vestibular disorders are triggered by large moving
  /// surfaces — and it is set at the OS level, so an app that ignores it is
  /// ignoring a medical setting the user already went looking for.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
          ? reducedFloor
          : duration;

  /// [curve], flattened to linear when animations are disabled. A curve on a
  /// 1ms animation is meaningless, and `Easing.emphasized*` overshoot-free
  /// cubics still cost a lookup per frame.
  static Curve curveOf(BuildContext context, Curve curve) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false
          ? Easing.linear
          : curve;
}
