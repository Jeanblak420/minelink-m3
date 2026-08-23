import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// THE HEADER LAYOUT, SHARED BY THE TWO HEADERS THAT NEED IT.
///
/// It was private to `ml_page_header.dart` until 2026-08-23, when the buyer
/// pass found the SAME fault in `SaSectionHeader` — the dashboard band head
/// used by every portal and the console. That one stacked on a WIDTH rule
/// (`maxWidth < 560`) into a plain `Wrap`, so the buyer dashboard's "Invoice
/// cover" band — a 497px column on a 1600px screen, where `Invoice cover` and
/// `View →` fit on one line with room to spare — spent a line stacking them,
/// and put the action at the LEFT edge while its neighbour's sat at the right.
///
/// Rather than write the measurement a second time, it moved here.

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
class MlHeaderLayout extends MultiChildRenderObjectWidget {
  MlHeaderLayout({
    super.key,
    required Widget title,
    Widget? description,
    Widget? tools,
  }) : super(children: [
          _Slot(slot: MlHeaderSlot.title, child: title),
          if (description != null)
            _Slot(slot: MlHeaderSlot.description, child: description),
          if (tools != null) _Slot(slot: MlHeaderSlot.tools, child: tools),
        ]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderHeaderLayout();
}

enum MlHeaderSlot { title, description, tools }

class _HeaderParentData extends ContainerBoxParentData<RenderBox> {
  MlHeaderSlot slot = MlHeaderSlot.title;
}

class _Slot extends ParentDataWidget<_HeaderParentData> {
  const _Slot({required this.slot, required super.child});
  final MlHeaderSlot slot;

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
  Type get debugTypicalAncestorWidgetClass => MlHeaderLayout;
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

  RenderBox? _child(MlHeaderSlot slot) {
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
    final title = _child(MlHeaderSlot.title)!;
    final description = _child(MlHeaderSlot.description);
    final tools = _child(MlHeaderSlot.tools);
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
    final title = _child(MlHeaderSlot.title)!.getMaxIntrinsicWidth(height);
    final tools = _child(MlHeaderSlot.tools)?.getMaxIntrinsicWidth(height) ?? 0;
    final description =
        _child(MlHeaderSlot.description)?.getMaxIntrinsicWidth(height) ?? 0;
    return math.max(title + (tools == 0 ? 0 : _gap + tools), description);
  }
}
