// ============================================================================
// MineLink — Targets Charts
// ----------------------------------------------------------------------------
//   MlShortTermChart   target vs actual for every month
//   MlHorizonChart     attainment per horizon against a 100% rule
//   MlCycleChart       cumulative tonnage across the 365-day cycle
//
// Hand-painted rather than pulled from a charting package: none of these are
// standard chart types, and the outlier handling in the first one is the whole
// reason it works on this data.
// ============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'minelink_targets_core.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';

Color mlOutcomeColor(MlGlass t, MlTargetOutcome o) {
  switch (o) {
    case MlTargetOutcome.surpassed:
      return t.good;
    case MlTargetOutcome.close:
      return t.accent;
    case MlTargetOutcome.short:
      return t.bad;
    case MlTargetOutcome.pending:
      return t.inkLo;
    case MlTargetOutcome.none:
      return t.inkXlo;
  }
}

// ---------------------------------------------------------------------------
// Short-term performance
// ---------------------------------------------------------------------------

/// Hollow column = target, solid column = actual, coloured by outcome.
/// Planned months show the hollow column only.
///
/// The scale clips at three times the median target. Without that, one
/// misconfigured month (28,000 t against a network moving hundreds) flattens
/// the entire year onto the baseline. Clipped columns are marked, not hidden —
/// the outlier stays visible *as* an outlier.
class MlShortTermChart extends StatelessWidget {
  const MlShortTermChart({
    super.key,
    required this.data,
    required this.tokens,
    this.height = 190,
    this.onPick,
  });

  final MlTargetsData data;
  final MlGlass tokens;
  final double height;
  final ValueChanged<int>? onPick;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, c) => GestureDetector(
            onTapDown: onPick == null
                ? null
                : (d) {
                    final n = data.months.length;
                    final i = ((d.localPosition.dx / c.maxWidth) * n)
                        .floor()
                        .clamp(0, n - 1);
                    onPick!(i);
                  },
            child: SizedBox(
              height: height,
              child: CustomPaint(
                painter: _ShortTermPainter(data: data, t: t),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _axis(t),
        const SizedBox(height: 10),
        _legend(t),
      ],
    );
  }

  Widget _axis(MlGlass t) => SizedBox(
        height: 13,
        child: LayoutBuilder(
          builder: (context, c) {
            final n = data.months.length;
            final slot = c.maxWidth / n;
            return Stack(
              children: [
                for (var i = 0; i < n; i++)
                  if (i.isEven || n <= 12)
                    Positioned(
                      left: slot * i + slot / 2 - 12,
                      width: 24,
                      child: Text(
                        data.months[i].shortLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: MlGlass.mono,
                          fontSize: 8,
                          letterSpacing: 0.8,
                          color: data.isPlanned(i) ? t.accent2 : t.inkLo,
                        ),
                      ),
                    ),
              ],
            );
          },
        ),
      );

  Widget _legend(MlGlass t) {
    Widget item(Widget swatch, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            swatch,
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(
                    fontFamily: MlGlass.sans, fontSize: 10.5, color: t.inkMid)),
          ],
        );

    Widget box(Color c, {bool outline = false, bool dashed = false}) =>
        Container(
          width: outline ? 14 : 9,
          height: 10,
          decoration: BoxDecoration(
            color: outline ? null : c,
            borderRadius: BorderRadius.circular(2),
            border: outline
                ? Border.all(
                    color: c,
                    width: 1.2,
                    style: dashed ? BorderStyle.none : BorderStyle.solid)
                : null,
          ),
        );

    return Wrap(
      spacing: 16,
      runSpacing: 6,
      children: [
        item(box(t.inkMid, outline: true), 'Target'),
        item(box(t.good), 'Surpassed'),
        item(box(t.accent), 'Close'),
        item(box(t.bad), 'Short'),
        item(box(t.accent2, outline: true), 'Planned'),
      ],
    );
  }
}

class _ShortTermPainter extends CustomPainter {
  const _ShortTermPainter({required this.data, required this.t});

  final MlTargetsData data;
  final MlGlass t;

  @override
  void paint(Canvas canvas, Size size) {
    final months = data.months;
    if (months.isEmpty) return;

    final vals = <double>[];
    for (final m in months) {
      if (m.target > 0) vals.add(m.target);
      if (m.hasActuals) vals.add(m.total);
    }
    if (vals.isEmpty) return;

    final sorted = List<double>.from(vals)..sort();
    final median = sorted[sorted.length ~/ 2];
    final cap = median * 3;
    final inScale = vals.where((v) => v <= cap).toList();
    final top = ((inScale.isEmpty ? median : inScale.reduce(math.max)) * 1.18)
        .clamp(1.0, double.infinity);

    final slot = size.width / months.length;
    final gw = math.min(26.0, slot * 0.62);
    final aw = gw * 0.54;
    double y(double v) => size.height - math.min(1.0, v / top) * size.height;

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = t.line2
        ..strokeWidth = 1,
    );

    for (var i = 0; i < months.length; i++) {
      final m = months[i];
      final cx = slot * i + slot / 2;
      final planned = data.isPlanned(i);

      if (m.target > 0) {
        final ty = y(m.target);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - gw / 2, ty, gw, size.height - ty),
          const Radius.circular(3),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2
            ..color = (planned ? t.accent2 : t.inkMid)
                .withValues(alpha: planned ? 0.75 : 0.45),
        );
        if (m.target > top) {
          // Clipped — mark it rather than silently truncating.
          final p = Path()..moveTo(cx - gw / 2, 6);
          for (var k = 0; k < 4; k++) {
            p.lineTo(cx - gw / 2 + gw / 4 * (k + 1), k.isEven ? 2 : 6);
          }
          canvas.drawPath(
            p,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.6
              ..color = t.warn,
          );
        }
      }

      if (m.hasActuals) {
        final ay = y(m.total);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(cx - aw / 2, ay, aw, size.height - ay),
            const Radius.circular(2.5),
          ),
          Paint()
            ..color = mlOutcomeColor(t, m.outcome)
                .withValues(alpha: i == data.currentIndex ? 1 : 0.88),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ShortTermPainter old) =>
      old.data != data || old.t.isDark != t.isDark;
}

// ---------------------------------------------------------------------------
// Horizon attainment
// ---------------------------------------------------------------------------

/// One bar per horizon against a dashed 100% rule. Horizons whose checkpoint
/// has not arrived render as dashed outlines — "not yet judged" must not look
/// like "missed".
class MlHorizonChart extends StatelessWidget {
  const MlHorizonChart({
    super.key,
    required this.data,
    required this.tokens,
    this.height = 170,
  });

  final MlTargetsData data;
  final MlGlass tokens;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(painter: _HorizonPainter(data: data, t: t)),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) {
            final slot = c.maxWidth / kMlHorizons.length;
            return SizedBox(
              height: 16,
              child: Stack(
                children: [
                  for (var i = 0; i < kMlHorizons.length; i++)
                    Positioned(
                      left: slot * i,
                      width: slot,
                      child: Text(
                        kMlHorizons[i].name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: MlGlass.sans,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: data.horizonReached(kMlHorizons[i])
                              ? t.ink
                              : t.inkLo,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HorizonPainter extends CustomPainter {
  const _HorizonPainter({required this.data, required this.t});

  final MlTargetsData data;
  final MlGlass t;

  @override
  void paint(Canvas canvas, Size size) {
    final atts = <double>[];
    for (final z in kMlHorizons) {
      final tgt = data.cycle.targets[z.key] ?? 0;
      final act = data.horizonActual(z);
      atts.add((tgt > 0 && act != null) ? act / tgt : 0);
    }
    final maxA = math.max(1.3, atts.reduce(math.max));
    final slot = size.width / kMlHorizons.length;
    final bw = math.min(76.0, slot * 0.5);
    double y(double a) => size.height - math.min(1.0, a / maxA) * size.height;

    // 100% rule
    final y100 = y(1);
    final dash = Path();
    for (var x = 0.0; x < size.width; x += 12) {
      dash.moveTo(x, y100);
      dash.lineTo(math.min(x + 6, size.width), y100);
    }
    canvas.drawPath(
      dash,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = t.inkHi.withValues(alpha: 0.32),
    );

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = t.line2
        ..strokeWidth = 1,
    );

    for (var i = 0; i < kMlHorizons.length; i++) {
      final z = kMlHorizons[i];
      final cx = slot * i + slot / 2;
      final outcome = data.horizonOutcome(z);

      if (outcome == MlTargetOutcome.pending ||
          outcome == MlTargetOutcome.none) {
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bw / 2, size.height - 26, bw, 26),
          const Radius.circular(4),
        );
        canvas.drawRRect(
          rect,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = t.inkXlo,
        );
        continue;
      }

      final a = atts[i];
      final by = y(a);
      final color = mlOutcomeColor(t, outcome);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - bw / 2, by, bw, size.height - by),
          const Radius.circular(4),
        ),
        Paint()..color = color.withValues(alpha: 0.9),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: '${(a * 100).round()}%',
          style: TextStyle(
            fontFamily: MlGlass.mono,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(cx - tp.width / 2, by - tp.height - 5));
    }
  }

  @override
  bool shouldRepaint(covariant _HorizonPainter old) =>
      old.data != data || old.t.isDark != t.isDark;
}

// ---------------------------------------------------------------------------
// Cycle progress
// ---------------------------------------------------------------------------

/// Cumulative tonnage across the 365-day cycle, with a marker at each horizon
/// target and a line at today. This is the chart that answers "are we on
/// course", which no per-month view can.
class MlCycleChart extends StatelessWidget {
  const MlCycleChart({
    super.key,
    required this.data,
    required this.tokens,
    this.height = 170,
  });

  final MlTargetsData data;
  final MlGlass tokens;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: height,
          child: CustomPaint(painter: _CyclePainter(data: data, t: t)),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, c) => SizedBox(
            height: 14,
            child: Stack(
              children: [
                for (final z in kMlHorizons)
                  Positioned(
                    left: (z.days / MlCycle.cycleDays) * c.maxWidth - 24,
                    width: 48,
                    child: Text(
                      z.name.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: MlGlass.mono,
                        fontSize: 8,
                        letterSpacing: 0.8,
                        color: t.inkLo,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CyclePainter extends CustomPainter {
  const _CyclePainter({required this.data, required this.t});

  final MlTargetsData data;
  final MlGlass t;

  @override
  void paint(Canvas canvas, Size size) {
    final f = data.dailySeries;
    if (f.isEmpty) return;

    var run = 0.0;
    final cum = f.map((v) => run += v).toList();

    final maxTarget = kMlHorizons
        .map((z) => data.cycle.targets[z.key] ?? 0)
        .fold<double>(0, math.max);
    final top = math.max(maxTarget, cum.last) * 1.12;
    if (top <= 0) return;

    double x(num d) => (d / MlCycle.cycleDays) * size.width;
    double y(double v) => size.height - (v / top) * size.height;

    // milestone gridlines
    final grid = Paint()
      ..color = t.inkHi.withValues(alpha: 0.10)
      ..strokeWidth = 1;
    for (final z in kMlHorizons) {
      final gx = x(z.days);
      final p = Path();
      for (var yy = 0.0; yy < size.height; yy += 6) {
        p.moveTo(gx, yy);
        p.lineTo(gx, math.min(yy + 2, size.height));
      }
      canvas.drawPath(p, Paint()..color = grid.color..strokeWidth = 1);
    }

    final pts = <Offset>[
      for (var i = 0; i < cum.length; i++) Offset(x(i + 1), y(cum[i]))
    ];

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final p0 = pts[i - 1], p1 = pts[i];
      final cx = (p0.dx + p1.dx) / 2;
      path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
    }

    final fill = Path.from(path)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.accent.withValues(alpha: 0.28), t.accent.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..shader = LinearGradient(colors: [t.accent3, t.accent])
            .createShader(Offset.zero & size),
    );

    // horizon target markers
    for (final z in kMlHorizons) {
      final tgt = data.cycle.targets[z.key] ?? 0;
      if (tgt <= 0) continue;
      final mx = x(z.days), my = y(tgt);
      final color = mlOutcomeColor(t, data.horizonOutcome(z));
      canvas.drawLine(
        Offset(mx - 9, my),
        Offset(mx + 9, my),
        Paint()
          ..color = color
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
      final reached = data.horizonReached(z);
      canvas.drawCircle(
          Offset(mx, my), 3.4, Paint()..color = reached ? color : t.panel);
      canvas.drawCircle(
        Offset(mx, my),
        3.4,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..color = color,
      );
    }

    // today
    final tx = x(data.elapsedCycleDays);
    canvas.drawLine(
      Offset(tx, 0),
      Offset(tx, size.height),
      Paint()
        ..color = t.accent.withValues(alpha: 0.55)
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _CyclePainter old) =>
      old.data != data || old.t.isDark != t.isDark;
}
