// ============================================================================
// Transporters overview — shared primitives
// ----------------------------------------------------------------------------
// Ported from the drop's `widgets/primitives.dart`. Names carry an `Ov` prefix
// so they cannot collide with the identically-named widgets in
// `insights_v2/minelink_screens_core.dart`, which a caller may well import in
// the same file.
// ============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter_application_1/core/design/tokens/ml_overview_tokens.dart';

/// The standard portal card: translucent navy, hairline border, top sheen,
/// cyan bloom, soft drop shadow.
///
/// [accent] is the "pop" variant. **Exactly one card on this screen may use
/// it** — the leaderboard. It is the visual anchor of the right column, and a
/// second one collapses the hierarchy.
class OvGlassCard extends StatelessWidget {
  const OvGlassCard({
    super.key,
    required this.tokens,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.accent = false,
    this.hoverGlow = false,
  });

  final MlOv tokens;
  final Widget child;
  final EdgeInsets padding;
  final bool accent;

  /// Brightens the accent card's cyan glow while the pointer is over it — the
  /// other half of the leaderboard card's "this opens something" signal. Only
  /// meaningful with [accent]; a plain card has no glow to brighten.
  final bool hoverGlow;

  /// The drop's hover state: `0 0 56px -18px rgba(34,211,238,.70)`, over the
  /// same drop shadow the resting card carries.
  static List<BoxShadow> _brightGlow(MlOv t) => [
        BoxShadow(
          color: t.acc.withValues(alpha: 0.7),
          blurRadius: 56,
          spreadRadius: -18,
        ),
        ...t.accentCardShadow.skip(1),
      ];

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final radius = BorderRadius.circular(MlOv.rCard);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: accent
            ? (hoverGlow ? _brightGlow(t) : t.accentCardShadow)
            : t.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: accent ? t.accentBase : t.glassBase,
            borderRadius: radius,
            border: Border.all(
              color: accent ? t.acc.withValues(alpha: 0.26) : t.overlay(0.08),
            ),
          ),
          child: Stack(
            children: [
              // Sheen, or the accent card's diagonal cyan→teal→navy wash.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: accent
                        ? LinearGradient(
                            begin: const Alignment(-0.9, -1),
                            end: const Alignment(0.9, 1),
                            colors: [
                              t.acc.withValues(alpha: 0.10),
                              t.acc3.withValues(alpha: 0.04),
                              t.glassBase.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.42, 0.78],
                          )
                        : t.glassSheen,
                  ),
                ),
              ),
              // Cyan bloom.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: accent
                        ? RadialGradient(
                            center: const Alignment(-1, -1),
                            radius: 1.2,
                            colors: [
                              t.acc.withValues(alpha: 0.18),
                              t.acc.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.62],
                          )
                        : t.cardBloom,
                  ),
                ),
              ),
              // The 1px inner top highlight. On the accent card it fades
              // transparent → cyan 70% → transparent.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent ? null : t.overlay(0.06),
                    gradient: accent
                        ? LinearGradient(
                            colors: [
                              t.acc.withValues(alpha: 0),
                              t.acc.withValues(alpha: 0.7),
                              t.acc.withValues(alpha: 0),
                            ],
                          )
                        : null,
                  ),
                ),
              ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pill badge: `padding 3px 9px`, 10.5px/600, fully rounded.
class OvPill extends StatelessWidget {
  const OvPill({
    super.key,
    required this.tokens,
    required this.label,
    required this.tone,
    this.mono = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    this.fontSize = 11,
  });

  final MlOv tokens;
  final String label;
  final OvTone tone;
  final bool mono;
  final EdgeInsets padding;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final t = tokens;
    final c = t.tone(tone);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(MlOv.rPill),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: mono
            ? t.m(size: fontSize, color: c, letterSpacing: 0.42)
            : t.s(
                size: fontSize,
                weight: FontWeight.w600,
                color: c,
                letterSpacing: 0.42,
              ),
      ),
    );
  }
}

/// The tinted rounded-square icon well used beside metrics and alerts.
class OvIconWell extends StatelessWidget {
  const OvIconWell({
    super.key,
    required this.tokens,
    required this.icon,
    required this.tone,
    this.size = 30,
    this.iconSize = 16,
    this.radius = MlOv.rWell,
  });

  final MlOv tokens;
  final IconData icon;
  final OvTone tone;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = tokens.tone(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Icon(icon, size: iconSize, color: c),
    );
  }
}

/// Card eyebrow + optional trailing pill.
class OvCardHeader extends StatelessWidget {
  const OvCardHeader({
    super.key,
    required this.tokens,
    required this.label,
    this.trailing,
  });

  final MlOv tokens;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tokens.eyebrow,
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 10), trailing!],
        ],
      );
}

/// Thin progress meter used by utilisation and the leaderboard.
class OvMeter extends StatelessWidget {
  const OvMeter({
    super.key,
    required this.fraction,
    this.height = 4,
    this.gradient,
    this.color,
    required this.track,
    this.glowColor,
  });

  final double fraction;
  final double height;
  final Gradient? gradient;
  final Color? color;
  final Color track;

  /// Non-null draws the leader's cyan bloom under the fill.
  final Color? glowColor;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Container(
          height: height,
          color: track,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: fraction.isFinite ? fraction.clamp(0.0, 1.0) : 0.0,
            // Stated, not inferred — see the guard
            // `fractional-fill-declares-its-height`.
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: gradient,
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
                boxShadow: glowColor == null
                    ? null
                    : [
                        BoxShadow(
                          color: glowColor!.withValues(alpha: 0.8),
                          blurRadius: 12,
                          spreadRadius: -2,
                        ),
                      ],
              ),
            ),
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Flex row
// ---------------------------------------------------------------------------

/// One child of an [OvFlexRow].
@immutable
class OvFlexItem {
  const OvFlexItem({
    required this.basis,
    required this.minWidth,
    required this.child,
    this.grow = true,
  });

  final double basis;
  final double minWidth;
  final bool grow;
  final Widget child;
}

/// A CSS-flex row: each child declares a `basis` and a `minWidth`, and leftover
/// width is shared **equally** (`flex-grow: 1`) rather than proportionally.
/// Collapses to a Column once the minimums no longer fit.
///
/// Do not swap this for `Expanded(flex:)` — proportional flex gives visibly
/// different column widths, which is the drop's first listed way to break the
/// match (README §9).
class OvFlexRow extends StatelessWidget {
  const OvFlexRow({
    super.key,
    required this.items,
    this.gap = 18,
    this.crossAxisAlignment = CrossAxisAlignment.start,
    this.stackedGap,
    this.equalHeight = false,
  });

  final List<OvFlexItem> items;
  final double gap;

  /// Do **not** pass [CrossAxisAlignment.stretch]. The CSS this ports uses
  /// `align-items: stretch`, but a Flutter `Row` inside a scroll view has
  /// unbounded height, and stretch then hands its children `h=Infinity`
  /// (CLAUDE.md §10.4). Use [equalHeight] for that look — it measures instead
  /// of stretching, so it works under an unbounded parent.
  final CrossAxisAlignment crossAxisAlignment;

  final double? stackedGap;

  /// Run every card in the row to the height of the tallest, so the row reads
  /// as one band rather than a ragged bottom edge. Ignored once the row
  /// collapses to a column, where there is no neighbour to match.
  ///
  /// Costs a second layout pass over the row (see [_EqualHeightRow]); leave it
  /// off for rows whose cards already end level.
  final bool equalHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final totalGap = gap * (items.length - 1);
        final minSum =
            items.fold<double>(0, (a, b) => a + b.minWidth) + totalGap;

        if (!c.hasBoundedWidth || c.maxWidth < minSum) {
          final g = stackedGap ?? gap;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(height: g),
                items[i].child,
              ],
            ],
          );
        }

        final basisSum = items.fold<double>(0, (a, b) => a + b.basis) + totalGap;
        final growers = items.where((i) => i.grow).length;
        final extra = c.maxWidth - basisSum;
        final share = growers == 0 ? 0.0 : extra / growers;

        final widths = items
            .map((i) => (i.basis + (i.grow ? share : 0))
                .clamp(i.minWidth, double.infinity))
            .toList();

        // Re-balance if clamping overflowed the line.
        final sum = widths.fold<double>(0, (a, b) => a + b) + totalGap;
        if (sum > c.maxWidth) {
          final scale = (c.maxWidth - totalGap) / (sum - totalGap);
          for (var i = 0; i < widths.length; i++) {
            widths[i] = widths[i] * scale;
          }
        }

        if (equalHeight) {
          return _EqualHeightRow(
            widths: widths,
            gap: gap,
            children: [for (final item in items) item.child],
          );
        }

        return Row(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(width: gap),
              SizedBox(width: widths[i], child: items[i].child),
            ],
          ],
        );
      },
    );
  }
}

/// Lays each child out at its given column width, then re-lays all of them
/// with the tallest one's height as a floor.
///
/// This is `align-items: stretch` from the CSS this screen ports. Flutter's
/// answer is normally `IntrinsicHeight`, but that asks each child for an
/// intrinsic height and `LayoutBuilder` — which the tons-moved card uses four
/// times to stay responsive — throws rather than answer one. Measuring by
/// laying out twice needs no intrinsics: pass one reads each card's natural
/// height at its assigned width, pass two hands every card that height as a
/// `minHeight`. Unlike `CrossAxisAlignment.stretch` it never depends on the
/// parent's height, so it is safe inside a scroll view.
///
/// **A floor, not a tight height, and that is load-bearing twice over.** Fully
/// tight constraints make each child its own relayout boundary, so a change
/// that only alters content — the console's text-scale slider is the one that
/// bites — re-lays the card against the *stale* height and it overflows, with
/// this row never asked to measure again. A floor leaves the height loose, so
/// the child is no boundary and any dirt inside it reaches [performLayout].
/// It also cannot squash: a card handed a minimum can only grow.
///
/// Widths come from [OvFlexRow]'s flex maths and are positional — `widths[i]`
/// belongs to `children[i]`.
class _EqualHeightRow extends MultiChildRenderObjectWidget {
  const _EqualHeightRow({
    required this.widths,
    required this.gap,
    required super.children,
  });

  final List<double> widths;
  final double gap;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderEqualHeightRow(widths: widths, gap: gap);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderEqualHeightRow renderObject,
  ) {
    renderObject
      ..widths = widths
      ..gap = gap;
  }
}

class _EqualHeightParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderEqualHeightRow extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EqualHeightParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EqualHeightParentData> {
  _RenderEqualHeightRow({required List<double> widths, required double gap})
      : _widths = widths,
        _gap = gap;

  List<double> _widths;
  set widths(List<double> value) {
    if (listEquals(_widths, value)) return;
    _widths = value;
    markNeedsLayout();
  }

  double _gap;
  set gap(double value) {
    if (_gap == value) return;
    _gap = value;
    markNeedsLayout();
  }

  double _widthAt(int i) => i < _widths.length ? _widths[i] : 0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EqualHeightParentData) {
      child.parentData = _EqualHeightParentData();
    }
  }

  @override
  void performLayout() {
    if (childCount == 0) {
      size = constraints.smallest;
      return;
    }

    // Pass one — natural height at the assigned width.
    var tallest = 0.0;
    var i = 0;
    var child = firstChild;
    while (child != null) {
      child.layout(
        BoxConstraints.tightFor(width: _widthAt(i)),
        parentUsesSize: true,
      );
      if (child.size.height > tallest) tallest = child.size.height;
      child = childAfter(child);
      i++;
    }

    // Pass two — everyone to the tallest. A card that was already the tallest
    // measures the same again, so only the short ones move.
    var x = 0.0;
    i = 0;
    child = firstChild;
    while (child != null) {
      final w = _widthAt(i);
      child.layout(
        BoxConstraints(minWidth: w, maxWidth: w, minHeight: tallest),
        parentUsesSize: true,
      );
      if (child.size.height > tallest) tallest = child.size.height;
      (child.parentData! as _EqualHeightParentData).offset = Offset(x, 0);
      x += w + _gap;
      child = childAfter(child);
      i++;
    }

    size = constraints.constrain(Size(x - _gap, tallest));
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}

/// A fixed-column grid that keeps its cells equal width and wraps to fewer
/// columns when the cells would be too narrow to hold their own text.
class OvCellGrid extends StatelessWidget {
  const OvCellGrid({
    super.key,
    required this.cells,
    required this.columns,
    required this.narrowColumns,
    required this.narrowBelow,
    this.gap = 14,
    this.rowGap = 14,
  });

  final List<Widget> cells;
  final int columns;
  final int narrowColumns;
  final double narrowBelow;
  final double gap;
  final double rowGap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth < narrowBelow ? narrowColumns : columns;
          final rows = (cells.length / cols).ceil();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rows; r++) ...[
                if (r > 0) SizedBox(height: rowGap),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < cols; i++) ...[
                      if (i > 0) SizedBox(width: gap),
                      Expanded(
                        child: r * cols + i < cells.length
                            ? cells[r * cols + i]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      );
}
