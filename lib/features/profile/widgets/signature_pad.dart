import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Holds the strokes drawn on a [SignaturePad] and exports them as a
/// transparent-background PNG (CLAUDE.md §4 — signatures are stored as
/// transparent PNGs and composited onto waybills/PODs).
class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = <List<Offset>>[];
  Size _canvasSize = Size.zero;

  /// Set by the pad on layout so exports match what the user drew.
  set canvasSize(Size value) => _canvasSize = value;

  bool get hasContent => _strokes.any((stroke) => stroke.isNotEmpty);

  List<List<Offset>> get strokes => _strokes;

  void startStroke(Offset point) {
    _strokes.add(<Offset>[point]);
    notifyListeners();
  }

  void appendPoint(Offset point) {
    if (_strokes.isEmpty) return;
    _strokes.last.add(point);
    notifyListeners();
  }

  void clear() {
    if (_strokes.isEmpty) return;
    _strokes.clear();
    notifyListeners();
  }

  /// Renders the strokes to a transparent PNG. Returns null if nothing was
  /// drawn. [pixelRatio] over-samples for a crisp result on print/high-DPI.
  Future<Uint8List?> exportPng({
    double pixelRatio = 3.0,
    Color color = MlTokens.signatureInk,
    double strokeWidth = 2.6,
  }) async {
    if (!hasContent || _canvasSize.isEmpty) return null;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final stroke = Paint()
      ..color = color
      ..strokeWidth = strokeWidth * pixelRatio
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final points in _strokes) {
      if (points.isEmpty) continue;
      if (points.length == 1) {
        final p = points.first.scale(pixelRatio, pixelRatio);
        canvas.drawCircle(p, strokeWidth * pixelRatio / 2, dot);
        continue;
      }
      final path = Path()
        ..moveTo(points.first.dx * pixelRatio, points.first.dy * pixelRatio);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx * pixelRatio, p.dy * pixelRatio);
      }
      canvas.drawPath(path, stroke);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (_canvasSize.width * pixelRatio).round(),
      (_canvasSize.height * pixelRatio).round(),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}

/// A finger/mouse-draw signature canvas. Pair it with a [SignaturePadController]
/// to read [SignaturePadController.hasContent] and export the PNG.
class SignaturePad extends StatelessWidget {
  const SignaturePad({
    super.key,
    required this.controller,
    this.height = 190,
  });

  final SignaturePadController controller;
  final double height;

  Offset _clamp(Offset p, Size size) => Offset(
        p.dx.clamp(0.0, size.width),
        p.dy.clamp(0.0, size.height),
      );

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, height);
        controller.canvasSize = size;
        return Container(
          height: height,
          decoration: BoxDecoration(
            color: semantic.surfaceCard,
            borderRadius: BorderRadius.circular(MlTokens.rMd),
            border: Border.all(color: semantic.borderCard),
          ),
          clipBehavior: Clip.antiAlias,
          child: GestureDetector(
            onPanStart: (d) =>
                controller.startStroke(_clamp(d.localPosition, size)),
            onPanUpdate: (d) =>
                controller.appendPoint(_clamp(d.localPosition, size)),
            child: CustomPaint(
              painter: _SignaturePainter(
                controller,
                MlSemantic.of(context).textStrong,
              ),
              size: size,
            ),
          ),
        );
      },
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.controller, this.color)
      : super(repaint: controller);

  final SignaturePadController controller;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final points in controller.strokes) {
      if (points.isEmpty) continue;
      if (points.length == 1) {
        canvas.drawCircle(points.first, 1.3, dot);
        continue;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => false;
}
