import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_rail_tokens.dart';

/// The workspace canvas both shells paint behind their content.
///
/// S5-11 (P5-17): carved VERBATIM out of `super_admin_shell_layout.dart`, where
/// it was the private `_WorkspaceCanvasPainter` — private meaning the portal
/// shell could not use it even though it wants the same surface. S5-10 merges
/// the two shells; a canvas painter only one of them can reach is a canvas the
/// other hand-copies.
///
/// Not a rewrite: the class body was moved, then renamed. Values unchanged.

/// Design workspace canvas. Light: `#E0E7F0` base + cyan/blue radial brand
/// washes + a 24px dot grid (`rgba(15,23,42,.045)`), so the white cards read
/// as distinct floating surfaces. Dark: flat `#070C17`. The texture layer is
/// user-toggleable from Settings → User Preferences.
/// The page ground, for the rare widget that has to paint it itself.
///
/// [MlWorkspaceCanvasPainter] paints this behind every routed screen, so a
/// screen inside either `ShellRoute` must NOT paint a ground of its own — 18
/// of them did, in a colour one step lighter (`#0A1424` over `#060B15`), which
/// is how the product came to have two page colours decided by nothing but
/// whether a screen happened to wrap itself in a `Scaffold`.
///
/// A page pushed with `Navigator.push` is the exception: it covers the shell,
/// so nothing is painting behind it and `Colors.transparent` leaves it BLACK.
/// Those pass this.
Color mlWorkspaceGround(Brightness brightness) =>
    brightness == Brightness.dark ? mlConsoleCanvasDark : mlConsoleCanvasLight;

class MlWorkspaceCanvasPainter extends CustomPainter {
  final bool dark;
  final bool texture;
  const MlWorkspaceCanvasPainter({required this.dark, required this.texture});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (dark) {
      canvas.drawRect(rect, Paint()..color = mlConsoleCanvasDark);
      return;
    }
    canvas.drawRect(rect, Paint()..color = mlConsoleCanvasLight);
    if (!texture) return;

    // Soft brand washes (design: radial-gradients at 88%/-12% and -8%/2%).
    void wash(Offset center, double radius, Color color) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawRect(rect, paint);
    }

    wash(
      Offset(size.width * 0.88, -size.height * 0.12),
      size.width * 0.55,
      mlCanvasBloomCyan,
    );
    wash(
      Offset(-size.width * 0.08, size.height * 0.02),
      size.width * 0.5,
      mlCanvasBloomBlue,
    );

    // 24px engineering dot grid.
    final dot = Paint()..color = mlCanvasDot;
    for (double y = 12; y < size.height; y += 24) {
      for (double x = 12; x < size.width; x += 24) {
        canvas.drawCircle(Offset(x, y), 1.1, dot);
      }
    }
  }

  @override
  bool shouldRepaint(MlWorkspaceCanvasPainter old) =>
      old.dark != dark || old.texture != texture;
}
