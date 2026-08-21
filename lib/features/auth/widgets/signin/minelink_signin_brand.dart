// ============================================================================
// MineLink — Sign-in brand panel
// ----------------------------------------------------------------------------
// Everything ambient on the left-hand panel, driven by ONE ticker.
//
// A separate AnimationController per effect would mean eleven tickers pumping
// eleven setState calls per frame. Instead a single unbounded controller
// exposes elapsed seconds, every effect derives its own phase from it, and one
// CustomPainter draws the lot in a single pass.
//
// The periods are deliberately co-prime-ish (11s, 24s, 31s, 44s, 54s, 62s,
// 78s) so the composition never visibly repeats.
//
// Nothing here is functional. All of it stops under "reduce motion".
// ============================================================================

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';

import 'dart:math' as math;

// `dart:ui show FontFeature` was in the drop; material re-exports it and this
// repo's lints flag the duplicate import.
import 'package:flutter/material.dart';

import 'minelink_signin_theme.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

class MlBrandPanel extends StatefulWidget {
  const MlBrandPanel({
    super.key,
    this.eyebrow = 'Mineral logistics, connected',
    this.headline = 'From the mine gate to the offload point — ',
    this.headlineAccent = 'every ton tracked.',
    this.blurb = 'Loading, security, haulage and reconciliation for mines, '
        'buyers and transporters — on one premium platform.',
    // ── These three figures are MARKETING PLACEHOLDERS, not measurements ──
    //
    // **The client was told and chose to keep them (2026-08-16).** That ruling
    // is what this default encodes, so do not "fix" it back to empty without
    // asking them again. What they were told:
    //
    //     shown here:  24+ Companies · 480 Trucks live ·   1.2M t Hauled
    //     production:  26  companies ·   7 vehicles    · 1,227.9 t hauled
    //
    // One is roughly right; the fleet is overstated ~68x and the tonnage by a
    // factor of a thousand — in large type on the first screen a customer
    // sees. Their answer was "for now it can be the fake numbers that's on it
    // but I'd like for it to be real numbers somewhere in the future when we
    // have more companies registered with us", which is a reasonable call for
    // a pre-launch marketing panel and an unreasonable one to leave
    // undocumented. It is item 1 of `docs/future-work.md`.
    //
    // Two things follow, and both matter if you touch this:
    //
    // 1. **Nothing downstream may treat these as data.** They are rendered by
    //    `_stat` and read by nothing else. Do not wire them into a report, an
    //    export or a dashboard.
    // 2. **Real ones cannot simply be dropped in here.** This screen renders
    //    BEFORE any session exists, so fetching them needs a public
    //    unauthenticated endpoint publishing how many customers MineLink has
    //    and how much ore they move — a disclosure decision, not a code
    //    change. Pass `stats:` from that source when it exists.
    //
    // `no-hardcoded-brand-stat` in `tool/release_guards.dart` is ratcheted at
    // exactly these three: a FOURTH invented figure fails the build.
    this.stats = kMlPlaceholderBrandStats,
  });

  final String eyebrow;
  final String headline;
  final String headlineAccent;
  final String blurb;
  final List<MlBrandStat> stats;

  @override
  State<MlBrandPanel> createState() => _MlBrandPanelState();
}

@immutable
class MlBrandStat {
  const MlBrandStat({
    required this.value,
    required this.label,
    required this.icon,
    this.suffix = '',
    this.decimals = 0,
  });

  final double value;
  final String label;
  final IconData icon;
  final String suffix;
  final int decimals;
}

/// The three placeholder figures the client chose to keep until real ones
/// exist (2026-08-16, `docs/future-work.md` item 1).
///
/// **This is the only place they are written.** They used to exist twice: here
/// as `MlBrandStat`s, and again in `auth_shell.dart` as a private `_RailStat`
/// row with the same three values typed out differently (`'24+'` as a string
/// against `value: 24, suffix: '+'`). `AuthShell` is what `/forgot-password`
/// and `/reset-password` render, so the same invented figures were on three
/// screens from two sources — and `no-hardcoded-brand-stat` matches
/// `MlBrandStat(value: <digit>`, so it could see one source and not the other.
///
/// That made the guard's own promise untrue. It says *"a FOURTH invented
/// figure fails the build, and so does one appearing anywhere other than the
/// sign-in panel"* — while three were already appearing elsewhere, unwatched,
/// and a fourth added as a `_RailStat` would have passed silently.
///
/// One list, one guard, and the numbers on screen are unchanged: the client's
/// decision is preserved exactly, it is simply now recorded once.
const List<MlBrandStat> kMlPlaceholderBrandStats = <MlBrandStat>[
  MlBrandStat(
      value: 24, suffix: '+', label: 'Companies', icon: Icons.domain_rounded),
  MlBrandStat(
      value: 480, label: 'Trucks live', icon: Icons.local_shipping_outlined),
  MlBrandStat(
      value: 1.2,
      decimals: 1,
      suffix: 'M t',
      label: 'Hauled',
      icon: Icons.scale_outlined),
];

class _MlBrandPanelState extends State<MlBrandPanel>
    with SingleTickerProviderStateMixin {
  /// One ticker for the whole panel. 600s so `value * 600` gives elapsed
  /// seconds directly and the wrap point is far outside any period in use.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 600),
  );

  /// Pointer offset in the range -0.5..0.5, for parallax.
  Offset _pointer = Offset.zero;

  late final List<_Mote> _dust = _Mote.field(18);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mlMotionEnabled(context)) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
      _clock.value = 0;
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = mlMotionEnabled(context);

    return MouseRegion(
      onHover: motion
          ? (e) {
              final box = context.findRenderObject() as RenderBox?;
              if (box == null) return;
              final local = box.globalToLocal(e.position);
              setState(() {
                _pointer = Offset(
                  (local.dx / box.size.width) - 0.5,
                  (local.dy / box.size.height) - 0.5,
                );
              });
            }
          : null,
      onExit: (_) => setState(() => _pointer = Offset.zero),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [MlAuth.backdropTop, MlAuth.backdropMid, MlAuth.backdropBottom],
            stops: [0, .44, 1],
          ),
        ),
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final t = _clock.value * 600; // elapsed seconds
            return Stack(
              fit: StackFit.expand,
              children: [
                // Everything ambient, one pass.
                RepaintBoundary(
                  child: CustomPaint(
                    painter: _BackdropPainter(t: t, motion: motion, dust: _dust),
                  ),
                ),
                _content(context, t, motion),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, double t, bool motion) {
    final p = motion ? _pointer : Offset.zero;

    return Padding(
      padding: const EdgeInsets.fromLTRB(46, 42, 46, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // wordmark
          Transform.translate(
            offset: Offset(p.dx * 9, p.dy * 7),
            // `min(268px, 64%)`, matching the reference's `.wordmark`. The drop
            // had the 64% but not the cap, so the lockup kept growing with the
            // window: ~363px at 1440 and ~506px on a 1920 full screen, against
            // an intended 268px. That is what made full screen look wrong — the
            // wordmark swamped the mark and the headline beneath it.
            child: LayoutBuilder(
              builder: (context, c) => Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: math.min(268.0, c.maxWidth * 0.64),
                  child: Image.asset(
                    MlAuth.logoAsset,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Text(
                      'MineLink',
                      style: TextStyle(
                        fontFamily: MlAuth.sans,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: MlAuth.inkHi,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // mark
          Expanded(
            child: Center(
              child: Transform.translate(
                offset: Offset(p.dx * 22, p.dy * 18),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final side = math.min(c.maxWidth * 0.62, 300.0);
                    // The mark bobs; the rings around it are painted below.
                    final bob = motion
                        ? math.sin((t / 7) * 2 * math.pi) * 7
                        : 0.0;
                    final tilt = motion
                        ? math.sin((t / 7) * 2 * math.pi) * 0.021
                        : 0.0;
                    return SizedBox(
                      width: side,
                      height: side,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: Size.square(side),
                            painter: _MarkOrbitPainter(t: t, motion: motion),
                          ),
                          Transform.translate(
                            offset: Offset(0, bob),
                            child: Transform.rotate(
                              angle: tilt,
                              child: SizedBox(
                                width: side * 0.62,
                                child: Image.asset(
                                  MlAuth.iconAsset,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // copy
          Text(
            widget.eyebrow.toUpperCase(),
            style: const TextStyle(
              fontFamily: MlAuth.sans,
              fontSize: 11,
              letterSpacing: 2.5,
              fontWeight: FontWeight.w700,
              color: MlAuth.accent2,
            ),
          ),
          const SizedBox(height: 16),
          _headline(context),
          const SizedBox(height: 16),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              widget.blurb,
              style: const TextStyle(
                fontFamily: MlAuth.sans,
                fontSize: 14,
                height: 1.68,
                color: MlAuth.inkMid,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            spacing: 34,
            runSpacing: 20,
            children: widget.stats.map(_stat).toList(),
          ),
        ],
      ),
    );
  }

  Widget _headline(BuildContext context) {
    final size = MediaQuery.sizeOf(context).width;
    final fs = (size * 0.025).clamp(26.0, 36.0);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: widget.headline),
            TextSpan(
              text: widget.headlineAccent,
              style: TextStyle(
                fontFamily: MlAuth.serif,
                fontFamilyFallback: MlAuth.serifFallback,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                fontSize: fs * 1.04,
                color: MlAuth.gold2,
              ),
            ),
          ],
        ),
        style: TextStyle(
          fontFamily: MlAuth.sans,
          fontSize: fs,
          height: 1.16,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.02 * fs,
          color: MlAuth.inkHi,
        ),
      ),
    );
  }

  Widget _stat(MlBrandStat s) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: MlTokens.overlayLight.withValues(alpha: 0.03),
              border: Border.all(color: MlAuth.line2),
              borderRadius: MlShape.radiusSmall,
            ),
            child: Icon(s.icon, size: 13, color: MlAuth.accent2),
          ),
          const SizedBox(height: 10),
          // Count-up runs once on first build, then holds.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: s.value),
            duration: mlDuration(context, const Duration(milliseconds: 1500)),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text(
              '${v.toStringAsFixed(s.decimals)}${s.suffix}',
              style: const TextStyle(
                fontFamily: MlAuth.mono,
                fontSize: 21,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: MlAuth.inkHi,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            s.label.toUpperCase(),
            style: const TextStyle(
              fontFamily: MlAuth.sans,
              fontSize: 11,
              letterSpacing: 1.05,
              fontWeight: FontWeight.w600,
              color: MlAuth.inkLo,
            ),
          ),
        ],
      );
}

// ===========================================================================
// Dust
// ===========================================================================

/// One drifting mote. Built with per-particle randomness rather than a CSS-ish
/// fixed set — a repeating pattern is obvious the moment you notice it.
class _Mote {
  _Mote(this.x, this.size, this.period, this.phase, this.drift, this.alpha);

  final double x; // 0..1 of width
  final double size; // px
  final double period; // seconds for a full traverse
  final double phase; // 0..1 offset
  final double drift; // px sideways over the traverse
  final double alpha;

  static List<_Mote> field(int n) {
    final r = math.Random(20260810);
    return List<_Mote>.generate(
      n,
      (_) => _Mote(
        r.nextDouble(),
        r.nextDouble() * 2.2 + 1,
        r.nextDouble() * 26 + 26,
        r.nextDouble(),
        r.nextDouble() * 60 - 30,
        r.nextDouble() * 0.4 + 0.25,
      ),
    );
  }
}

// ===========================================================================
// Backdrop — aurora, colour wheel, grid, dust
// ===========================================================================

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter({
    required this.t,
    required this.motion,
    required this.dust,
  });

  final double t;
  final bool motion;
  final List<_Mote> dust;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // -- colour wheel: the panel warms toward gold and cools toward cyan over
    // about a minute. Slower than anyone watches for, but it changes the room
    // while you sit in it.
    final wheelAngle = motion ? (t / 62) * 2 * math.pi : 0.0;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: 0,
          endAngle: 2 * math.pi,
          transform: GradientRotation(wheelAngle),
          colors: [
            MlAuth.gold.withValues(alpha: 0.13),
            MlAuth.accent.withValues(alpha: 0.14),
            MlAuth.bloomIndigo.withValues(alpha: 0.10),
            MlAuth.good.withValues(alpha: 0.08),
            MlAuth.gold.withValues(alpha: 0.13),
          ],
          stops: const [0, .27, .52, .78, 1],
        ).createShader(rect),
    );

    // -- aurora blobs
    void blob(Offset c, double r, Color col) {
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [col, col.withValues(alpha: 0)],
            stops: const [0, 0.66],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    final d1 = motion ? math.sin((t / 22) * 2 * math.pi) : 0.0;
    final d2 = motion ? math.sin((t / 27) * 2 * math.pi) : 0.0;
    blob(
      Offset(-70 + d1 * 60, -60 + d1 * 50),
      size.width * 0.72,
      MlAuth.gold.withValues(alpha: 0.24),
    );
    blob(
      Offset(size.width + 60 - d2 * 70, size.height + 40 - d2 * 44),
      size.width * 0.80,
      MlAuth.accent.withValues(alpha: 0.20),
    );

    // -- grid, drifting one cell per 46s
    const cell = 56.0;
    final off = motion ? (t / 46) % 1 * cell : 0.0;
    final grid = Paint()
      ..color = MlTokens.overlayLight.withValues(alpha: 0.028)
      ..strokeWidth = 1;
    for (double x = off - cell; x < size.width; x += cell) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = off - cell; y < size.height; y += cell) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // -- dust
    if (motion) {
      for (final m in dust) {
        final p = ((t / m.period) + m.phase) % 1;
        final y = size.height + 12 - p * (size.height + 120);
        final x = m.x * size.width + p * m.drift;
        // fade in and out at the ends so nothing pops
        final a = m.alpha *
            (p < .12 ? p / .12 : (p > .88 ? (1 - p) / .12 : 1));
        canvas.drawCircle(
          Offset(x, y),
          m.size / 2,
          Paint()..color = MlTokens.overlayLight.withValues(alpha: a.clamp(0, 1) * 0.6),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter old) =>
      old.t != t || old.motion != motion;
}

// ===========================================================================
// Mark — rings, sweep, pings, orbiting markers
// ===========================================================================

class _MarkOrbitPainter extends CustomPainter {
  const _MarkOrbitPainter({required this.t, required this.motion});

  final double t;
  final bool motion;

  double _phase(double period) => motion ? (t / period) % 1 : 0.0;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final base = size.width / 2;

    // Radii mirror the CSS insets: -11%, 0, 11%, 22%.
    final r0 = base * 1.11;
    final r1 = base;
    final r2 = base * 0.89;
    final r3 = base * 0.78;

    final breathe = motion
        ? 1 + math.sin((t / 11) * 2 * math.pi) * 0.02
        : 1.0;

    // -- glow behind the mark
    canvas.drawCircle(
      c,
      base * 0.94,
      Paint()
        ..shader = RadialGradient(
          colors: [
            MlAuth.gold.withValues(alpha: 0.26),
            MlAuth.gold.withValues(alpha: 0),
          ],
          stops: const [0, 0.62],
        ).createShader(Rect.fromCircle(center: c, radius: base * 0.94)),
    );

    // -- rings
    _dashedCircle(canvas, c, r0, -_phase(78) * 2 * math.pi,
        MlTokens.overlayLight.withValues(alpha: 0.045));
    _circle(canvas, c, r1 * breathe, MlTokens.overlayLight.withValues(alpha: 0.07));
    _dashedCircle(canvas, c, r2, -_phase(78) * 2 * math.pi,
        MlAuth.gold.withValues(alpha: 0.14));
    _circle(canvas, c, r3 * breathe, MlAuth.accent.withValues(alpha: 0.12));

    // -- radar sweep. The mark is a chain link and the product tracks loads;
    // a sweep says "tracking" where a spinning ring would only say "spinning".
    final sweepAngle = _phase(11) * 2 * math.pi;
    canvas.drawCircle(
      c,
      r0,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = base * 0.30
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: 2 * math.pi,
          transform: GradientRotation(sweepAngle),
          colors: [
            MlAuth.accent.withValues(alpha: 0),
            MlAuth.accent.withValues(alpha: 0),
            MlAuth.accent.withValues(alpha: 0.20),
            MlAuth.accent.withValues(alpha: 0.34),
            MlAuth.accent.withValues(alpha: 0),
          ],
          stops: const [0, .74, .91, .97, 1],
        ).createShader(Rect.fromCircle(center: c, radius: r0)),
    );

    // -- pings, 7.5s period on a 2.5s stagger
    const pingPeriod = 7.5;
    const pingColors = [MlAuth.accent, MlAuth.gold, MlTokens.inkOnFill];
    for (var i = 0; i < 3; i++) {
      final p = motion ? ((t + i * 2.5) / pingPeriod) % 1 : 0.0;
      if (!motion) break;
      final scale = 0.6 + p * 1.15;
      final a = p < .10
          ? (p / .10) * 0.7
          : (p < .70 ? 0.7 * (1 - (p - .10) / .60) : 0.0);
      if (a <= 0) continue;
      canvas.drawCircle(
        c,
        r3 * scale,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = pingColors[i].withValues(alpha: a * 0.55),
      );
    }

    // -- markers riding the rings: a load moving along a route
    void marker(double radius, double period, bool reverse, Color col,
        double dotR) {
      final a = (reverse ? -1 : 1) * _phase(period) * 2 * math.pi - math.pi / 2;
      final p = Offset(c.dx + math.cos(a) * radius, c.dy + math.sin(a) * radius);
      canvas.drawCircle(
          p, dotR * 2.6, Paint()..color = col.withValues(alpha: 0.22));
      canvas.drawCircle(p, dotR, Paint()..color = col);
      canvas.drawCircle(
          p, dotR * 0.45, Paint()..color = MlTokens.overlayLight.withValues(alpha: 0.85));
    }

    marker(r1, 24, false, MlAuth.gold, 3.5);
    marker(r2, 31, true, MlAuth.accent, 3.5);
    marker(r0, 44, false, MlTokens.overlayLight.withValues(alpha: 0.75), 2.5);
  }

  void _circle(Canvas canvas, Offset c, double r, Color col) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = col,
    );
  }

  /// Flutter has no dashed stroke, so the arc is drawn in segments. 44 dashes
  /// keeps the gap proportional at every size this renders at.
  void _dashedCircle(
      Canvas canvas, Offset c, double r, double rotation, Color col) {
    const dashes = 44;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = col;
    final rect = Rect.fromCircle(center: c, radius: r);
    final step = 2 * math.pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(
          rect, rotation + i * step, step * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MarkOrbitPainter old) =>
      old.t != t || old.motion != motion;
}
