import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Column spec for [MlDataTable]. [flex] sizes the column; [width] pins it.
class MlColumn {
  final String label;
  final int flex;
  final double? width;
  final TextAlign align;

  const MlColumn(this.label,
      {this.flex = 1, this.width, this.align = TextAlign.left});
}

/// MineLink list table: UPPERCASE letter-spaced headers, 14px row padding,
/// hairline dividers. Rows are plain widget lists so cells can be plates,
/// badges, or rich two-line identities. Scrolls horizontally when narrower
/// than [minWidth].
class MlDataTable extends StatelessWidget {
  final List<MlColumn> columns;
  final List<List<Widget>> rows;
  final void Function(int index)? onRowTap;
  final double minWidth;

  const MlDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.minWidth = 560,
  });

  Alignment _alignment(TextAlign a) => switch (a) {
        TextAlign.right || TextAlign.end => Alignment.centerRight,
        TextAlign.center => Alignment.center,
        _ => Alignment.centerLeft,
      };

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);

    Widget cell(MlColumn c, Widget child) {
      // A small right gutter keeps a right-aligned column (e.g. numeric "Tons")
      // from butting up against the next column's header/content.
      final aligned = Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Align(alignment: _alignment(c.align), child: child),
      );
      if (c.width != null) return SizedBox(width: c.width, child: aligned);
      return Expanded(flex: c.flex, child: aligned);
    }

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 10),
      child: Row(
        children: [
          for (final c in columns)
            cell(
              c,
              Text(
                c.label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: semantic.textFaint,
                ),
              ),
            ),
        ],
      ),
    );

    final table = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        Container(height: 1, color: semantic.divider),
        for (var i = 0; i < rows.length; i++) ...[
          _MlRow(
            onTap: onRowTap == null ? null : () => onRowTap!(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
              child: Row(
                children: [
                  for (var c = 0; c < columns.length; c++)
                    cell(columns[c],
                        c < rows[i].length ? rows[i][c] : const SizedBox()),
                ],
              ),
            ),
          ),
          if (i < rows.length - 1)
            Container(height: 1, color: semantic.divider),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= minWidth) return table;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(width: minWidth, child: table),
        );
      },
    );
  }
}

class _MlRow extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _MlRow({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: MlTokens.accent.withValues(alpha: 0.04),
        child: child,
      ),
    );
  }
}
