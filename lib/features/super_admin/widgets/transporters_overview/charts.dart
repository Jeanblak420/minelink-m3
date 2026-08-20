// ============================================================================
// Transporters overview — charts
// ----------------------------------------------------------------------------
// Ported from the drop's `widgets/charts.dart`.
//
// All three line charts share [ovSmoothStepPath]: every segment is a cubic
// whose two control points sit at the segment's horizontal midpoint. That is
// what gives the design its soft stair. A Catmull-Rom or monotone spline looks
// close and is not the same silhouette — the drop says explicitly not to
// substitute one, so don't.
//
// Series arrive as normalised y in 0..1, 0 = top of the plot box (SVG
// orientation). Normalisation happens in the mapper so the target rule and both
// series are guaranteed to share one scale.
// ============================================================================

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import 'overview_models.dart';
import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';

/// 160×160 donut, 18px stroke, r = 71, from 12 o'clock, clockwise, butt caps
/// so there are no gaps between slices.
class OvFleetDonut extends StatelessWidget {
  const OvFleetDonut({
    super.key,
    required this.tokens,
    required this.slices,
    required this.centreValue,
    this.size = 160,
    this.stroke = 18,
  });

  final MlOv tokens;
  final List<FleetSlice> slices;

  /// Utilisation percent. Rendered "33%" over "UTILISED".
  final int centreValue;
  final double size;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(
              values: [for (final s in slices) s.count],
              colors: [for (final s in slices) t.tone(s.tone)],
              track: t.overlay(0.04),
              stroke: stroke,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text.rich(
                TextSpan(
                  style: t.m(size: 28, weight: FontWeight.w500, height: 1),
                  children: [
                    TextSpan(text: '$centreValue'),
                    TextSpan(text: '%', style: t.m(size: 14, color: t.inkLo)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'UTILISED',
                style: t.s(size: 10, color: t.inkMid, letterSpacing: 1.2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.track,
    required this.stroke,
  });

  final List<int> values;
  final List<Color> colors;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - stroke) / 2;
    final centre = size.center(Offset.zero);
    canvas.drawCircle(
      centre,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    final total = values.fold<int>(0, (a, b) => a + b);
    if (total == 0) return;

    final rect = Rect.fromCircle(center: centre, radius: r);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt
          ..color = colors[i],
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      !listEquals(old.values, values) ||
      !listEquals(old.colors, colors) ||
      old.track != track ||
      old.stroke != stroke;
}

/// The soft-stair path shared by every line on this screen.
Path ovSmoothStepPath(List<Offset> pts) {
  final path = Path()..moveTo(pts.first.dx, pts.first.dy);
  for (var i = 1; i < pts.length; i++) {
    final p0 = pts[i - 1];
    final p1 = pts[i];
    final mx = p0.dx + (p1.dx - p0.dx) / 2;
    path.cubicTo(mx, p0.dy, mx, p1.dy, p1.dx, p1.dy);
  }
  return path;
}

/// The big "Tons moved this period" chart: guides, area, dashed prior period,
/// dashed target rule, main line.
class OvTonsAreaChart extends StatelessWidget {
  const OvTonsAreaChart({
    super.key,
    required this.tokens,
    required this.series,
    required this.compareSeries,
    this.targetY,
    this.height = 150,
  });

  final MlOv tokens;
  final List<double> series;
  final List<double> compareSeries;

  /// Null draws no rule at all.
  final double? targetY;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _TonsAreaPainter(
            tokens: tokens,
            series: series,
            compare: compareSeries,
            targetY: targetY,
          ),
        ),
      );
}

class _TonsAreaPainter extends CustomPainter {
  _TonsAreaPainter({
    required this.tokens,
    required this.series,
    required this.compare,
    required this.targetY,
  });

  final MlOv tokens;
  final List<double> series;
  final List<double> compare;
  final double? targetY;

  List<Offset> _pts(List<double> ys, Size size) {
    if (ys.length == 1) {
      return [Offset(0, ys.first * size.height), Offset(size.width, ys.first * size.height)];
    }
    final step = size.width / (ys.length - 1);
    return [
      for (var i = 0; i < ys.length; i++) Offset(i * step, ys[i] * size.height),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final t = tokens;

    // Horizontal guides at 1/3 and 2/3.
    final guide = Paint()..color = t.overlay(0.03);
    canvas.drawLine(Offset(0, size.height * 0.33),
        Offset(size.width, size.height * 0.33), guide);
    canvas.drawLine(Offset(0, size.height * 0.66),
        Offset(size.width, size.height * 0.66), guide);

    if (series.isEmpty) return;

    final line = ovSmoothStepPath(_pts(series, size));

    canvas.drawPath(
      Path.from(line)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            t.acc.withValues(alpha: 0.32),
            t.acc.withValues(alpha: 0.08),
            t.acc.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );

    if (targetY != null) {
      final y = targetY!.clamp(0.0, 1.0) * size.height;
      _dashedLine(canvas, Offset(0, y), Offset(size.width, y),
          t.acc2.withValues(alpha: 0.45), 1.2, 7, 8);
    }

    if (compare.isNotEmpty) {
      _dashedPath(canvas, ovSmoothStepPath(_pts(compare, size)),
          t.inkMid.withValues(alpha: 0.55), 1.4, 3, 6);
    }

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(colors: [t.acc3, t.acc])
            .createShader(Offset.zero & size),
    );
  }

  void _dashedLine(Canvas c, Offset a, Offset b, Color color, double w,
      double on, double off) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = w;
    final total = (b - a).distance;
    if (total <= 0) return;
    final dir = (b - a) / total;
    var d = 0.0;
    while (d < total) {
      final end = math.min(d + on, total);
      c.drawLine(a + dir * d, a + dir * end, paint);
      d = end + off;
    }
  }

  void _dashedPath(
      Canvas c, Path path, Color color, double w, double on, double off) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final end = math.min(d + on, metric.length);
        c.drawPath(metric.extractPath(d, end), paint);
        d = end + off;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _TonsAreaPainter old) =>
      !listEquals(old.series, series) ||
      !listEquals(old.compare, compare) ||
      old.targetY != targetY ||
      old.tokens.isDark != tokens.isDark;
}

/// The compact 68px rail chart in "Monthly movement trend".
class OvTrendRailChart extends StatelessWidget {
  const OvTrendRailChart({
    super.key,
    required this.tokens,
    required this.series,
    this.height = 68,
  });

  final MlOv tokens;
  final List<double> series;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _RailPainter(tokens, series)),
      );
}

class _RailPainter extends CustomPainter {
  _RailPainter(this.tokens, this.series);

  final MlOv tokens;
  final List<double> series;

  @override
  void paint(Canvas canvas, Size size) {
    if (series.length < 2) return;
    final t = tokens;
    final step = size.width / (series.length - 1);
    final pts = [
      for (var i = 0; i < series.length; i++)
        Offset(i * step, series[i] * size.height),
    ];
    final line = ovSmoothStepPath(pts);

    canvas.drawPath(
      Path.from(line)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [t.acc.withValues(alpha: 0.35), t.acc.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(colors: [t.acc3, t.acc])
            .createShader(Offset.zero & size),
    );

    final last = pts.last;
    canvas.drawCircle(last, 4, Paint()..color = t.railDotFill);
    canvas.drawCircle(
      last,
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = t.acc,
    );
  }

  @override
  bool shouldRepaint(covariant _RailPainter old) =>
      !listEquals(old.series, series) || old.tokens.isDark != tokens.isDark;
}

/// The 15-day tempo bars beside each transporter's identity block.
class OvTempoBars extends StatelessWidget {
  const OvTempoBars({
    super.key,
    required this.tokens,
    required this.values,
    this.height = 32,
  });

  final MlOv tokens;
  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    if (values.isEmpty) return SizedBox(height: height);
    final max = values.reduce(math.max);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              // A month with no movement is a flat row of minimum stubs, not
              // a NaN — max is 0 in that case and the ratio must not divide.
              child: Opacity(
                opacity: max <= 0
                    ? 0.5
                    : (0.5 + (values[i] / max) * 0.5).clamp(0.0, 1.0),
                child: Container(
                  height: max <= 0
                      ? 6
                      : math.max(6, (values[i] / max) * height),
                  decoration: BoxDecoration(
                    borderRadius: MlShape.radiusExtraSmall,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [t.acc, t.acc.withValues(alpha: 0.3)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Small dash/solid key line used by the chart legend.
class OvKeyLine extends StatelessWidget {
  const OvKeyLine({super.key, required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: const Size(16, 2),
        painter: _KeyLinePainter(color, dashed),
      );
}

class _KeyLinePainter extends CustomPainter {
  _KeyLinePainter(this.color, this.dashed);

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2;
    final y = size.height / 2;
    if (!dashed) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
      return;
    }
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, y), Offset((x + 3).clamp(0, size.width), y), p);
      x += 6;
    }
  }

  @override
  bool shouldRepaint(covariant _KeyLinePainter old) =>
      old.color != color || old.dashed != dashed;
}
