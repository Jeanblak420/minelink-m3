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

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.busy;

    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: enabled ? widget.onPressed : null,
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
          foregroundDecoration: enabled
              ? null
              : BoxDecoration(
                  color: MlAuth.bg.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(MlAuth.fieldRadius),
                ),
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

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: mlDuration(context, const Duration(milliseconds: 150)),
          height: 52,
          transform: Matrix4.translationValues(0, _hover ? -1.5 : 0, 0),
          decoration: BoxDecoration(
            color: _hover
                ? widget.tint.withValues(alpha: 0.09)
                : MlAuth.tintRest,
            borderRadius: BorderRadius.circular(MlAuth.fieldRadius),
            border: Border.all(
              color: _hover
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
                  style: TextStyle(
                    fontFamily: MlAuth.sans,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _hover ? MlAuth.inkHiGood : MlAuth.inkHi,
                  ),
                ),
              ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(12),
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
              style: TextStyle(
                fontFamily: MlAuth.sans,
                fontSize: 12.5,
                height: 1.5,
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
          borderRadius: BorderRadius.circular(13),
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
                      fontSize: 12.5,
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
            borderRadius: BorderRadius.circular(9),
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
