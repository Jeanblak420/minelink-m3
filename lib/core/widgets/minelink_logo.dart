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

  /// The committed artwork is 1281x991, so the lockup is this much wider than
  /// it is tall. Named here because [legibleHeight] has to reason about a
  /// caller who sized the WIDTH — `BoxFit.contain` then derives the height,
  /// and a width small enough to crush the strapline looks perfectly innocent
  /// at the call site.
  static const lockupAspect = 1281 / 991;

  /// Below this the lockup stops being a logo and starts being a smudge.
  ///
  /// The artwork is three stacked bands of ink, and the two type bands are the
  /// small ones — "MineLink" is 231 of the 991 rows and the letter-spaced
  /// "TECHNOLOGIES" strapline is 67. At this height they draw 14.9px and 4.3px
  /// respectively, which is the floor at which both are still type. At the 28
  /// the rail used to ask for, they drew 6.5px and **1.89px**.
  ///
  /// It is deliberately the widget's own default height: asking for less than
  /// the default is asking for [MineLinkMark], and that is what the assert
  /// says.
  static const legibleHeight = 64.0;

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
    final h = height ?? (width == null ? legibleHeight : null);
    assert(
      (h ?? double.infinity) >= legibleHeight,
      'MineLinkLogo asked for height ${h!} — the stacked lockup is illegible '
      'below $legibleHeight (its strapline draws under 4.3px). Use '
      'MineLinkMark for a compact brand spot.',
    );
    assert(
      width == null || width! / lockupAspect >= legibleHeight,
      'MineLinkLogo asked for width $width, which BoxFit.contain resolves to '
      '${(width ?? 0) / lockupAspect} tall — below the $legibleHeight the '
      'lockup needs. Use MineLinkMark for a compact brand spot.',
    );
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
