// ============================================================================
// MineLink Technologies — Chart primitives
// ----------------------------------------------------------------------------
// Every chart the two screens use, as CustomPainters. No charting package:
// these are ~500 lines of Canvas work against a Flutter SDK that already has
// everything needed, and adding fl_chart or syncfusion for six shapes would
// cost more than it saves.
//
//   MlSparkline      tiny gradient-filled trend        (dashboard org cards)
//   MlAreaTrend      smoothed area with end dot        (rail "monthly movement")
//   MlFlagshipTrend  current + prior + target, crosshair tooltip
//   MlDonut          segmented ring with a centre slot
//   MlRidge          15-day tempo bars                 (transporter cards)
//   MlMeter          thin progress bar                 (utilisation / seats)
// ============================================================================

import 'dart:math' as math;
import 'dart:ui' show FontFeature, PathMetric;
import 'package:flutter/material.dart';

import 'minelink_screens_core.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

// ---------------------------------------------------------------------------
// Shared path building
// ---------------------------------------------------------------------------

/// Builds a horizontally-smoothed path through [points] using midpoint cubic
/// control handles — the same curve shape the JS used, so the ported charts
/// read identically.
Path mlSmoothPath(List<Offset> points) {
  final path = Path();
  if (points.isEmpty) return path;
  path.moveTo(points.first.dx, points.first.dy);
  for (var i = 1; i < points.length; i++) {
    final p0 = points[i - 1];
    final p1 = points[i];
    final cx = (p0.dx + p1.dx) / 2;
    path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
  }
  return path;
}

/// Dashes a path. Flutter has no native dash support, so this walks the path
/// metrics and extracts alternating segments.
Path mlDashPath(Path source, {double dash = 6, double gap = 6}) {
  final out = Path();
  for (final PathMetric metric in source.computeMetrics()) {
    double pos = 0;
    while (pos < metric.length) {
      final next = math.min(pos + dash, metric.length);
      out.addPath(metric.extractPath(pos, next), Offset.zero);
      pos = next + gap;
    }
  }
  return out;
}

List<Offset> _project(
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

// ---------------------------------------------------------------------------
// Sparkline
// ---------------------------------------------------------------------------

class MlAreaTrend extends StatelessWidget {
  const MlAreaTrend({
    super.key,
    required this.data,
    required this.tokens,
    this.height = 68,
  });

  final List<double> data;
  final MlGlass tokens;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _AreaTrendPainter(data, tokens)),
    );
  }
}

class _AreaTrendPainter extends CustomPainter {
  const _AreaTrendPainter(this.data, this.t);

  final List<double> data;
  final MlGlass t;

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final pts = _project(data, size, topPad: 8, bottomPad: 6);
    final line = mlSmoothPath(pts);

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
          colors: [t.accent.withValues(alpha: 0.35), t.accent.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          colors: [t.accent3, t.accent],
        ).createShader(Offset.zero & size),
    );

    // End marker: filled ring in the panel colour so the line reads through it
    final end = pts.last;
    canvas.drawCircle(end, 4, Paint()..color = t.panel);
    canvas.drawCircle(
      end,
      4,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = t.accent,
    );
  }

  @override
  bool shouldRepaint(covariant _AreaTrendPainter old) => old.data != data;
}

// ---------------------------------------------------------------------------
// Flagship trend — current period, prior month, target, crosshair tooltip
// ---------------------------------------------------------------------------

class MlFlagshipTrend extends StatefulWidget {
  const MlFlagshipTrend({
    super.key,
    required this.current,
    required this.previous,
    required this.tokens,
    // DEVIATION from the drop (2026-08-08): target was a non-null 1352 with a
    // hardcoded 'Target 28.0k' caption — the line and the label did not even
    // agree, and neither came from anywhere. Now null means NO TARGET SET, and
    // nothing is drawn: no line, no caption. A target nobody chose that renders
    // identically to one somebody did is exactly what produced the 28,000 t
    // month. Fed from `monthly_targets` via MineLinkTransportersScreen.
    this.target,
    this.targetLabel,
    this.latestLabel = '',
    this.priorLabel = 'Jul 2026',
    this.height = 150,
    this.xLabels = const {0: '01', 4: '05', 8: '09', 12: '13', 16: '17'},
    this.unitCaption = 'Daily · Tons',
    this.monthLabel = 'Aug',
  });

  final List<double> current;
  final List<double> previous;
  final MlGlass tokens;
  /// Tons targeted for the period, or null when none is set.
  final double? target;

  /// Caption for the target line. Derived from [target] when omitted.
  final String? targetLabel;
  final String latestLabel;
  final String priorLabel;
  final double height;
  final Map<int, String> xLabels;
  final String unitCaption;
  final String monthLabel;

  @override
  State<MlFlagshipTrend> createState() => _MlFlagshipTrendState();
}

class _MlFlagshipTrendState extends State<MlFlagshipTrend> {
  int? _hoverIndex;

  double _min = 0;
  double _max = 1;

  void _computeBounds() {
    final all = <double>[
      ...widget.current,
      ...widget.previous,
      // Only widens the scale when there is a target; an absent one must not
      // drag the bounds toward zero.
      if (widget.target != null) widget.target!,
    ];
    _min = all.reduce(math.min) - 80;
    _max = all.reduce(math.max) + 95;
  }

  void _updateHover(Offset local, double width) {
    if (widget.current.length < 2) return;
    final frac = (local.dx / width).clamp(0.0, 1.0);
    final i = (frac * (widget.current.length - 1)).round();
    if (i != _hoverIndex) setState(() => _hoverIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    _computeBounds();
    final t = widget.tokens;
    final n = widget.current.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        LayoutBuilder(
          builder: (context, c) {
            final size = Size(c.maxWidth, widget.height);
            final pts = _project(widget.current, size,
                topPad: 0, bottomPad: 0, forcedMin: _min, forcedMax: _max);

            return MouseRegion(
              onHover: (e) => _updateHover(e.localPosition, c.maxWidth),
              onExit: (_) => setState(() => _hoverIndex = null),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) => _updateHover(d.localPosition, c.maxWidth),
                onPanEnd: (_) => setState(() => _hoverIndex = null),
                onTapDown: (d) => _updateHover(d.localPosition, c.maxWidth),
                child: SizedBox(
                  height: widget.height,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _FlagshipPainter(
                            current: widget.current,
                            previous: widget.previous,
                            target: widget.target,
                            min: _min,
                            max: _max,
                            t: t,
                            hoverIndex: _hoverIndex,
                          ),
                        ),
                      ),

                      // Target caption, riding just above its own dashed line.
                      // Absent entirely when no target is set — see the note
                      // on the constructor.
                      if (widget.target != null)
                        Positioned(
                          right: 6,
                          top: _yFor(widget.target!, widget.height) - 16,
                          child: Text(
                            (widget.targetLabel ??
                                    'Target ${mlThousands(widget.target!.round())} t')
                                .toUpperCase(),
                            style: TextStyle(
                              fontFamily: MlGlass.mono,
                              fontSize: 9,
                              letterSpacing: 2,
                              fontWeight: FontWeight.w500,
                              color: t.accent2.withValues(alpha: 0.8),
                            ),
                          ),
                        ),

                      if (widget.latestLabel.isNotEmpty)
                        Positioned(
                          right: 0,
                          top: -6,
                          child: _LatestPill(
                              label: widget.latestLabel, tokens: t),
                        ),

                      if (_hoverIndex != null && pts.isNotEmpty)
                        _tooltip(pts, c.maxWidth, t),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _xAxis(t, n),
        const SizedBox(height: 8),
        _footer(t),
      ],
    );
  }

  double _yFor(double v, double h) =>
      h - ((v - _min) / (_max - _min)) * h;

  Widget _tooltip(List<Offset> pts, double width, MlGlass t) {
    final i = _hoverIndex!.clamp(0, pts.length - 1);
    final p = pts[i];
    final frac = p.dx / width;

    final cur = widget.current[i];
    final prev = i < widget.previous.length ? widget.previous[i] : null;

    // Flip the card away from whichever edge it would overrun.
    final alignRight = frac > 0.82;
    final alignLeft = frac < 0.14;

    return Positioned(
      left: alignLeft ? p.dx : null,
      right: alignRight ? width - p.dx : null,
      top: math.max(0, p.dy - 92),
      child: FractionalTranslation(
        translation:
            alignLeft || alignRight ? Offset.zero : const Offset(-0.5, 0),
        child: Container(
          constraints: const BoxConstraints(minWidth: 96),
          padding: const EdgeInsets.fromLTRB(11, 8, 11, 9),
          decoration: BoxDecoration(
            color: t.bg0.withValues(alpha: 0.94),
            border: Border.all(color: t.lineStrong),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: MlTokens.overlayDark.withValues(alpha: t.isDark ? 0.9 : 0.18),
                blurRadius: 32,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.monthLabel} ${(i + 1).toString().padLeft(2, '0')}'
                    .toUpperCase(),
                style: TextStyle(
                  fontFamily: MlGlass.mono,
                  fontSize: 9,
                  letterSpacing: 1.6,
                  color: t.inkLo,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_fmt(cur)} t',
                style: TextStyle(
                  fontFamily: MlGlass.mono,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: t.inkHi,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (prev != null) ...[
                const SizedBox(height: 3),
                Text(
                  '${widget.priorLabel.split(' ').first} · ${_fmt(prev)} t',
                  style: TextStyle(
                    fontFamily: MlGlass.mono,
                    fontSize: 10,
                    color: t.inkMid,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _xAxis(MlGlass t, int n) {
    final style = TextStyle(
      fontFamily: MlGlass.mono,
      fontSize: 9,
      letterSpacing: 1.4,
      color: t.inkLo,
    );
    return SizedBox(
      height: 14,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          children: [
            for (final e in widget.xLabels.entries)
              Positioned(
                left: (e.key / (n - 1)) * c.maxWidth - (e.key == 0 ? 0 : 8),
                child: Text(e.value, style: style),
              ),
            Positioned(
              right: 0,
              child: Text('Today', style: style.copyWith(color: t.inkMid)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _footer(MlGlass t) {
    Widget swatch(Color color, {bool dashed = false}) => Container(
          width: 16,
          height: 2,
          decoration: BoxDecoration(
            color: dashed ? null : color,
            border: dashed
                ? Border(top: BorderSide(color: color, width: 2))
                : null,
          ),
        );

    Widget legend(String label, Widget sw) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            sw,
            const SizedBox(width: 7),
            Text(label,
                style: TextStyle(fontSize: 10.5, color: t.inkMid)),
          ],
        );

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              legend('This period', swatch(t.accent)),
              legend(widget.priorLabel,
                  swatch(t.inkMid.withValues(alpha: 0.7), dashed: true)),
              legend('Target', swatch(t.accent2.withValues(alpha: 0.6), dashed: true)),
            ],
          ),
        ),
        Text(
          widget.unitCaption.toUpperCase(),
          style: TextStyle(
            fontFamily: MlGlass.mono,
            fontSize: 9,
            letterSpacing: 1.8,
            color: t.inkXlo,
          ),
        ),
      ],
    );
  }

  static String _fmt(double v) {
    final s = v.round().toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _LatestPill extends StatelessWidget {
  const _LatestPill({required this.label, required this.tokens});

  final String label;
  final MlGlass tokens;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: t.bg0.withValues(alpha: 0.92),
        border: Border.all(color: t.accent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: t.accent.withValues(alpha: 0.10),
            blurRadius: 0,
            spreadRadius: 3,
          ),
          BoxShadow(
            color: MlTokens.overlayDark.withValues(alpha: t.isDark ? 0.85 : 0.15),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: MlGlass.mono,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: t.inkHi,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _FlagshipPainter extends CustomPainter {
  const _FlagshipPainter({
    required this.current,
    required this.previous,
    required this.target,
    required this.min,
    required this.max,
    required this.t,
    required this.hoverIndex,
  });

  final List<double> current;
  final List<double> previous;
  final double? target;
  final double min;
  final double max;
  final MlGlass t;
  final int? hoverIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (current.length < 2) return;

    final curPts = _project(current, size,
        topPad: 0, bottomPad: 0, forcedMin: min, forcedMax: max);
    final prevPts = _project(previous, size,
        topPad: 0, bottomPad: 0, forcedMin: min, forcedMax: max);

    // Faint horizontal guides at thirds
    final guide = Paint()
      ..color = t.isDark
          ? MlTokens.overlayLight.withValues(alpha: 0.03)
          : MlTokens.overlayDark.withValues(alpha: 0.04)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height * 0.33),
        Offset(size.width, size.height * 0.33), guide);
    canvas.drawLine(Offset(0, size.height * 0.66),
        Offset(size.width, size.height * 0.66), guide);

    final curPath = mlSmoothPath(curPts);

    // Area under the current series
    final area = Path.from(curPath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            t.accent.withValues(alpha: 0.32),
            t.accent.withValues(alpha: 0.08),
            t.accent.withValues(alpha: 0),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(Offset.zero & size),
    );

    // Target line — drawn only when there is one.
    if (target != null) {
      final ty = size.height - ((target! - min) / (max - min)) * size.height;
      canvas.drawPath(
        mlDashPath(
          Path()
            ..moveTo(0, ty)
            ..lineTo(size.width, ty),
          dash: 7,
          gap: 8,
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = t.accent2.withValues(alpha: 0.45),
      );
    }

    // Prior month
    canvas.drawPath(
      mlDashPath(mlSmoothPath(prevPts), dash: 3, gap: 6),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = t.inkMid.withValues(alpha: 0.55),
    );

    // Current series
    canvas.drawPath(
      curPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..shader = LinearGradient(
          colors: [t.accent3, t.accent],
        ).createShader(Offset.zero & size),
    );

    // Every third point, plus the last
    for (var i = 0; i < curPts.length; i++) {
      final isEnd = i == curPts.length - 1;
      if (!isEnd && i % 3 != 0) continue;
      final p = curPts[i];
      if (isEnd) {
        canvas.drawCircle(
            p, 10, Paint()..color = t.accent.withValues(alpha: 0.16));
        canvas.drawCircle(p, 3.5, Paint()..color = t.accent);
      } else {
        canvas.drawCircle(p, 3.5, Paint()..color = t.panel);
        canvas.drawCircle(
          p,
          3.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = t.accent,
        );
      }
    }

    // Crosshair
    if (hoverIndex != null) {
      final i = hoverIndex!.clamp(0, curPts.length - 1);
      final p = curPts[i];
      canvas.drawLine(
        Offset(p.dx, 0),
        Offset(p.dx, size.height),
        Paint()
          ..strokeWidth = 1
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              t.accent2.withValues(alpha: 0),
              t.accent2.withValues(alpha: 0.55),
              t.accent2.withValues(alpha: 0.55),
              t.accent2.withValues(alpha: 0),
            ],
            stops: const [0, 0.3, 0.7, 1],
          ).createShader(
              Rect.fromLTWH(p.dx - 1, 0, 2, size.height)),
      );
      canvas.drawCircle(p, 4.5, Paint()..color = t.accent);
      canvas.drawCircle(
        p,
        4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = t.inkHi.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FlagshipPainter old) =>
      old.hoverIndex != hoverIndex ||
      old.current != current ||
      old.t.isDark != t.isDark;
}

// ---------------------------------------------------------------------------
// Donut
// ---------------------------------------------------------------------------

class MlDonut extends StatelessWidget {
  const MlDonut({
    super.key,
    required this.segments,
    required this.trackColor,
    this.size = 160,
    this.thickness = 18,
    this.centre,
  });

  final List<MlDonutSegment> segments;
  final Color trackColor;
  final double size;
  final double thickness;
  final Widget? centre;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size.square(size),
            painter: _DonutPainter(segments, thickness, trackColor),
          ),
          if (centre != null) centre!,
        ],
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter(this.segments, this.thickness, this.trackColor);

  final List<MlDonutSegment> segments;
  final double thickness;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (a, s) => a + s.value);
    if (total <= 0) return;

    final r = (size.width - thickness) / 2;
    final rect = Rect.fromCircle(
      center: Offset(size.width / 2, size.height / 2),
      radius: r,
    );

    canvas.drawCircle(
      rect.center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = trackColor,
    );

    var start = -math.pi / 2;
    for (final s in segments) {
      final sweep = (s.value / total) * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.butt
          ..color = s.color,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.segments != segments || old.trackColor != trackColor;
}

// ---------------------------------------------------------------------------
// Ridge — the 15-day tempo bars on transporter cards
// ---------------------------------------------------------------------------

class MlRidge extends StatelessWidget {
  const MlRidge({
    super.key,
    required this.data,
    required this.color,
    this.height = 32,
  });

  final List<double> data;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    // A company with no tonnage in the window makes every bar 0, and 0/0 is
    // NaN — which a Container height turns into a layout assertion. Fall back
    // to 1 so an idle transporter renders a flat floor instead of crashing.
    final peak = data.isEmpty ? 0.0 : data.reduce(math.max);
    final max = peak > 0 ? peak : 1.0;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < data.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minWidth: 3),
                height: math.max(3, (data[i] / max) * height),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color, color.withValues(alpha: 0.3)],
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

// ---------------------------------------------------------------------------
// Meter — utilisation / on-time / seat bars
// ---------------------------------------------------------------------------

class MlMeter extends StatelessWidget {
  const MlMeter({
    super.key,
    required this.value,
    required this.track,
    required this.fill,
    this.height = 4,
    this.radius = 2,
    this.gradientEnd,
  });

  /// 0–1.
  final double value;
  final Color track;
  final Color fill;
  final Color? gradientEnd;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: height,
        color: track,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: gradientEnd == null
                  ? null
                  : LinearGradient(colors: [fill, gradientEnd!]),
              color: gradientEnd == null ? fill : null,
            ),
          ),
        ),
      ),
    );
  }
}
