import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/components/ml_wide_table.dart';
import 'package:flutter_application_1/core/design/shell/ml_window_class.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Column spec for [MlDataTable]. [flex] sizes the column; [width] pins it.
class MlColumn {
  final String label;
  final int flex;
  final double? width;
  final TextAlign align;

  /// The narrowest this column's CONTENT can be drawn at.
  ///
  /// Flex weights say how the space is shared; they say nothing about how much
  /// space there has to be. A cell holding an [MlPlatePill] is the case that
  /// makes the difference matter: a South African registration is 114px of pill
  /// at the table's font size, the pill is unflexed inside its cell's `Row`, and
  /// a `Row` hands a non-flex child UNBOUNDED width — so a 90px column does not
  /// squeeze it, it overflows behind it (CLAUDE.md §10.4).
  ///
  /// Measured 2026-08-20 on `screen-recon-tables-phone-dark` and
  /// `screen-buyer-reconciliations-phone-dark`: 24px and 35px of overflow, in
  /// two different tables, both on the truck column.
  ///
  /// Setting this makes [MlDataTable] widen its scroll minimum until this
  /// column gets what it needs, so the table SCROLLS rather than compresses.
  /// Use [kPlateColumnMinWidth] for a column that carries a plate.
  final double? minWidth;

  const MlColumn(this.label,
      {this.flex = 1,
      this.width,
      this.align = TextAlign.left,
      this.minWidth});
}

/// What a table column needs to hold an [MlPlatePill] without overflowing.
///
/// A plate is `CK 84 RT GP` — eleven monospace characters at 0.8 letter-spacing
/// plus 8px of pill padding each side and a 1px border. Measured rather than
/// estimated, and named rather than repeated: seven tables in `lib/` put a plate
/// in a cell, and the number was wrong in at least two of them.
const double kPlateColumnMinWidth = 120;

/// MineLink list table: UPPERCASE letter-spaced headers, 14px row padding,
/// hairline dividers. Rows are plain widget lists so cells can be plates,
/// badges, or rich two-line identities. Scrolls horizontally when narrower
/// than [minWidth].
class MlDataTable extends StatelessWidget {
  final List<MlColumn> columns;
  final List<List<Widget>> rows;
  final void Function(int index)? onRowTap;
  final double minWidth;

  /// On a phone, one card per row — every column as a label beside its
  /// value — instead of a table to swipe sideways.
  ///
  /// Opt-in. The admin panel's tables on a 360dp phone broke their headers
  /// mid-word ("ROUT / E ID", "PRODU / CT"), cut every cell, and hid the
  /// columns that matter behind a sideways scroll (admin phone audit,
  /// 2026-10-24). Windows wider than a phone are untouched.
  final bool cardsOnPhone;

  const MlDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.minWidth = 560,
    this.cardsOnPhone = false,
  });

  Alignment _alignment(TextAlign a) => switch (a) {
        TextAlign.right || TextAlign.end => Alignment.centerRight,
        TextAlign.center => Alignment.center,
        _ => Alignment.centerLeft,
      };

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    if (cardsOnPhone && MlWindowClass.of(context).usesBottomNav) {
      return _cards(context, semantic);
    }

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
                // TWO lines. A header is two or three short words and the
                // column is sized for its DATA, not for its label — so at one
                // line the margin ledger read "YOUR CUT / T…", "TRANSPORTE…"
                // and "MARGIN EAR…", which between them name the three figures
                // the platform's whole commercial model is made of.
                //
                // Wrapping at the space or the slash costs a line of chrome and
                // keeps the words. The column still has to be wide enough for
                // the widest single WORD — declare `MlColumn.minWidth` when the
                // data is wider than that.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.overline.copyWith(
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

    // MlWideTable, not a bare SingleChildScrollView: a horizontal scroll view
    // draws no scrollbar unless one is asked for, so a table narrower than its
    // columns showed a last column cut off mid-word with nothing to say the
    // rest was reachable.
    return MlWideTable(
      minWidth: _effectiveMinWidth(MediaQuery.textScalerOf(context)),
      child: table,
    );
  }

  /// The phone layout behind [cardsOnPhone]: a block per row, a line per
  /// column, label beside value.
  ///
  /// The label column is as wide as the WIDEST label, capped at 45% of the
  /// card, rather than a fixed two-fifths. The fixed share broke a long
  /// one-word label mid-word: "TRANSPORTER / S" on the S25 at its 1.3 text
  /// size (2026-10-24). Multi-word labels wrap between words. When even the
  /// longest single WORD of a label cannot fit that 45% — a narrow phone at a
  /// large text size — every card of the table stacks instead: the label on
  /// its own line, the value under it, so no word is ever split.
  Widget _cards(BuildContext context, MlSemantic semantic) {
    final labelStyle = context.mlText.overline.copyWith(
      color: semantic.textFaint,
    );
    final scaler = MediaQuery.textScalerOf(context);
    final labels = [for (final c in columns) c.label.toUpperCase()];
    var widestWord = 0.0;
    for (final l in labels) {
      for (final w in l.split(' ')) {
        final p = TextPainter(
          text: TextSpan(text: w, style: labelStyle),
          textScaler: scaler,
          textDirection: TextDirection.ltr,
        )..layout();
        if (p.width > widestWord) widestWord = p.width;
        p.dispose();
      }
    }

    Widget value(int i, int c) => Align(
          alignment: Alignment.centerLeft,
          child: c < rows[i].length ? rows[i][c] : const SizedBox(),
        );
    Widget label(int c) => Text(
          labels[c],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: labelStyle,
        );

    return LayoutBuilder(builder: (context, box) {
      // 8 of row padding and the label's 12 gutter come out of the 45%.
      final stacked = widestWord + 12 > (box.maxWidth - 8) * 0.45;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            _MlRow(
              onTap: onRowTap == null ? null : () => onRowTap!(i),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                child: stacked
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: 10,
                        children: [
                          for (var c = 0; c < columns.length; c++)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              spacing: 2,
                              children: [label(c), value(i, c)],
                            ),
                        ],
                      )
                    : Table(
                        columnWidths: const {
                          0: MinColumnWidth(IntrinsicColumnWidth(),
                              FractionColumnWidth(0.45)),
                          1: FlexColumnWidth(),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.top,
                        children: [
                          for (var c = 0; c < columns.length; c++)
                            TableRow(
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                      top: 2,
                                      right: 12,
                                      bottom:
                                          c < columns.length - 1 ? 8 : 0),
                                  child: label(c),
                                ),
                                Padding(
                                  padding: EdgeInsets.only(
                                      bottom:
                                          c < columns.length - 1 ? 8 : 0),
                                  child: value(i, c),
                                ),
                              ],
                            ),
                        ],
                      ),
              ),
            ),
            if (i < rows.length - 1)
              Container(height: 1, color: semantic.divider),
          ],
        ],
      );
    });
  }

  /// [minWidth], widened until every column that declared an [MlColumn.minWidth]
  /// actually gets it.
  ///
  /// `minWidth` alone is a guess about the whole table, and a guess about the
  /// whole table cannot know that one flex-3 column in the middle of it has to
  /// hold a 114px plate. Two tables shipped overflowing for exactly that reason.
  /// Declaring the need per column and solving for the total is the same
  /// information, in the place that has it.
  ///
  /// The arithmetic mirrors the layout above: 16px of row padding (8 each side),
  /// a 12px right gutter inside every cell, pinned columns taken off the top,
  /// and the rest shared by flex.
  ///
  /// **[scaler] is not optional decoration.** A declared minimum is a statement
  /// about TEXT, and this console lets every user scale text (0.85–1.3). The
  /// first version of this took `kPlateColumnMinWidth` literally, gave the truck
  /// column exactly 120px, and then overflowed by 18px at scale 1.3 on six
  /// screens at once — a fixed pixel floor under a user-controlled type size,
  /// which is the same fault the bottom navigation bar had. Scaling the whole
  /// figure slightly over-pays for the pill's 18px of chrome; that is the
  /// conservative direction and it costs a few pixels of scroll.
  double _effectiveMinWidth(TextScaler scaler) {
    const rowPadding = 16.0;
    const cellGutter = 12.0;

    var totalFlex = 0;
    var pinned = 0.0;
    for (final c in columns) {
      if (c.width != null) {
        pinned += c.width!;
      } else {
        totalFlex += c.flex;
      }
    }

    var out = minWidth;
    for (final c in columns) {
      if (c.minWidth == null) continue;
      final need = scaler.scale(c.minWidth!) + cellGutter;
      final total = c.width != null
          // A pinned column already owns its width; all this can do is check it.
          ? (need > c.width! ? pinned + need - c.width! + rowPadding : 0.0)
          : (totalFlex == 0 || c.flex == 0
              ? 0.0
              : need * totalFlex / c.flex + pinned + rowPadding);
      if (total > out) out = total;
    }
    return out;
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
