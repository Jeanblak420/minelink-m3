import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// The standard scrollable page body: one column, centred, capped, padded.
///
/// S5-14 (P5-32). Was `MlPageBody` in `features/portal/widgets/`, at
/// `EdgeInsets.fromLTRB(16, 16, 16, 32)` and a 1200px cap. Both are now the
/// design tokens the console already uses — `MlTokens.contentPadding` (28) and
/// `MlTokens.contentMaxWidth` (1280) — so a portal page and a console page
/// measure the same, which is the whole point of one design system.
///
/// It lives in `core/design/components/` rather than the portal feature for
/// the same reason the tokens moved: a layout primitive owned by one feature
/// is one the other feature hand-copies.
class MlPageBody extends StatelessWidget {
  const MlPageBody({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth,
  });

  final Widget child;

  /// Defaults to a RESPONSIVE gutter: [MlTokens.contentPadding] (28) at tablet
  /// width and above, 16 below it.
  ///
  /// 28 is a desktop console measure. On a 360px phone it takes 56px of a
  /// 360px viewport — 16% of the screen given to margin — and that alone
  /// pushed a filter row into a 12px overflow the moment this replaced the
  /// portal's old flat 16. The reference is a desktop surface; phones need a
  /// tighter gutter, and pretending otherwise just moves the problem into
  /// every screen's layout instead of solving it once here.
  final EdgeInsetsGeometry? padding;

  /// Below this the gutter tightens to 16.
  static const double _tightGutterBelow = 600;

  /// Defaults to [MlTokens.contentMaxWidth]. Never wider than the viewport.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final cap = maxWidth ?? MlTokens.contentMaxWidth;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: padding ??
            EdgeInsets.all(constraints.maxWidth < _tightGutterBelow
                ? 16
                : MlTokens.contentPadding),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            // min() so a narrow viewport is never handed a wider constraint
            // than it has — that is how a page ends up scrolling sideways.
            constraints:
                BoxConstraints(maxWidth: math.min(constraints.maxWidth, cap)),
            child: child,
          ),
        ),
      ),
    );
  }
}
