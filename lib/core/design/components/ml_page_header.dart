import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

export 'package:flutter_application_1/core/design/components/ml_meta.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';


/// The title block every portal screen opens with.
///
/// All 36 portal screens hand-rolled this:
///
/// ```dart
/// Text(title, style: Theme.of(context).textTheme.headlineSmall
///     ?.copyWith(fontWeight: FontWeight.w800)),
/// const SizedBox(height: 4),
/// Text(description, ...),
/// ```
///
/// Three things follow from copying it rather than sharing it.
///
/// 1. **It is in the wrong face.** `docs/design-reference.md` §3 puts titles in
///    Fraunces, and the console renders them that way. Thirty-six screens in
///    PlusJakartaSans ExtraBold is the portal speaking a different type
///    language from the surface the client designated as the reference.
/// 2. **There was nowhere to put a meta line.** S5-22 requires one on every
///    migrated screen, plus a `View →` / filter / export affordance where the
///    screen has one. A bare `Text` has no slot for either, so the gate could
///    not be satisfied without changing the shape.
/// 3. **A rule applied by hand 36 times holds in 34 places.** That is what
///    S5-13 and S5-17 exist to stop.
///
/// [actions] sit on the right of the title row and wrap under it when the row
/// runs out of width, which on a 360px phone at text scale 1.3 it does. They
/// are laid out in a [Wrap] rather than a `Row` deliberately — CLAUDE.md §10.4
/// records that an unflexed `Wrap` inside a `Row` is measured against
/// unbounded width and pushes the row over, so the title and the actions are
/// siblings in one `Wrap`, not a `Row` containing one.
///
/// Pinned by `test/widgets/portal_page_header_test.dart`.
class MlPageHeader extends StatelessWidget {
  const MlPageHeader({
    super.key,
    required this.title,
    this.description,
    this.meta,
    this.actions = const [],
    this.padding = const EdgeInsets.only(bottom: 18),
  });

  final String title;

  /// One calm sentence saying what the screen is for. Kept to the body face —
  /// the reference reserves the display face for titles and numerals.
  final String? description;

  /// Right-aligned context: `Last 24h · 14 loads`, `Updated 2 minutes ago`.
  /// This is the meta line S5-22 asks for.
  final String? meta;

  /// Screen-level actions — export, record, refresh.
  final List<Widget> actions;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final glass = MlGlass.of(context);

    final titleText = Text(
      title,
      style: context.mlText.editorialLarge.copyWith(
        color: semantic.textStrong,
        fontWeight: FontWeight.w400,
      ),
    );

    final tools = <Widget>[
      if (meta != null)
        Text(
          meta!,
          style: context.mlText.labelSmall.copyWith(
            color: glass.inkLo,
            fontWeight: FontWeight.w400,
          ),
        ),
      ...actions,
    ];

    final descriptionText = description == null
        ? null
        : Text(
            description!,
            style: context.mlText.bodyMedium.copyWith(
              color: semantic.textMuted,
            ),
          );

    return Padding(
      padding: padding,
      child: _HeaderLayout(
        title: titleText,
        description: descriptionText,
        tools: tools.isEmpty
            ? null
            : Wrap(
                // Right-aligned whether the tools sit beside the title or
                // under it — `_HeaderLayout` hands this block the full width
                // when it stacks, so `end` has room to work in.
                alignment: WrapAlignment.end,
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: tools,
              ),
      ),
    );
  }
}

/// Title · description · tools, laid out by FIT rather than by width.
///
/// The header used to be one `Wrap` of [title, tools]. A Wrap that has to
/// wrap starts its second run at the LEFT, so on a 412px phone "4 vehicles
/// costed ⟳ [Log cost]" sat under the title at the left edge, "[Log fuel]"
/// on a third line ending at x=297 of 396, and the description then followed
/// BELOW the buttons, separated from its own title. Right-aligned on desktop,
/// left on a phone — the console pass's class 2, product-wide, found by two
/// reviewers on 2026-08-23.
///
/// A width floor is the wrong rule: "9 entries · Export" fits beside "Audit
/// logs" on a phone, and stacking it by width cost every such header a line
/// (tried, measured on 43 goldens, reverted). So this measures. Both blocks
/// are laid out loose; if `title + gap + tools` fits in the width they share
/// one row (title left, tools right, centred on each other) with the
/// description under; otherwise title, description, then the tools on their
/// own full-width row flush right.
class _HeaderLayout extends MultiChildRenderObjectWidget {
  _HeaderLayout({
    required Widget title,
    Widget? description,
    Widget? tools,
  }) : super(children: [
          _Slot(slot: _HeaderSlot.title, child: title),
          if (description != null)
            _Slot(slot: _HeaderSlot.description, child: description),
          if (tools != null) _Slot(slot: _HeaderSlot.tools, child: tools),
        ]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeaderLayout();
}

enum _HeaderSlot { title, description, tools }

class _HeaderParentData extends ContainerBoxParentData<RenderBox> {
  _HeaderSlot slot = _HeaderSlot.title;
}

class _Slot extends ParentDataWidget<_HeaderParentData> {
  const _Slot({required this.slot, required super.child});
  final _HeaderSlot slot;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _HeaderParentData;
    if (data.slot != slot) {
      data.slot = slot;
      final parent = renderObject.parent;
      if (parent is RenderObject) parent.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => _HeaderLayout;
}

class _RenderHeaderLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeaderParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeaderParentData> {
  /// Between the title and the tools when they share a row.
  static const double _gap = 12;

  /// Between the title and the description.
  static const double _descriptionGap = 4;

  /// Above the tools when they have their own row.
  static const double _stackGap = 10;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeaderParentData) {
      child.parentData = _HeaderParentData();
    }
  }

  RenderBox? _child(_HeaderSlot slot) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _HeaderParentData;
      if (data.slot == slot) return child;
      child = data.nextSibling;
    }
    return null;
  }

  @override
  void performLayout() {
    final title = _child(_HeaderSlot.title)!;
    final description = _child(_HeaderSlot.description);
    final tools = _child(_HeaderSlot.tools);
    final maxWidth = constraints.maxWidth;
    final loose = BoxConstraints(maxWidth: maxWidth);

    title.layout(loose, parentUsesSize: true);
    tools?.layout(loose, parentUsesSize: true);

    final fits = tools == null ||
        !maxWidth.isFinite ||
        title.size.width + _gap + tools.size.width <= maxWidth;

    var y = 0.0;
    if (fits) {
      // One row: title left, tools right, centred on each other.
      final rowHeight = math.max(title.size.height, tools?.size.height ?? 0);
      _place(title, Offset(0, (rowHeight - title.size.height) / 2));
      if (tools != null) {
        _place(
          tools,
          Offset(
            maxWidth.isFinite ? maxWidth - tools.size.width : title.size.width + _gap,
            (rowHeight - tools.size.height) / 2,
          ),
        );
      }
      y = rowHeight;
      if (description != null) {
        description.layout(loose, parentUsesSize: true);
        y += _descriptionGap;
        _place(description, Offset(0, y));
        y += description.size.height;
      }
    } else {
      _place(title, Offset.zero);
      y = title.size.height;
      if (description != null) {
        description.layout(loose, parentUsesSize: true);
        y += _descriptionGap;
        _place(description, Offset(0, y));
        y += description.size.height;
      }
      // The tools get the whole width, so their `WrapAlignment.end` works.
      tools.layout(BoxConstraints.tightFor(width: maxWidth).copyWith(
        minHeight: 0,
        maxHeight: double.infinity,
      ), parentUsesSize: true);
      y += _stackGap;
      _place(tools, Offset(0, y));
      y += tools.size.height;
    }

    final width = maxWidth.isFinite
        ? maxWidth
        : [
            title.size.width + (tools == null ? 0 : _gap + tools.size.width),
            description?.size.width ?? 0,
          ].reduce(math.max);
    size = constraints.constrain(Size(width, y));
  }

  void _place(RenderBox child, Offset offset) {
    (child.parentData! as _HeaderParentData).offset = offset;
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  double computeMinIntrinsicWidth(double height) {
    var w = 0.0;
    var child = firstChild;
    while (child != null) {
      w = math.max(w, child.getMinIntrinsicWidth(height));
      child = (child.parentData! as _HeaderParentData).nextSibling;
    }
    return w;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    final title = _child(_HeaderSlot.title)!.getMaxIntrinsicWidth(height);
    final tools = _child(_HeaderSlot.tools)?.getMaxIntrinsicWidth(height) ?? 0;
    final description =
        _child(_HeaderSlot.description)?.getMaxIntrinsicWidth(height) ?? 0;
    return math.max(title + (tools == 0 ? 0 : _gap + tools), description);
  }
}
