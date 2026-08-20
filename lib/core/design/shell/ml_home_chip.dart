import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/ml_rail_tokens.dart';

/// The rail's "home" chip — a 38px bordered square with the dashboard glyph.
///
/// S5-11 (P5-20): carved VERBATIM out of `super_admin_shell_layout.dart`, where
/// it was the private `_HomeButton`. The portal shell had its own hand-copied
/// version inline in `portal_shell_layout.dart` — same 38px box, same 11px
/// radius, same glyph — because the original was private and unreachable. The
/// two had already drifted: the portal's hardcoded the border to
/// `MlTokens.sidebarActiveBlue` and the ink to `mlRailAccentLift` in BOTH
/// themes, so on a light portal it drew an ice-blue glyph meant for dark.
///
/// One copy now, theme-aware, and the portal's is deleted.

class MlHomeChip extends StatelessWidget {
  final VoidCallback onTap;
  const MlHomeChip({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? mlRailAccentLift : mlRailAccent;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: MlShape.radiusMedium,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: MlShape.radiusMedium,
            // Design: 1px accent-ink border (matches the glyph ink).
            border: Border.all(color: ink),
          ),
          child: Icon(Icons.space_dashboard_outlined, size: 20, color: ink),
        ),
      ),
    );
  }
}
