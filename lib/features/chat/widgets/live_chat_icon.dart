import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;

import 'package:flutter_application_1/core/utils/pointer_position_tracker.dart';
import 'package:flutter_application_1/core/design/tokens/ml_brand_artwork.dart';

/// A lively, "fake-3D" chat icon that turns to face the pointer.
///
/// Pure Flutter — `CustomPaint` + a `Matrix4` perspective tilt. There is **no**
/// 3D engine, no GL, no image asset and no extra dependency, so it is cheap
/// enough to live on every screen and works identically on mobile, Windows
/// desktop and web.
///
/// MineLink palette: the glossy disc is CYAN (design `LiveChatIcon` accent
/// `#00B5D8`), the unread badge glossy red, the typing bubble glossy orange —
/// mirroring `templates/chat/live-chat-icon.jsx`.
///
/// The illusion of a solid, glossy disc is built from five cooperating tricks
/// rather than real geometry:
///   1. A perspective tilt of the whole disc toward the pointer (`Matrix4`).
///   2. A stacked, offset rim that fakes the extruded thickness of a coin.
///   3. A specular highlight that slides across the glossy face as it tilts.
///   4. Parallax — the speech bubble floats above the disc so it pops out.
///   5. A soft contact shadow that swings opposite the tilt.
class LiveChatIcon extends StatefulWidget {
  const LiveChatIcon({
    super.key,
    this.size = 48,
    this.showCircuit,
    this.maxTilt = 0.45,
    this.cursorTracking = true,
    this.unreadCount = 0,
    this.isTyping = false,
    this.semanticLabel = 'Messages',
  });

  /// Side length of the (square) widget. The disc occupies the inner ~72 %,
  /// leaving room for the circuit traces, thickness and shadow to spill out.
  final double size;

  /// Whether to draw the radiating circuit traces. Defaults to drawing them
  /// only when [size] is large enough for them to read (>= 44 px).
  final bool? showCircuit;

  /// Maximum tilt, in radians, applied on each axis at full pointer deflection.
  final double maxTilt;

  /// When true (and motion is allowed), the disc turns to face the mouse
  /// cursor anywhere on screen via [PointerPositionTracker].
  final bool cursorTracking;

  /// Unread message count. When > 0 a glossy 3D red badge is drawn top-right.
  final int unreadCount;

  /// When true, an animated "typing…" bubble is shown at the bottom-right.
  final bool isTyping;

  /// Accessibility label.
  final String semanticLabel;

  @override
  State<LiveChatIcon> createState() => _LiveChatIconState();
}

class _LiveChatIconState extends State<LiveChatIcon>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  /// Smoothed current tilt that chases the gaze target / idle sway.
  Offset _current = Offset.zero;

  bool _pressed = false;
  double _press = 0; // smoothed 0..1 press depth
  double _idlePhase = 0;
  Duration _last = Duration.zero;
  bool _motion = true;

  /// Distance (logical px) from the icon at which the gaze reaches full tilt.
  static const double _gazeReach = 320.0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _setMotion(bool on) {
    if (on == _motion && _ticker.isActive == on) return;
    _motion = on;
    if (on) {
      if (!_ticker.isActive) {
        _last = Duration.zero;
        _ticker.start();
      }
    } else {
      if (_ticker.isActive) _ticker.stop();
      _current = Offset.zero;
      _press = 0;
      _frame.value++;
    }
  }

  void _onTick(Duration elapsed) {
    final double dt = _last == Duration.zero
        ? 0.016
        : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _idlePhase += dt;

    // Gentle figure-of-eight breathing used until a cursor is known.
    final Offset idle = Offset(
      math.sin(_idlePhase * 1.1) * 0.30,
      math.sin(_idlePhase * 0.8 + 1.3) * 0.22,
    );

    final Offset? gaze = _gazeTarget();
    final Offset desired = gaze ?? idle;

    // Critically-damped chase: frame-rate independent exponential smoothing.
    final double k = 1 - math.exp(-dt * 11);
    _current += (desired - _current) * k;

    final double pk = 1 - math.exp(-dt * 16);
    _press += ((_pressed ? 1.0 : 0.0) - _press) * pk;

    _frame.value = elapsed.inMilliseconds;
  }

  /// Direction (-1..1 per axis) from the icon's on-screen centre toward the
  /// global cursor, or null when the cursor position is unknown.
  Offset? _gazeTarget() {
    final Offset? cursor = PointerPositionTracker.instance.position.value;
    if (cursor == null) return null;
    final RenderObject? ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize || !ro.attached) return null;
    final Offset centre = ro.localToGlobal(ro.size.center(Offset.zero));
    final Offset delta = cursor - centre;
    final double dist = delta.distance;
    if (dist < 0.5) return Offset.zero;
    final double mag = (dist / _gazeReach).clamp(0.0, 1.0);
    return (delta / dist) * mag;
  }

  @override
  Widget build(BuildContext context) {
    final bool motionOn = widget.cursorTracking;
    // Toggle the ticker after this frame so we never mutate during build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _setMotion(motionOn);
    });

    final bool showCircuit = widget.showCircuit ?? widget.size >= 44;

    Widget paintLayer = ValueListenableBuilder<int>(
      valueListenable: _frame,
      builder: (context, _, _) {
        final Offset tilt = motionOn ? _current : Offset.zero;
        final double press = motionOn ? _press : 0;

        final Matrix4 m = Matrix4.identity()
          ..setEntry(3, 2, 0.0016)
          ..rotateX(-tilt.dy * widget.maxTilt)
          ..rotateY(tilt.dx * widget.maxTilt)
          ..scaleByDouble(
            1 - press * 0.07,
            1 - press * 0.07,
            1,
            1,
          );

        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            CustomPaint(
              size: Size.square(widget.size),
              painter: _ShadowPainter(tilt: tilt, press: press),
            ),
            Transform(
              alignment: Alignment.center,
              transform: m,
              child: CustomPaint(
                size: Size.square(widget.size),
                painter: _ChatDiscPainter(
                  tilt: tilt,
                  press: press,
                  idlePhase: _idlePhase,
                  showCircuit: showCircuit,
                  animate: motionOn,
                ),
              ),
            ),
            if (widget.isTyping)
              Positioned(
                right: widget.size * 0.02,
                bottom: widget.size * 0.06,
                child: ChatTypingBubble(size: widget.size * 0.46),
              ),
            if (widget.unreadCount > 0)
              Positioned(
                right: -widget.size * 0.04,
                top: -widget.size * 0.02,
                child: ChatUnreadBadge3D(
                  count: widget.unreadCount,
                  diameter: widget.size * 0.42,
                ),
              ),
          ],
        );
      },
    );

    return Semantics(
      label: widget.semanticLabel,
      button: true,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => _pressed = true,
            onPointerUp: (_) => _pressed = false,
            onPointerCancel: (_) => _pressed = false,
            child: paintLayer,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glossy 3D unread badge (top-right)
// ─────────────────────────────────────────────────────────────────────────────

/// A bold, glossy red unread badge — a lit radial-red pill with a light rim,
/// soft red glow and a drop shadow.
class ChatUnreadBadge3D extends StatelessWidget {
  const ChatUnreadBadge3D({
    super.key,
    required this.count,
    this.diameter = 22,
  });

  final int count;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final String label = count > 99 ? '99+' : '$count';
    final bool wide = label.length > 1;
    final double radius = diameter;

    return Container(
      constraints: BoxConstraints(minWidth: diameter, minHeight: diameter),
      padding: EdgeInsets.symmetric(horizontal: wide ? diameter * 0.26 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: _glaze.withValues(alpha: 0.85),
          width: (diameter * 0.06).clamp(1.0, 2.0),
        ),
        boxShadow: [
          BoxShadow(
            color: _shade.withValues(alpha: 0.38),
            blurRadius: diameter * 0.22,
            offset: Offset(0, diameter * 0.09),
          ),
          BoxShadow(
            color: MlLiveChatIconArt.badgeMain.withValues(alpha: 0.45),
            blurRadius: diameter * 0.30,
            spreadRadius: diameter * 0.02,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(-0.4, -0.55),
                    radius: 1.1,
                    colors: [
                      MlLiveChatIconArt.badgeBright,
                      MlLiveChatIconArt.badgeMain,
                      MlLiveChatIconArt.badgeDeep,
                    ],
                    stops: [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -diameter * 0.18,
              child: Container(
                width: diameter * 0.7,
                height: diameter * 0.5,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(diameter),
                  gradient: RadialGradient(
                    colors: [
                      _glaze.withValues(alpha: 0.55),
                      _glaze.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: diameter * 0.06),
              child: Text(
                label,
                style: TextStyle(
                  color: _glaze,
                  fontWeight: FontWeight.w800,
                  fontSize: diameter * 0.5,
                  height: 1.0,
                  shadows: const [
                    Shadow(color: MlLiveChatIconArt.numeralShadow, blurRadius: 1.5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated typing bubble (bottom-right) — glossy orange
// ─────────────────────────────────────────────────────────────────────────────

class ChatTypingBubble extends StatefulWidget {
  const ChatTypingBubble({super.key, this.size = 26});

  final double size;

  @override
  State<ChatTypingBubble> createState() => _ChatTypingBubbleState();
}

class _ChatTypingBubbleState extends State<ChatTypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const List<int> _phaseLitCount = [3, 1, 2];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double w = widget.size;
    final double h = widget.size * 0.74;
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    return SizedBox(
      width: w,
      height: h,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final int phase = reduceMotion
              ? 0
              : (_controller.value * _phaseLitCount.length).floor() %
                  _phaseLitCount.length;
          final int lit = reduceMotion ? 3 : _phaseLitCount[phase];
          return CustomPaint(
            size: Size(w, h),
            painter: _TypingBubblePainter(litDots: lit),
          );
        },
      ),
    );
  }
}

class _TypingBubblePainter extends CustomPainter {
  _TypingBubblePainter({required this.litDots});

  final int litDots;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Rect body = Rect.fromLTWH(0, 0, w, h * 0.82);
    final RRect bubble = RRect.fromRectAndRadius(
      body,
      Radius.circular(body.height / 2),
    );

    canvas.drawRRect(
      bubble.shift(Offset(0, h * 0.05)),
      Paint()
        ..color = _shade.withValues(alpha: 0.32)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, h * 0.06),
    );

    final Path tail = Path()
      ..moveTo(w * 0.20, body.bottom - h * 0.04)
      ..lineTo(w * 0.40, body.bottom - h * 0.04)
      ..lineTo(w * 0.12, h * 0.99)
      ..close();
    canvas.drawPath(tail, Paint()..color = _bDeep);

    canvas.drawRRect(
      bubble,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_bBright, _bOrange, _bDeep],
          stops: [0.0, 0.55, 1.0],
        ).createShader(body),
    );
    canvas.drawRRect(
      bubble.deflate(0.6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = (h * 0.05).clamp(0.8, 1.6)
        ..color = _glaze.withValues(alpha: 0.30),
    );
    canvas.save();
    canvas.clipRRect(bubble);
    final Rect gloss = Rect.fromLTWH(
      w * 0.1,
      -body.height * 0.35,
      w * 0.8,
      body.height * 0.7,
    );
    canvas.drawOval(
      gloss,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _glaze.withValues(alpha: 0.45),
            _glaze.withValues(alpha: 0.0),
          ],
        ).createShader(gloss),
    );
    canvas.restore();

    final double cy = body.center.dy;
    final double dotR = h * 0.11;
    final double step = dotR * 2.5;
    for (int i = 0; i < 3; i++) {
      final Offset c = Offset(w / 2 + (i - 1) * step, cy);
      final bool on = i < litDots;
      if (on) {
        canvas.drawCircle(
          c,
          dotR * 1.7,
          Paint()
            ..color = _glaze.withValues(alpha: 0.45)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, dotR * 0.7),
        );
      }
      canvas.drawCircle(
        c,
        on ? dotR : dotR * 0.82,
        Paint()..color = _glaze.withValues(alpha: on ? 1.0 : 0.40),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TypingBubblePainter old) =>
      old.litDots != litDots;
}

// ─────────────────────────────────────────────────────────────────────────────
// Palette
// ─────────────────────────────────────────────────────────────────────────────

// The mark's artwork palette now lives in the design-token layer
// (`ml_brand_artwork.dart`) — see that file for why an artwork colour is not a
// UI colour. These short aliases keep the painters below reading as drawing
// code rather than as a wall of qualified names.
const Color _dBright = MlLiveChatIconArt.discBright;
const Color _dMain = MlLiveChatIconArt.discMain;
const Color _dDeep = MlLiveChatIconArt.discDeep;
const Color _dDark = MlLiveChatIconArt.discDark;
const Color _dRim = MlLiveChatIconArt.discRim;

const Color _bBright = MlLiveChatIconArt.bubbleBright;
const Color _bOrange = MlLiveChatIconArt.bubbleMain;
const Color _bDeep = MlLiveChatIconArt.bubbleDeep;

const Color _cBubble = MlLiveChatIconArt.markFace;
const Color _cBubbleShade = MlLiveChatIconArt.markShade;
const Color _cLine = MlLiveChatIconArt.markLine;

/// White and black as paint — see [MlLiveChatIconArt.glaze].
const Color _glaze = MlLiveChatIconArt.glaze;
const Color _shade = MlLiveChatIconArt.shade;

// ─────────────────────────────────────────────────────────────────────────────
// Contact shadow (drawn flat under the tilted disc)
// ─────────────────────────────────────────────────────────────────────────────

class _ShadowPainter extends CustomPainter {
  _ShadowPainter({required this.tilt, required this.press});

  final Offset tilt;
  final double press;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = s * 0.36;

    final Offset off =
        Offset(-tilt.dx, -tilt.dy) * (r * 0.22) + Offset(0, r * 0.30);
    final double spread = 1.0 - press * 0.18;
    final Rect rect = Rect.fromCenter(
      center: c + off,
      width: r * 1.9 * spread,
      height: r * 1.15 * spread,
    );
    final Paint p = Paint()
      ..color = _shade.withValues(alpha: 0.34 - press * 0.06)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05);
    canvas.drawOval(rect, p);
  }

  @override
  bool shouldRepaint(covariant _ShadowPainter old) =>
      old.tilt != tilt || old.press != press;
}

// ─────────────────────────────────────────────────────────────────────────────
// The disc: circuit → thickness → face → gloss → bubble
// ─────────────────────────────────────────────────────────────────────────────

class _ChatDiscPainter extends CustomPainter {
  _ChatDiscPainter({
    required this.tilt,
    required this.press,
    required this.idlePhase,
    required this.showCircuit,
    required this.animate,
  });

  final Offset tilt;
  final double press;
  final double idlePhase;
  final bool showCircuit;
  final bool animate;

  @override
  void paint(Canvas canvas, Size size) {
    final double s = size.shortestSide;
    final Offset c = Offset(size.width / 2, size.height / 2);
    final double r = s * 0.36; // disc radius

    if (showCircuit) _paintCircuit(canvas, c, r, s);
    _paintThickness(canvas, c, r);
    _paintFace(canvas, c, r);
    _paintGloss(canvas, c, r * 0.86);
    _paintBubble(canvas, c, r, s);
  }

  void _paintCircuit(Canvas canvas, Offset c, double r, double s) {
    final Offset cc = c + Offset(-tilt.dx, -tilt.dy) * (s * 0.012);
    const int n = 11;
    final double stroke = (s * 0.013).clamp(0.7, 3.0);
    for (int i = 0; i < n; i++) {
      final double ang = (i / n) * math.pi * 2 + 0.25;
      final Offset dir = Offset(math.cos(ang), math.sin(ang));
      final double pulse = animate
          ? 0.45 + 0.30 * math.sin(idlePhase * 2.6 + i * 0.9)
          : 0.5;
      final Offset start = cc + dir * (r * 1.02);
      final Offset elbow = cc + dir * (r * 1.16);
      final Offset perp =
          Offset(-dir.dy, dir.dx) * (r * 0.07 * (i.isEven ? 1 : -1));
      final Offset end = elbow + perp + dir * (r * 0.10);

      final Paint line = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = _dRim.withValues(alpha: pulse.clamp(0.0, 1.0));
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(elbow.dx, elbow.dy)
          ..lineTo(end.dx, end.dy),
        line,
      );

      final double nodeR = (s * 0.022).clamp(1.2, 4.5);
      canvas.drawCircle(
        end,
        nodeR,
        Paint()
          ..color = _dBright.withValues(alpha: (pulse + 0.2).clamp(0.0, 1.0)),
      );
      canvas.drawCircle(
        end,
        nodeR * 1.9,
        Paint()
          ..color = _dRim.withValues(alpha: 0.18 * pulse)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.02),
      );
    }
  }

  void _paintThickness(Canvas canvas, Offset c, double r) {
    final Offset depthDir = Offset(-tilt.dx, -tilt.dy);
    final double mag = tilt.distance.clamp(0.0, 1.0);
    final Offset depth =
        depthDir * (r * 0.20 * mag) + Offset(0, r * 0.07); // base lip
    const int layers = 9;
    for (int i = layers; i >= 1; i--) {
      final double t = i / layers;
      final Color col = Color.lerp(_dRim, _dDark, t)!;
      canvas.drawCircle(c + depth * t, r, Paint()..color = col);
    }
  }

  void _paintFace(Canvas canvas, Offset c, double r) {
    final Rect rimRect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_dBright, _dMain, _dDeep],
          stops: [0.0, 0.55, 1.0],
        ).createShader(rimRect),
    );

    final double fr = r * 0.86;
    final Rect faceRect = Rect.fromCircle(center: c, radius: fr);
    canvas.drawCircle(
      c,
      fr,
      Paint()
        ..shader = RadialGradient(
          center: Alignment(-tilt.dx * 0.5, -tilt.dy * 0.5 - 0.18),
          radius: 0.95,
          colors: const [_dBright, _dMain, _dDeep, _dDark],
          stops: const [0.0, 0.45, 0.82, 1.0],
        ).createShader(faceRect),
    );

    canvas.drawCircle(
      c,
      fr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..color = _dDark.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.04),
    );
  }

  void _paintGloss(Canvas canvas, Offset c, double fr) {
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: fr)));

    final Offset hl =
        c + Offset(-tilt.dx, -tilt.dy) * (fr * 0.34) + Offset(0, -fr * 0.42);
    final Rect g = Rect.fromCenter(
      center: hl,
      width: fr * 1.5,
      height: fr * 1.02,
    );
    canvas.drawOval(
      g,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _glaze.withValues(alpha: 0.55),
            _glaze.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 1.0],
        ).createShader(g),
    );

    canvas.drawArc(
      Rect.fromCircle(center: c, radius: fr * 0.93),
      math.pi * 1.15,
      math.pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = fr * 0.06
        ..strokeCap = StrokeCap.round
        ..color = _glaze.withValues(alpha: 0.32),
    );
    canvas.restore();
  }

  void _paintBubble(Canvas canvas, Offset c, double r, double s) {
    final Offset parallax = Offset(tilt.dx, tilt.dy) * (r * 0.17);
    final Offset bc = c + parallax;
    final double bw = r * 1.04;
    final double bh = r * 0.84;
    final double rad = r * 0.30;

    Path bubblePath(Offset center) {
      final RRect rr = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: bw, height: bh),
        Radius.circular(rad),
      );
      final Path p = Path()..addRRect(rr);
      final double by = center.dy + bh * 0.5;
      p.moveTo(center.dx - bw * 0.20, by - bh * 0.04);
      p.lineTo(center.dx - bw * 0.46, by + bh * 0.34);
      p.lineTo(center.dx - bw * 0.02, by - bh * 0.04);
      p.close();
      return p;
    }

    final Offset shOff =
        Offset(-tilt.dx, -tilt.dy) * (r * 0.10) + Offset(0, r * 0.06);
    canvas.drawPath(
      bubblePath(bc + shOff),
      Paint()
        ..color = _shade.withValues(alpha: 0.22)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.018),
    );

    canvas.drawPath(
      bubblePath(bc),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_glaze, _cBubble, _cBubbleShade],
          stops: [0.0, 0.55, 1.0],
        ).createShader(
          Rect.fromCenter(center: bc, width: bw, height: bh * 1.5),
        ),
    );

    final List<double> widths = [0.56, 0.62, 0.42];
    final double lineH = (bh * 0.12).clamp(1.4, 6.0);
    final double left = bc.dx - bw * 0.30;
    for (int i = 0; i < widths.length; i++) {
      final double y = bc.dy + (i - 1) * bh * 0.22;
      final Rect lr = Rect.fromLTWH(left, y - lineH / 2, bw * widths[i], lineH);
      canvas.drawRRect(
        RRect.fromRectAndRadius(lr, Radius.circular(lineH / 2)),
        Paint()..color = _cLine.withValues(alpha: 0.85),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChatDiscPainter old) =>
      old.tilt != tilt ||
      old.press != press ||
      old.idlePhase != idlePhase ||
      old.showCircuit != showCircuit ||
      old.animate != animate;
}
