import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';

/// Faint grid "paper" map backdrop (major 120px + minor 24px slate grid),
/// used behind floating truck pins/cards where no live tiles are shown.
class MlMapCanvas extends StatelessWidget {
  final Widget? child;
  final double? height;

  const MlMapCanvas({super.key, this.child, this.height});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: dark
              ? [MlPortalSurfaces.mapDarkTop, MlPortalSurfaces.mapDarkBottom]
              : [MlPortalSurfaces.mapLightTop, MlPortalSurfaces.mapLightBottom],
        ),
        borderRadius: BorderRadius.circular(MlTokens.rLg),
        border: Border.all(color: semantic.borderCard),
      ),
      child: CustomPaint(
        painter: _GridPaperPainter(dark: dark),
        child: child ?? const SizedBox.expand(),
      ),
    );
  }
}

class _GridPaperPainter extends CustomPainter {
  final bool dark;
  const _GridPaperPainter({required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final minor = Paint()
      ..color = dark ? MlPortalSurfaces.mapGridDark : MlPortalSurfaces.mapGridLight
      ..strokeWidth = 1;
    final major = Paint()
      ..color = dark
          ? MlPortalSurfaces.mapGridDarkMajor
          : MlPortalSurfaces.mapGridLightMajor
      ..strokeWidth = 1;

    for (double x = 0; x <= size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), minor);
    }
    for (double y = 0; y <= size.height; y += 24) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    }
    for (double x = 0; x <= size.width; x += 120) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), major);
    }
    for (double y = 0; y <= size.height; y += 120) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), major);
    }
  }

  @override
  bool shouldRepaint(_GridPaperPainter oldDelegate) =>
      oldDelegate.dark != dark;
}
