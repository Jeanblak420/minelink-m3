import 'dart:math' as math;

import 'package:flutter/material.dart';

/// THE sparkline. One implementation (S5-13, P5-22…P5-31).
///
/// The gate says "three sparkline implementations collapse to one". There were
/// FIVE:
///
///   MlSparkline            insights_v2/minelink_charts.dart   <- this one
///   SaSparkline            super_admin_dashboard_widgets.dart <- ZERO callers
///   _SparkPainter          employee_register_screen.dart
///   _AreaSparkPainter      employee_profile_screen.dart
///   _SparkPainter          super_admin_org_insights_screen.dart
///
/// SaSparkline turned out to be dead — a whole implementation, painter and all,
/// that nothing called. It is deleted rather than merged.
///
/// The three private painters each draw a slightly different thing (a plain
/// line, an area fill, a line with a dot) and live inside screens that S5-20/21
/// migrate. They are converted alongside their screen, not in a blind sweep
/// that would silently change three visual treatments at once.
///
/// Carved verbatim out of minelink_charts.dart — values unchanged.

class MlSparkline extends StatelessWidget {
  const MlSparkline({
    super.key,
    required this.data,
    required this.color,
    this.width = 100,
    this.height = 34,
    this.strokeWidth = 2,
  });

  final List<double> data;
  final Color color;
  final double width;
  final double height;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(data, color, strokeWidth),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter(this.data, this.color, this.strokeWidth);

  final List<double> data;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final pts = mlProjectSeries(data, size, topPad: 5, bottomPad: 3);

    final line = Path();
    line.moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      line.lineTo(p.dx, p.dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color;
}

// ---------------------------------------------------------------------------
// Area trend
// ---------------------------------------------------------------------------

/// Maps values onto points inside [size], with padding so a peak or trough is
/// never clipped by the edge. Shared by every chart that plots a series.
///
/// A flat series (max == min) gets range 1 rather than 0 — otherwise every
/// point divides by zero and the line vanishes, which is how "no movement"
/// used to render as "no chart".
List<Offset> mlProjectSeries(
  List<double> values,
  Size size, {
  double topPad = 4,
  double bottomPad = 2,
  double? forcedMin,
  double? forcedMax,
}) {
  if (values.isEmpty) return const [];
  final min = forcedMin ?? values.reduce(math.min);
  final max = forcedMax ?? values.reduce(math.max);
  final range = (max - min) == 0 ? 1.0 : (max - min);
  final usable = size.height - topPad - bottomPad;
  return List<Offset>.generate(values.length, (i) {
    final x = values.length == 1
        ? size.width / 2
        : (i / (values.length - 1)) * size.width;
    final y = size.height - bottomPad - ((values[i] - min) / range) * usable;
    return Offset(x, y);
  });
}
