import 'package:flutter/material.dart';

/// A table that is wider than its column, with a scrollbar that says so.
///
/// ## Why this exists
///
/// A `SingleChildScrollView(scrollDirection: Axis.horizontal)` around a table
/// is correct — a thirteen-column fleet register cannot be made to fit a laptop
/// and should not be truncated to try. What it does not do is **tell anyone**.
/// Flutter draws no scrollbar for a horizontal scroll view unless one is asked
/// for, so what a reader sees is a last column cut off mid-word and no reason
/// to think there is anything past it. On a desktop, with no touch surface to
/// flick, that is simply a broken-looking table.
///
/// Measured 2026-08-20: **fifteen of the sixteen** horizontal scroll views in
/// `lib/` had no scrollbar. The one that did — the raw recon table — is where
/// this treatment comes from, `Scrollbar(thumbVisibility: true)` over a scroll
/// view with `padding: bottom 8` so the bar does not sit on the last row. It
/// was right, and it had never spread.
///
/// ## Why it owns a controller
///
/// `thumbVisibility: true` needs a `ScrollController` the `Scrollbar` can
/// actually attach to. A horizontal `SingleChildScrollView` does **not** adopt
/// the `PrimaryScrollController` (that is vertical-only by default), so a
/// `Scrollbar` given neither asserts at runtime — in debug, on the screen that
/// scrolls, which is the worst place to find out. One controller, created here,
/// handed to both.
///
/// ## What it is not for
///
/// Chip strips, avatar stacks and toolbars also scroll horizontally, and a
/// scrollbar under those reads as chrome rather than as information. This is
/// for **tabular** content, where a hidden column is hidden data.
class MlWideTable extends StatefulWidget {
  const MlWideTable({
    super.key,
    required this.child,
    this.minWidth,
  });

  /// The table itself.
  final Widget child;

  /// The width below which the table scrolls rather than compresses.
  ///
  /// Null means the child sizes itself — which is what a Material `DataTable`
  /// does, since it measures its own columns.
  final double? minWidth;

  @override
  State<MlWideTable> createState() => _MlWideTableState();
}

class _MlWideTableState extends State<MlWideTable> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Wide enough already: no scroll view, and therefore no bar. A
        // scrollbar over content that cannot scroll is a promise of more.
        if (widget.minWidth != null && constraints.maxWidth >= widget.minWidth!) {
          return widget.child;
        }
        return Scrollbar(
          controller: _controller,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            // Room for the bar, so it does not sit on the last row.
            padding: const EdgeInsets.only(bottom: 8),
            child: widget.minWidth == null
                ? widget.child
                : SizedBox(width: widget.minWidth, child: widget.child),
          ),
        );
      },
    );
  }
}
