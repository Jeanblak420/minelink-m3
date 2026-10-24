import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_application_1/core/utils/file_save.dart';
import '../data/models/models.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/core/utils/ml_count.dart';

/// Supported export formats for audit logs
enum ExportFormat { csv, pdf, excel, json }

/// Unified export utility for audit logs — CSV, PDF, Excel, JSON
class AuditLogExporter {
  // ─── Shared field definitions ──────────────────────────────
  static const _headers = [
    'Date', 'Time', 'Actor Email', 'Actor Role',
    'Action Type', 'Target Type', 'Target Name',
    'Organization', 'Org Type', 'Description',
  ];

  static List<String> _rowFor(AuditLog log) {
    final dt = MlTime.sast(log.createdAt);
    final dateFmt = DateFormat('yyyy-MM-dd');
    final timeFmt = DateFormat('HH:mm:ss');
    return [
      dateFmt.format(dt),
      timeFmt.format(dt),
      log.actorEmail,
      log.actorPlatformRole,
      log.actionType,
      log.targetType,
      log.targetName ?? '',
      log.organizationName ?? '',
      log.organizationType ?? '',
      log.description,
    ];
  }

  // ─── Public entry point ────────────────────────────────────

  /// Shows a bottom-sheet format picker then exports and shares.
  static Future<void> pickFormatAndExport(
    BuildContext context,
    List<AuditLog> logs, {
    String filenameBase = 'audit_logs',
  }) async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audit logs to export.')),
      );
      return;
    }

    final format = await showModalBottomSheet<ExportFormat>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MlShape.largeIncreased)),
      ),
      builder: (ctx) => _FormatPickerSheet(logCount: logs.length),
    );

    if (format == null || !context.mounted) return;

    await exportAndShare(context, logs, format: format, filenameBase: filenameBase);
  }

  /// Directly export in a given format and share.
  static Future<void> exportAndShare(
    BuildContext context,
    List<AuditLog> logs, {
    ExportFormat format = ExportFormat.csv,
    String filenameBase = 'audit_logs',
    String? filename,
  }) async {
    if (logs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audit logs to export.')),
      );
      return;
    }

    // Show loading snackbar
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: MlTokens.inkOnFill)),
            const SizedBox(width: 12),
            Text('Preparing ${format.name.toUpperCase()} export…'),
          ]),
          duration: const Duration(seconds: 10),
        ),
      );
    }

    try {
      // `MlTime.now()`: the file is NAMED for the day it was exported and a
      // mine keeps it, so on a laptop left on UTC it carried the previous
      // day's name between midnight and 02:00 SAST. Formatting a wall clock,
      // so no second conversion.
      final now = DateFormat('yyyyMMdd_HHmmss').format(MlTime.now());
      final base = filename ?? '${filenameBase}_$now';

      List<int> bytes;
      String extension;
      String mimeType;
      String typeLabel;

      switch (format) {
        case ExportFormat.csv:
          bytes = utf8.encode(_buildCsv(logs));
          extension = 'csv';
          mimeType = 'text/csv';
          typeLabel = 'CSV';
        case ExportFormat.pdf:
          bytes = await _buildPdf(logs);
          extension = 'pdf';
          mimeType = 'application/pdf';
          typeLabel = 'PDF document';
        case ExportFormat.excel:
          bytes = _buildExcel(logs);
          extension = 'xlsx';
          mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
          typeLabel = 'Excel spreadsheet';
        case ExportFormat.json:
          bytes = utf8.encode(_buildJson(logs));
          extension = 'json';
          mimeType = 'application/json';
          typeLabel = 'JSON';
      }

      final outcome = await saveBytesToDevice(
        bytes: bytes,
        suggestedName: '$base.$extension',
        mimeType: mimeType,
        typeLabel: typeLabel,
        extension: extension,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
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
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed. ${friendlyError(e)}'), backgroundColor: MlTokens.red600),
        );
      }
    }
  }

  // ─── CSV ──────────────────────────────────────────────────

  static String _buildCsv(List<AuditLog> logs) {
    final buf = StringBuffer();
    buf.writeln(_headers.map(_esc).join(','));
    for (final log in logs) {
      buf.writeln(_rowFor(log).map(_esc).join(','));
    }
    return buf.toString();
  }

  static String _esc(String f) {
    if (f.contains(',') || f.contains('"') || f.contains('\n')) {
      return '"${f.replaceAll('"', '""')}"';
    }
    return f;
  }

  // ─── JSON ─────────────────────────────────────────────────

  static String _buildJson(List<AuditLog> logs) {
    final list = logs.map((log) => {
      'date': log.createdAt.toIso8601String(),
      'actorEmail': log.actorEmail,
      'actorPlatformRole': log.actorPlatformRole,
      'actionType': log.actionType,
      'targetType': log.targetType,
      'targetName': log.targetName,
      'organizationName': log.organizationName,
      'organizationType': log.organizationType,
      'description': log.description,
      'beforeData': log.beforeData,
      'afterData': log.afterData,
    }).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  // ─── Excel ────────────────────────────────────────────────

  static List<int> _buildExcel(List<AuditLog> logs) {
    final excel = Excel.createExcel();
    final sheet = excel['Audit Logs'];

    // Header row with bold style
    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#1565C0'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );
    for (var i = 0; i < _headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
      cell.value = TextCellValue(_headers[i]);
      cell.cellStyle = headerStyle;
    }

    // Data rows
    for (var r = 0; r < logs.length; r++) {
      final row = _rowFor(logs[r]);
      for (var c = 0; c < row.length; c++) {
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1))
          .value = TextCellValue(row[c]);
      }
    }

    // Auto-width hint (Excel pkg doesn't resize, but set column widths manually)
    for (var i = 0; i < _headers.length; i++) {
      sheet.setColumnWidth(i, 20);
    }

    final bytes = excel.encode();
    return bytes ?? [];
  }

  // ─── PDF ─────────────────────────────────────────────────

  static Future<List<int>> _buildPdf(List<AuditLog> logs) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();

    // Chunk logs into pages of 30 rows each
    const pageSize = 30;
    final pages = (logs.length / pageSize).ceil();

    for (var p = 0; p < pages; p++) {
      final slice = logs.skip(p * pageSize).take(pageSize).toList();
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(16),
          build: (ctx) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Title
              pw.Text(
                'MineLink Platform Audit Log Export',
                style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue900),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Generated: ${MlTime.stamp(MlTime.instant())}  |  Page ${p + 1} of $pages  |  Total: ${mlCount(logs.length, 'entry', 'entries')}',
                style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
              ),
              pw.SizedBox(height: 8),
              pw.Divider(color: PdfColors.blue900, thickness: 1.5),
              pw.SizedBox(height: 8),
              // Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                columnWidths: {
                  0: const pw.FixedColumnWidth(70),
                  1: const pw.FixedColumnWidth(90),
                  2: const pw.FlexColumnWidth(1),
                  3: const pw.FixedColumnWidth(70),
                  4: const pw.FixedColumnWidth(70),
                  5: const pw.FlexColumnWidth(1.5),
                },
                children: [
                  // Header
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                    children: [
                      _pdfCell('Date/Time', fontBold, isHeader: true),
                      _pdfCell('Actor', fontBold, isHeader: true),
                      _pdfCell('Action', fontBold, isHeader: true),
                      _pdfCell('Target', fontBold, isHeader: true),
                      _pdfCell('Organization', fontBold, isHeader: true),
                      _pdfCell('Description', fontBold, isHeader: true),
                    ],
                  ),
                  // Rows
                  ...slice.asMap().entries.map((e) {
                    final log = e.value;
                    final isEven = e.key % 2 == 0;
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: isEven ? PdfColors.grey50 : PdfColors.white,
                      ),
                      children: [
                        _pdfCell(MlTime.stamp(log.createdAt), font),
                        _pdfCell(log.actorEmail, font),
                        _pdfCell(log.actionType.replaceAll('_', ' '), font),
                        _pdfCell(log.targetType, font),
                        _pdfCell(log.organizationName ?? '-', font),
                        _pdfCell(log.description, font),
                      ],
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return doc.save();
  }

  static pw.Widget _pdfCell(String text, pw.Font font, {bool isHeader = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 8 : 7,
          color: isHeader ? PdfColors.white : PdfColors.grey900,
        ),
        maxLines: 3,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }

  /// Export token history as CSV and save it to the user's device.
  static Future<void> shareTokenHistoryCsv(
    BuildContext context, {
    required List<dynamic> tokens,
    required String orgName,
  }) async {
    try {
      // Same rule as the export filename above — the day this history was
      // pulled is a South African day, not the reader's device's.
      final now = MlTime.now();
      final buf = StringBuffer();
      buf.writeln('Token History for $orgName — Generated ${MlTime.stamp(now)}');
      buf.writeln('Preview,Valid Days,Seat Limit,Status,Created At,Expires At,Revoked At,Revoke Reason');
      for (final t in tokens) {
        final row = [
          t.tokenPreview as String? ?? '',
          '${t.validDays}',
          '${t.seatLimit}',
          t.status as String? ?? '',
          MlTime.sast(t.createdAt as DateTime).toString(),
          t.expiresAt != null ? MlTime.sast(t.expiresAt as DateTime).toString() : 'N/A',
          t.revokedAt != null ? MlTime.sast(t.revokedAt as DateTime).toString() : 'N/A',
          t.revokeReason as String? ?? '',
        ].map(_esc).join(',');
        buf.writeln(row);
      }
      final fname = 'token_history_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
      final outcome = await saveBytesToDevice(
        bytes: utf8.encode(buf.toString()),
        suggestedName: fname,
        mimeType: 'text/csv',
        typeLabel: 'CSV',
        extension: 'csv',
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed. ${friendlyError(e)}'), backgroundColor: MlTokens.red600),
        );
      }
    }
  }
}

// ─── Format Picker Bottom Sheet ───────────────────────────────

class _FormatPickerSheet extends StatelessWidget {
  final int logCount;
  const _FormatPickerSheet({required this.logCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: MlShape.radiusExtraSmall),
            ),
          ),
          const SizedBox(height: 16),
          Text('Export $logCount Audit Log${logCount > 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Choose export format', style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 20),
          _FormatTile(
            icon: Icons.table_chart_outlined,
            color: MlTokens.green600,
            title: 'CSV',
            subtitle: 'Comma-separated — best for spreadsheets',
            onTap: () => Navigator.pop(context, ExportFormat.csv),
          ),
          _FormatTile(
            icon: Icons.picture_as_pdf_rounded,
            color: MlTokens.red600,
            title: 'PDF',
            subtitle: 'Printable report with table layout',
            onTap: () => Navigator.pop(context, ExportFormat.pdf),
          ),
          _FormatTile(
            icon: Icons.grid_on_rounded,
            color: MlTokens.teal700,
            title: 'Excel (.xlsx)',
            subtitle: 'Styled spreadsheet for Excel / Sheets',
            onTap: () => Navigator.pop(context, ExportFormat.excel),
          ),
          _FormatTile(
            icon: Icons.data_object_rounded,
            color: MlTokens.orange500,
            title: 'JSON',
            subtitle: 'Raw data for developer/integration use',
            onTap: () => Navigator.pop(context, ExportFormat.json),
          ),
        ],
      ),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _FormatTile({
    required this.icon, required this.color, required this.title,
    required this.subtitle, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: MlShape.radiusMedium,
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

// Legacy compat alias — existing call sites using AuditLogCsvExporter.exportAndShare still work
class AuditLogCsvExporter {
  static Future<void> exportAndShare(
    BuildContext context,
    List<AuditLog> logs, {
    String? filename,
  }) =>
      AuditLogExporter.exportAndShare(
        context,
        logs,
        format: ExportFormat.csv,
        filename: filename,
      );

  static String buildCsvString(List<AuditLog> logs) => AuditLogExporter._buildCsv(logs);
}
