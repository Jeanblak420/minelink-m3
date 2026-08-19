import 'package:flutter/material.dart';

/// A responsive row of equal-width tiles that wraps.
///
/// S5-17 (P6-09). The portal hand-rolls this shape in **16 files** — a
/// `LayoutBuilder`, a breakpoint ladder, `(maxWidth - gap * (cols - 1)) / cols`,
/// and a `Wrap` of `SizedBox`es. The arithmetic is subtly wrong in some of them
/// (a `cols <= 1` guard present in one copy, absent in the next) and the
/// breakpoints disagree screen to screen: 980/620 here, 900/560 there,
/// 820/420 elsewhere, for tiles of the same size.
///
/// The gate called this "3 copies of `_wrap(w, cols, tiles)`". Only one
/// function was ever named `_wrap`; the duplication is the *shape*, not the
/// name, and it is five times larger than the gate describes.
///
/// Two ways to use it:
///  * [MlTileGrid] — give it [minTileWidth] and it works the columns out. This
///    is the one to reach for: it has no arbitrary breakpoints to disagree with
///    anyone else's, and it cannot produce a tile narrower than its content.
///  * [MlTileGrid.columns] — keep an existing explicit ladder, for a screen
///    whose column counts are deliberate.
class MlTileGrid extends StatelessWidget {
  const MlTileGrid({
    super.key,
    required this.children,
    this.minTileWidth = 260,
    this.gap = 14,
    this.maxColumns,
  }) : _columnsFor = null;

  /// Keep an explicit breakpoint ladder: `(availableWidth) => columnCount`.
  const MlTileGrid.columns({
    super.key,
    required this.children,
    required int Function(double width) columnsFor,
    this.gap = 14,
  })  : _columnsFor = columnsFor,
        minTileWidth = 0,
        maxColumns = null;

  final List<Widget> children;
  final double minTileWidth;
  final double gap;
  final int? maxColumns;
  final int Function(double width)? _columnsFor;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        var cols = _columnsFor?.call(width) ??
            ((width + gap) / (minTileWidth + gap)).floor();
        // Never zero (a viewport narrower than one tile still gets one column),
        // never more tiles than there are, never past an explicit cap. The
        // missing `cols <= 1` guard is what made one hand-rolled copy divide
        // by a negative gap total on a narrow screen.
        cols = cols.clamp(1, children.length);
        if (maxColumns != null) cols = cols.clamp(1, maxColumns!);
        final tileWidth =
            cols <= 1 ? width : (width - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}
