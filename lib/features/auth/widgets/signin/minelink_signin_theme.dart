// ============================================================================
// MineLink — Sign-in tokens & shared controls
// ----------------------------------------------------------------------------
// Self-contained on purpose. The sign-in screen renders before any session
// exists, so it must not reach into `insights_v2/` or anything else that
// assumes an authenticated user — a token file shared with the console would
// eventually pull a provider in behind it.
//
// Palette matches the console: gold is the brand mark, cyan is the action.
// ============================================================================

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// MlAuth moved to the design-token layer at S5-19 — it is a token table
// (surfaces, ink, brand, geometry, asset paths), not a widget. The file's
// own header explains why it must not depend on anything session-aware;
// `core/design/tokens/` satisfies that better than `features/auth/` did,
// since the token layer imports nothing but Flutter. Re-exported so every
// existing `import 'minelink_signin_theme.dart'` still resolves MlAuth.
export 'package:flutter_application_1/core/design/tokens/ml_auth_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_auth_tokens.dart';

/// Carries the "play anyway" override down the tree.
///
/// The platform setting is a request, not a verdict — the design offers a way
/// to watch the animation anyway (see [MlMotionNotice]), mirroring the
/// reference's `html.force-motion` class. Being an InheritedWidget means
/// [mlMotionEnabled] call sites need no change and everything that reads it —
/// including `MlBrandPanel.didChangeDependencies`, which starts and stops the
/// ambient clock — is rebuilt when the override flips.
class MlMotionScope extends InheritedWidget {
  const MlMotionScope({
    super.key,
    required this.forceMotion,
    required super.child,
  });

  final bool forceMotion;

  static bool forcedOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MlMotionScope>()?.forceMotion ??
      false;

  @override
  bool updateShouldNotify(MlMotionScope oldWidget) =>
      oldWidget.forceMotion != forceMotion;
}

/// Whether the platform asked for reduced motion, ignoring any override.
///
/// Use this to decide whether to OFFER the override; use [mlMotionEnabled] to
/// decide whether to animate.
bool mlReduceMotionRequested(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Whether decorative motion should run.
///
/// Honours the platform "reduce motion" setting unless the person has asked to
/// see it anyway. Everything ambient on this screen — rings, sweep, pings,
/// drift, dust — is decoration, so all of it stops. Functional transitions
/// (view changes, button states) still run, just shorter.
bool mlMotionEnabled(BuildContext context) =>
    MlMotionScope.forcedOf(context) || !mlReduceMotionRequested(context);

/// Shortens a duration when animations are disabled rather than removing the
/// transition, so state changes still read as changes.
Duration mlDuration(BuildContext context, Duration d) =>
    mlMotionEnabled(context) ? d : const Duration(milliseconds: 1);

// ===========================================================================
// Buttons
// ===========================================================================

/// What makes a hand-drawn auth button a BUTTON.
///
/// Both buttons on the sign-in card are drawn by hand — a gradient slab and a
/// tinted outline — so neither is a `ButtonStyleButton` and neither inherits
/// what one gives you for free. Until 2026-08-21 they inherited none of it,
/// and driving the redesign in a real browser is what showed it. The live
/// accessibility tree of the sign-in card, on the empty form every user meets
/// first, read:
///
///     button     "Show password"
///     button     "Forgot password?"
///     StaticText "Sign in"                    <- the primary action
///     button     "Sign in with WhatsApp code"
///
/// Three separate things were wrong, and only the first one is visible there:
///
///  1. **A disabled button vanished instead of announcing as disabled.**
///     `onPressed` is null until the form validates, so `GestureDetector.onTap`
///     was null, so the node carried no tap action and collapsed to a bare
///     string. A screen-reader user was told the sign-in screen has no sign-in
///     control — rather than that it has one and it is not ready yet, which is
///     the entire message that state exists to send.
///  2. **Neither was a button even when ENABLED.** The browser was being
///     generous: Flutter's web engine maps any tappable node to `role=button`
///     in the DOM, so the ghost button *looked* correct in the tree while
///     carrying no `isButton` flag at all. Under `flutter test`, which reads
///     the real semantics, both failed. A platform that infers less — and
///     every non-web one does — got neither.
///  3. **Neither could be reached by keyboard.** A `GestureDetector` takes no
///     focus, so Tab walked email -> password -> Show password -> Forgot
///     password and then straight past both buttons to the legal links. Enter
///     appeared to work only because the text field's own submit action fires
///     the same callback; from the password field alone, with nothing else
///     focused, there was no way to sign in without a pointer.
///
/// So it is all here, once, rather than twice and drifting:
///
///  * `Semantics(button, enabled, label)` with `excludeSemantics`, so the node
///    is one button carrying one label instead of a container wrapping a
///    string. The label is the EFFECTIVE one, which is why a busy button
///    announces "Signing in…" rather than the label under the spinner.
///  * `FocusableActionDetector` for focus, hover and Enter/Space. Its
///    `enabled` flag is the same `onPressed != null`, so a disabled button is
///    skipped by Tab rather than focused and inert.
///  * A visible focus ring, drawn by the caller through [focused] — keyboard
///    operability with no indicator is half a fix.
///
/// Pinned by `test/widgets/auth_buttons_are_buttons_test.dart`.
class _AuthPressable extends StatelessWidget {
  const _AuthPressable({
    required this.label,
    required this.onPressed,
    required this.onHover,
    required this.onFocus,
    required this.child,
    this.onDown,
  });

  /// What the button is ANNOUNCED as. Pass the busy label while busy.
  final String label;
  final VoidCallback? onPressed;
  final ValueChanged<bool> onHover;
  final ValueChanged<bool> onFocus;
  final ValueChanged<bool>? onDown;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      // The tap action has to be declared HERE, not left to the
      // `GestureDetector` below, because `excludeSemantics` drops everything
      // underneath — the label AND the action. Without this the node is a
      // button an assistive technology can see and cannot press, which is a
      // worse state than the one being fixed. Caught by the enabled-button
      // test, which asserts the action and not only the flags.
      onTap: onPressed,
      excludeSemantics: true,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor:
            enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onShowHoverHighlight: onHover,
        onShowFocusHighlight: onFocus,
        shortcuts: const <ShortcutActivator, Intent>{
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.numpadEnter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              onPressed?.call();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTapDown:
              enabled && onDown != null ? (_) => onDown!(true) : null,
          onTapUp: enabled && onDown != null ? (_) => onDown!(false) : null,
          onTapCancel: enabled && onDown != null ? () => onDown!(false) : null,
          onTap: enabled ? onPressed : null,
          child: child,
        ),
      ),
    );
  }
}

class MlPrimaryButton extends StatefulWidget {
  const MlPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.busyLabel,
    this.height = 52,
  });

  final String label;
  final String? busyLabel;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;

  @override
  State<MlPrimaryButton> createState() => _MlPrimaryButtonState();
}

class _MlPrimaryButtonState extends State<MlPrimaryButton> {
  bool _hover = false;
  bool _down = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;
    final effectiveLabel =
        widget.busy ? (widget.busyLabel ?? widget.label) : widget.label;

    return _AuthPressable(
      label: effectiveLabel,
      onPressed: enabled ? widget.onPressed : null,
      onHover: (v) => setState(() => _hover = v),
      onFocus: (v) => setState(() => _focused = v),
      onDown: (v) => setState(() => _down = v),
      child: AnimatedContainer(
          duration: mlDuration(context, const Duration(milliseconds: 150)),
          curve: Curves.easeOut,
          height: widget.height,
          transform: Matrix4.translationValues(
              0, (_hover && enabled && !_down) ? -1.5 : 0, 0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MlAuth.accent2, MlAuth.accent, MlAuth.accentDeep],
              stops: [0, .62, 1],
            ),
            borderRadius: BorderRadius.circular(MlAuth.fieldRadius),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: MlAuth.accent.withValues(
                          alpha: _hover ? 0.36 : 0.28),
                      blurRadius: _hover ? 42 : 34,
                      offset: Offset(0, _hover ? 18 : 14),
                    ),
                  ]
                : null,
          ),
          // The disabled veil, or — when the button has keyboard focus — the
          // focus ring. Both are drawn in FRONT so neither changes the
          // button's size: a ring that grew the box by 2px would move every
          // control under it the moment somebody pressed Tab.
          foregroundDecoration: !enabled
              ? BoxDecoration(
                  color: MlAuth.bg.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(MlAuth.fieldRadius),
                )
              : _focused
                  ? BoxDecoration(
                      border: Border.all(color: MlAuth.inkHi, width: 2),
                      borderRadius:
                          BorderRadius.circular(MlAuth.fieldRadius),
                    )
                  : null,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.busy) ...[
                const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(MlAuth.onAccent),
                    backgroundColor: MlAuth.onAccentTrack,
                  ),
                ),
                const SizedBox(width: 9),
              ],
              // Same reason as MlGhostButton: a non-flex child in a Row gets
              // unbounded width, so nothing would engage before it overran.
              Flexible(
                child: Text(
                  widget.busy
                      ? (widget.busyLabel ?? widget.label)
                      : widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: const TextStyle(
                    fontFamily: MlAuth.sans,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.14,
                    color: MlAuth.onAccent,
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

class MlGhostButton extends StatefulWidget {
  const MlGhostButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.tint = MlAuth.whatsapp,
  });

  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final Color tint;

  @override
  State<MlGhostButton> createState() => _MlGhostButtonState();
}

class _MlGhostButtonState extends State<MlGhostButton> {
  bool _hover = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return _AuthPressable(
      label: widget.label,
      onPressed: widget.onPressed,
      onHover: (v) => setState(() => _hover = v),
      onFocus: (v) => setState(() => _focused = v),
      child: AnimatedContainer(
          duration: mlDuration(context, const Duration(milliseconds: 150)),
          height: 52,
          transform: Matrix4.translationValues(0, _hover ? -1.5 : 0, 0),
          decoration: BoxDecoration(
            color: _hover
                ? widget.tint.withValues(alpha: 0.09)
                : MlAuth.tintRest,
            borderRadius: BorderRadius.circular(MlAuth.fieldRadius),
            // The focus ring is this button's own border, brightened and
            // doubled, rather than a second ring outside it — an outline
            // button already has the outline, and two concentric rings read
            // as a rendering fault rather than as focus.
            border: Border.all(
              width: _focused ? 2 : 1,
              color: _focused
                  ? MlAuth.inkHi
                  : _hover
                      ? widget.tint.withValues(alpha: 0.42)
                      : MlAuth.line2,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                widget.icon!,
                const SizedBox(width: 9),
              ],
              // Flexible, and allowed a second line. "Sign in with WhatsApp
              // code" plus its icon overran this Row by 43px at 380px wide and
              // text scale 1.3. Two lines of 18px still fit the 52px button,
              // and ellipsizing the only label on a button is worse than
              // wrapping it.
              Flexible(
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  style: context.mlText.titleSmall.copyWith(
                    color: _hover ? MlAuth.inkHiGood : MlAuth.inkHi,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }
}

// ===========================================================================
// Banner
// ===========================================================================

enum MlBannerKind { error, info }

/// Refusal notice. Carries the server's own wording — those messages are
/// written to be read by a person, so passing them through beats inventing a
/// generic failure line.
class MlBanner extends StatelessWidget {
  const MlBanner({
    super.key,
    required this.message,
    this.kind = MlBannerKind.error,
  });

  final String message;
  final MlBannerKind kind;

  @override
  Widget build(BuildContext context) {
    final error = kind == MlBannerKind.error;
    final tint = error ? MlAuth.bad : MlAuth.accent2;

    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.09),
        borderRadius: MlShape.radiusMedium,
        border: Border.all(color: tint.withValues(alpha: 0.34)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              error ? Icons.error_outline_rounded : Icons.info_outline_rounded,
              size: 15,
              color: tint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: context.mlText.bodyMedium.copyWith(
                color: error ? MlAuth.inkOnBad : MlAuth.inkOnAccentBanner,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Reduce-motion notice
// ===========================================================================

/// Says why the panel is still, and offers to animate it anyway.
///
/// Reduce motion is usually set once and forgotten — on Windows it is
/// Settings → Accessibility → Visual effects → Animation effects, and it is off
/// on plenty of machines that never asked for it. Without this card the brand
/// panel is simply inert with nothing to say, which reads as broken rather than
/// as respectful. "Play anyway" is a per-visit override: it never writes the
/// system setting, and dismissing with × leaves the motion off.
class MlMotionNotice extends StatelessWidget {
  const MlMotionNotice({
    super.key,
    required this.onPlayAnyway,
    required this.onDismiss,
  });

  final VoidCallback onPlayAnyway;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    // Deliberately NOT wrapped in mlDuration: this card only ever appears when
    // motion is being suppressed, so a 300ms entrance would contradict it. It
    // fades in over one frame.
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: math.min(360, MediaQuery.sizeOf(context).width - 36),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(15, 11, 13, 11),
        decoration: BoxDecoration(
          color: MlAuth.panel.withValues(alpha: 0.94),
          borderRadius: MlShape.radiusLarge,
          border: Border.all(color: MlAuth.line2),
          boxShadow: [
            BoxShadow(
              color: MlAuth.shadow,
              blurRadius: 44,
              offset: const Offset(0, 18),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MlAuth.warn,
                boxShadow: [
                  BoxShadow(
                    color: MlAuth.warn.withValues(alpha: 0.4),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Flexible so the copy wraps rather than pushing the button out.
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Animation is switched off on this device',
                    style: TextStyle(
                      fontFamily: MlAuth.sans,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: MlAuth.inkHi,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Your system asks apps to reduce motion, so the rings, '
                    'sweep and drift are paused.',
                    style: TextStyle(
                      fontFamily: MlAuth.sans,
                      fontSize: 12,
                      height: 1.4,
                      color: MlAuth.inkMid,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _NoticeAction(onPressed: onPlayAnyway),
            SizedBox(
              width: 28,
              child: IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, size: 15),
                color: MlAuth.inkLo,
                hoverColor: MlAuth.tintHover,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                splashRadius: 16,
                tooltip: 'Dismiss',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeAction extends StatefulWidget {
  const _NoticeAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_NoticeAction> createState() => _NoticeActionState();
}

class _NoticeActionState extends State<_NoticeAction> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _hover
                  ? const [MlAuth.accentLift1, MlAuth.accentLift2]
                  : const [MlAuth.accent2, MlAuth.accent],
            ),
            borderRadius: MlShape.radiusMedium,
          ),
          child: const Text(
            'Play anyway',
            maxLines: 1,
            style: TextStyle(
              fontFamily: MlAuth.sans,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MlAuth.onAccent,
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// Shake
// ===========================================================================

/// Wraps a child and shakes it when [trigger] changes. A refusal should be
/// felt as well as read.
class MlShake extends StatefulWidget {
  const MlShake({super.key, required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<MlShake> createState() => _MlShakeState();
}

class _MlShakeState extends State<MlShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );

  @override
  void didUpdateWidget(covariant MlShake old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger && widget.trigger > 0) {
      if (mlMotionEnabled(context)) {
        _c.forward(from: 0);
      } else {
        HapticFeedback.lightImpact();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          if (_c.isDismissed) return child!;
          // Decaying oscillation — four crossings, settling to zero.
          final t = _c.value;
          final dx = (1 - t) * 8 * math.sin(t * 4 * math.pi * 2);
          return Transform.translate(offset: Offset(dx, 0), child: child);
        },
        child: widget.child,
      );
}
