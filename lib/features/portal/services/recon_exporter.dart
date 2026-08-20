import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:convert';

import 'package:excel/excel.dart';
// Excel and Material both export `Border`/`BorderStyle`; this file styles Excel
// cell borders, so hide Material's (it uses `BorderSide`/`RoundedRectangleBorder`
// here, not the bare names).
import 'package:flutter/material.dart' hide Border, BorderStyle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:flutter_application_1/core/utils/file_save.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// Reconciliation export formats (CLAUDE.md §4: Excel + CSV + PDF).
enum ReconExportFormat { csv, excel, pdf }

/// Generic styled table exporter for the reconciliation views (Side A raw and
/// Side B reconciled). Builds the file, then saves it via a real native
/// "Save As" dialog on desktop (choose folder + filename) — see
/// [saveBytesToDevice].
class ReconExporter {
  /// Bottom-sheet format picker, then export + share.
  ///
  /// [filters] mirrors the on-screen filter selections (e.g. `Transporter:
  /// All`, `Product: All`) and [summary] the period/stat headers shown above
  /// the table (e.g. `Total: 35.00 t`) — both are rendered as labelled blocks
  /// at the top of the export so the file reads exactly like the app view.
  static Future<void> pickFormatAndExport(
    BuildContext context, {
    required String title,
    required String filenameBase,
    required List<String> headers,
    required List<List<String>> rows,
    Map<String, String> filters = const {},
    Map<String, String> summary = const {},
    Set<int> noTotalColumns = const {},
  }) async {
    if (rows.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Nothing to export yet.')));
      return;
    }

    final format = await showModalBottomSheet<ReconExportFormat>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MlShape.largeIncreased)),
      ),
      builder: (ctx) => _FormatSheet(rowCount: rows.length),
    );
    if (format == null || !context.mounted) return;

    await exportAndSave(
      context,
      title: title,
      filenameBase: filenameBase,
      headers: headers,
      rows: rows,
      format: format,
      filters: filters,
      summary: summary,
      noTotalColumns: noTotalColumns,
    );
  }

  /// Builds the file in the chosen [format] and saves it to the user's device
  /// via a native "Save As" dialog (desktop) or the share sheet (mobile).
  static Future<void> exportAndSave(
    BuildContext context, {
    required String title,
    required String filenameBase,
    required List<String> headers,
    required List<List<String>> rows,
    required ReconExportFormat format,
    Map<String, String> filters = const {},
    Map<String, String> summary = const {},
    Set<int> noTotalColumns = const {},
  }) async {
    try {
      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final base = '${filenameBase}_$now';

      List<int> bytes;
      String extension;
      String mimeType;
      String typeLabel;
      switch (format) {
        case ReconExportFormat.csv:
          bytes = utf8.encode(
            buildCsv(headers, rows,
                title: title,
                filters: filters,
                summary: summary,
                noTotalColumns: noTotalColumns),
          );
          extension = 'csv';
          mimeType = 'text/csv';
          typeLabel = 'CSV';
        case ReconExportFormat.excel:
          bytes = buildExcel(title, headers, rows,
              filters: filters,
              summary: summary,
              noTotalColumns: noTotalColumns);
          extension = 'xlsx';
          mimeType =
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          typeLabel = 'Excel spreadsheet';
        case ReconExportFormat.pdf:
          bytes = await buildPdf(title, headers, rows,
              filters: filters,
              summary: summary,
              noTotalColumns: noTotalColumns);
          extension = 'pdf';
          mimeType = 'application/pdf';
          typeLabel = 'PDF document';
      }

      final outcome = await saveBytesToDevice(
        bytes: bytes,
        suggestedName: '$base.$extension',
        mimeType: mimeType,
        typeLabel: typeLabel,
        extension: extension,
      );

      if (outcome == null || !context.mounted) return; // cancelled
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            outcome.shared
                ? 'Exported — choose where to save it.'
                : 'Saved to ${outcome.path}',
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed. ${friendlyError(e)}')));
      }
    }
  }

  // ─── CSV ──────────────────────────────────────────────────

  /// With no [title]/[filters]/[summary] the output is a plain header-first
  /// CSV (unchanged — the two-version round-trip snapshot relies on this). When
  /// any context is supplied, a labelled title/filter/summary block is prefixed
  /// and an auto-summed `TOTAL` row is appended for every numeric column.
  static String buildCsv(
    List<String> headers,
    List<List<String>> rows, {
    String? title,
    Map<String, String> filters = const {},
    Map<String, String> summary = const {},
    Set<int> noTotalColumns = const {},
  }) {
    final buf = StringBuffer();
    final hasContext =
        title != null || filters.isNotEmpty || summary.isNotEmpty;

    if (hasContext) {
      if (title != null) buf.writeln(_esc(title));
      buf.writeln(
        _esc('Generated ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'
            '  ·  ${rows.length} row(s)'),
      );
      buf.writeln();
      if (filters.isNotEmpty) {
        buf.writeln('Filters');
        filters.forEach((k, v) => buf.writeln('${_esc(k)},${_esc(v)}'));
        buf.writeln();
      }
      if (summary.isNotEmpty) {
        buf.writeln('Summary');
        summary.forEach((k, v) => buf.writeln('${_esc(k)},${_esc(v)}'));
        buf.writeln();
      }
    }

    buf.writeln(headers.map(_esc).join(','));
    for (final row in rows) {
      buf.writeln(row.map(_esc).join(','));
    }

    if (hasContext) {
      final sums = _columnSums(headers.length, rows, noTotal: noTotalColumns);
      if (sums.values.any((v) => v != null)) {
        final cells = [
          for (var c = 0; c < headers.length; c++)
            c == 0
                ? 'TOTAL'
                : (sums[c] != null ? sums[c]!.toStringAsFixed(2) : ''),
        ];
        buf.writeln(cells.map(_esc).join(','));
      }
    }
    return buf.toString();
  }

  /// Per-column running sum for every column that is fully numeric (ignoring
  /// blank / `—` cells); `null` for non-numeric columns.
  ///
  /// [noTotal] opts a column out even when it parses. Not every numeric column
  /// is a quantity: totalling a rate or an average produces a figure that means
  /// nothing — the sum of three transporters' tons-per-trip is not anything —
  /// and a TOTAL row is read as authoritative. Callers name those columns.
  static Map<int, double?> _columnSums(
    int cols,
    List<List<String>> rows, {
    Set<int> noTotal = const {},
  }) {
    final res = <int, double?>{};
    for (var c = 0; c < cols; c++) {
      res[c] = (!noTotal.contains(c) && _isSummable(rows, c))
          ? rows.fold<double>(0, (s, r) {
              if (c >= r.length) return s;
              return s + (double.tryParse(r[c].trim().replaceAll(',', '')) ?? 0);
            })
          : null;
    }
    return res;
  }

  /// A column is summable when it has at least one numeric value and no
  /// non-numeric value (blank / `—` cells are skipped, not disqualifying).
  static bool _isSummable(List<List<String>> rows, int col) {
    var any = false;
    for (final r in rows) {
      if (col >= r.length) continue;
      final v = r[col].trim();
      if (v.isEmpty || v == '—') continue;
      if (double.tryParse(v.replaceAll(',', '')) == null) return false;
      any = true;
    }
    return any;
  }

  /// Excel column letter for a 0-based index (0 → `A`, 26 → `AA`).
  static String _colLetter(int index) {
    var n = index + 1;
    var col = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      col = String.fromCharCode(65 + rem) + col;
      n = (n - 1) ~/ 26;
    }
    return col;
  }

  static String _esc(String f) {
    if (f.contains(',') || f.contains('"') || f.contains('\n')) {
      return '"${f.replaceAll('"', '""')}"';
    }
    return f;
  }

  // ─── Excel ────────────────────────────────────────────────

  static List<int> buildExcel(
    String title,
    List<String> headers,
    List<List<String>> rows, {
    Map<String, String> filters = const {},
    Map<String, String> summary = const {},
    Set<int> noTotalColumns = const {},
  }) {
    final excel = Excel.createExcel();
    final sheetName = title.length > 31 ? title.substring(0, 31) : title;
    final sheet = excel[sheetName];
    // Exactly one sheet: drop the auto-created default "Sheet1" (and any other
    // stray sheet) so the file opens straight onto the data.
    for (final name in excel.tables.keys.toList()) {
      if (name != sheetName) excel.delete(name);
    }
    excel.setDefaultSheet(sheetName);

    final cols = headers.length;
    final lastCol = cols - 1;
    final border = _thinBorder();
    var row = 0;

    void put(int c, int r, CellValue v, CellStyle? style) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
      );
      cell.value = v;
      if (style != null) cell.cellStyle = style;
    }

    // ── Title (merged across the table) ──────────────────────
    put(
      0,
      row,
      TextCellValue(title),
      CellStyle(
        bold: true,
        fontSize: 15,
        fontColorHex: ExcelColor.fromHexString('#0E7490'),
      ),
    );
    if (lastCol > 0) {
      sheet.merge(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
        CellIndex.indexByColumnRow(columnIndex: lastCol, rowIndex: row),
      );
    }
    row++;
    put(
      0,
      row,
      TextCellValue(
        'Generated ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'
        '  ·  ${rows.length} row(s)',
      ),
      CellStyle(
        italic: true,
        fontSize: 9,
        fontColorHex: ExcelColor.fromHexString('#64748B'),
      ),
    );
    row += 2; // trailing blank row

    final labelStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.fromHexString('#334155'),
    );

    // ── Filter / summary context blocks (the "All …" headers) ─
    void block(String heading, Map<String, String> entries) {
      if (entries.isEmpty) return;
      put(
        0,
        row,
        TextCellValue(heading),
        CellStyle(
          bold: true,
          fontColorHex: ExcelColor.fromHexString('#0E7490'),
        ),
      );
      row++;
      entries.forEach((k, v) {
        put(0, row, TextCellValue(k), labelStyle);
        put(1, row, TextCellValue(v), null);
        row++;
      });
      row++; // trailing blank row
    }

    block('Filters', filters);
    block('Summary', summary);

    // ── Header row ───────────────────────────────────────────
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#0E7490'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      textWrapping: TextWrapping.WrapText,
      leftBorder: border,
      rightBorder: border,
      topBorder: border,
      bottomBorder: border,
    );
    final headerRowIndex = row;
    for (var c = 0; c < cols; c++) {
      put(c, row, TextCellValue(headers[c]), headerStyle);
    }
    row++;

    // ── Data rows (bordered, zebra-striped) ──────────────────
    final firstDataRow = row; // 0-based excel row of the first data record
    final sums = _columnSums(cols, rows, noTotal: noTotalColumns);
    for (var r = 0; r < rows.length; r++) {
      final striped = r.isOdd;
      for (var c = 0; c < cols; c++) {
        final numeric = sums[c] != null;
        put(
          c,
          row,
          TextCellValue(c < rows[r].length ? rows[r][c] : ''),
          CellStyle(
            backgroundColorHex: striped
                ? ExcelColor.fromHexString('#F1F5F9')
                : ExcelColor.none,
            horizontalAlign:
                numeric ? HorizontalAlign.Right : HorizontalAlign.Left,
            leftBorder: border,
            rightBorder: border,
            topBorder: border,
            bottomBorder: border,
          ),
        );
      }
      row++;
    }

    // ── Auto-sum TOTAL row (live =SUM formula, any number of rows) ──
    if (rows.isNotEmpty && sums.values.any((v) => v != null)) {
      final lastDataRow = row - 1; // 0-based
      final totalStyle = CellStyle(
        bold: true,
        backgroundColorHex: ExcelColor.fromHexString('#E2E8F0'),
        horizontalAlign: HorizontalAlign.Right,
        leftBorder: border,
        rightBorder: border,
        topBorder: border,
        bottomBorder: border,
      );
      for (var c = 0; c < cols; c++) {
        if (c == 0) {
          put(
            c,
            row,
            TextCellValue('TOTAL'),
            totalStyle.copyWith(horizontalAlignVal: HorizontalAlign.Left),
          );
        } else if (sums[c] != null) {
          // A1 range spans the data block only — Excel recomputes it live no
          // matter how many rows the export holds.
          final colL = _colLetter(c);
          put(
            c,
            row,
            FormulaCellValue(
              '=SUM($colL${firstDataRow + 1}:$colL${lastDataRow + 1})',
            ),
            totalStyle,
          );
        } else {
          put(c, row, TextCellValue(''), totalStyle);
        }
      }
      row++;
    }

    for (var i = 0; i < cols; i++) {
      sheet.setColumnWidth(i, 18);
    }
    // Give the header row height for wrapped labels.
    sheet.setRowHeight(headerRowIndex, 26);
    return excel.encode() ?? [];
  }

  static Border _thinBorder() => Border(
        borderStyle: BorderStyle.Thin,
        borderColorHex: ExcelColor.fromHexString('#CBD5E1'),
      );

  // ─── PDF ─────────────────────────────────────────────────

  static Future<List<int>> buildPdf(
    String title,
    List<String> headers,
    List<List<String>> rows, {
    Map<String, String> filters = const {},
    Map<String, String> summary = const {},
    Set<int> noTotalColumns = const {},
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    const pageSize = 28;
    final pages = (rows.length / pageSize).ceil().clamp(1, 1 << 30);
    final sums = _columnSums(headers.length, rows, noTotal: noTotalColumns);
    final hasTotals = rows.isNotEmpty && sums.values.any((v) => v != null);

    pw.Widget kvBlock(String heading, Map<String, String> entries) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(heading,
                style: pw.TextStyle(
                    font: fontBold, fontSize: 9, color: PdfColors.cyan900)),
            for (final e in entries.entries)
              pw.Text('${e.key}: ${e.value}',
                  style: pw.TextStyle(
                      font: font, fontSize: 8, color: PdfColors.grey800)),
          ],
        );

    for (var p = 0; p < pages; p++) {
      final slice = rows.skip(p * pageSize).take(pageSize).toList();
      final isLast = p == pages - 1;
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: 15,
                  color: PdfColors.cyan900,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}'
                '  |  Page ${p + 1} of $pages  |  ${rows.length} rows',
                style: pw.TextStyle(
                  font: font,
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
              if (p == 0 && (filters.isNotEmpty || summary.isNotEmpty)) ...[
                pw.SizedBox(height: 8),
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (filters.isNotEmpty)
                      pw.Expanded(child: kvBlock('Filters', filters)),
                    if (summary.isNotEmpty)
                      pw.Expanded(child: kvBlock('Summary', summary)),
                  ],
                ),
              ],
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.cyan900, thickness: 1.2),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.cyan900,
                    ),
                    children: [
                      for (final h in headers)
                        _cell(h, fontBold, isHeader: true),
                    ],
                  ),
                  ...slice.asMap().entries.map(
                    (e) => pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: e.key.isEven
                            ? PdfColors.grey50
                            : PdfColors.white,
                      ),
                      children: [for (final v in e.value) _cell(v, font)],
                    ),
                  ),
                  // Auto-summed TOTAL row on the final page (§4 "Total Tons =").
                  if (isLast && hasTotals)
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blueGrey100,
                      ),
                      children: [
                        for (var c = 0; c < headers.length; c++)
                          _cell(
                            c == 0
                                ? 'TOTAL'
                                : (sums[c] != null
                                    ? sums[c]!.toStringAsFixed(2)
                                    : ''),
                            fontBold,
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return doc.save();
  }

  static pw.Widget _cell(String text, pw.Font font, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 7.5 : 7,
          color: isHeader ? PdfColors.white : PdfColors.grey900,
        ),
        maxLines: 3,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }
}

class _FormatSheet extends StatelessWidget {
  final int rowCount;
  const _FormatSheet({required this.rowCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget tile(
      IconData icon,
      Color color,
      String title,
      String subtitle,
      ReconExportFormat format,
    ) {
      return Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(
          borderRadius: MlShape.radiusMedium,
          side: BorderSide(color: cs.outlineVariant),
        ),
        child: ListTile(
          onTap: () => Navigator.pop(context, format),
          leading: CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.12),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: MlShape.radiusExtraSmall,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Export $rowCount row${rowCount == 1 ? '' : 's'}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text('Choose a format, then pick where to save it',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          tile(
            Icons.grid_on_rounded,
            MlTokens.teal700,
            'Excel (.xlsx)',
            'Styled, labelled spreadsheet',
            ReconExportFormat.excel,
          ),
          tile(
            Icons.table_chart_outlined,
            MlTokens.green600,
            'CSV',
            'Plain data for any spreadsheet tool',
            ReconExportFormat.csv,
          ),
          tile(
            Icons.picture_as_pdf_rounded,
            MlTokens.red600,
            'PDF',
            'Printable report with table layout',
            ReconExportFormat.pdf,
          ),
        ],
      ),
    );
  }
}
