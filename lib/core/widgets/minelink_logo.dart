import 'package:flutter/material.dart';

/// Official MineLink Technologies branding (assets/branding/*):
/// [MineLinkLogo] is the full stacked logo (chain-link mark + wordmark),
/// [MineLinkMark] is the chain-link mark alone (also the app icon artwork).
///
/// Two colorways, both supplied by the brand owner and cropped to their
/// content bounds (2026-08-05):
///  - white/gold — the DEFAULT everywhere in-app (the chrome that carries the
///    brand — auth, super-admin console, boot screen — is always dark navy)
///  - black/gold — only when explicitly requested via `onDark: false`
///    (reserved for genuinely light surfaces, e.g. printed/PDF output).

class MineLinkLogo extends StatelessWidget {
  static const assetLight = 'assets/branding/minelink_logo.png'; // black/gold
  static const assetDark = 'assets/branding/minelink_logo_white.png';

  final double? height;
  final double? width;

  /// true (default) = white/gold artwork; false = black/gold artwork for
  /// genuinely light surfaces.
  final bool? onDark;

  const MineLinkLogo({super.key, this.height, this.width, this.onDark});

  @override
  Widget build(BuildContext context) {
    final dark = onDark ?? true;
    // Only default the height when the caller sized neither axis — passing
    // width alone must NOT also pin height, or the art letterboxes down to
    // the 64px default inside the requested width.
    final h = height ?? (width == null ? 64.0 : null);
    return Image.asset(
      dark ? assetDark : assetLight,
      height: h,
      width: width,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'MineLink Technologies',
    );
  }
}

/// The chain-link brand mark alone — squarish, used for compact brand spots
/// (collapsed sidebars, auth headers).
class MineLinkMark extends StatelessWidget {
  static const assetLight = 'assets/branding/minelink_mark.png';
  static const assetDark = 'assets/branding/minelink_mark_white.png';

  final double size;

  /// Same colorway contract as [MineLinkLogo.onDark]: white/gold by default.
  final bool? onDark;

  const MineLinkMark({super.key, this.size = 44, this.onDark});

  @override
  Widget build(BuildContext context) {
    final dark = onDark ?? true;
    return Image.asset(
      dark ? assetDark : assetLight,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'MineLink',
    );
  }
}
