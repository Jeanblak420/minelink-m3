import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';

void main() {
  const headers = [
    'REFERENCE',
    'TRUCK REGISTRATION NO',
    'PRODUCT',
    'SOURCE',
    'CUSTOMER',
    'TRANSPORTER',
    'MINE NET (t)',
    'DELIVERED (t)',
    'VARIANCE (t)',
    'STATUS',
  ];
  final rows = [
    ['TRP-1', 'KVK007MP', 'Chrome Ore', 'Iron Hills', 'Atlas', 'Roadhaul',
        '35.00', '34.80', '0.20', 'completed'],
    ['TRP-2', 'ABC123', 'Chrome Ore', 'Iron Hills', 'Atlas', 'Roadhaul',
        '40.00', '39.50', '0.50', 'completed'],
  ];

  test('Excel export has exactly one sheet, a header, and live SUM totals', () {
    final bytes = ReconExporter.buildExcel(
      'Reconciliations — Side B (reconciled)',
      headers,
      rows,
      summary: {'Loaded (mine net)': '75.00 t', 'Delivered': '74.30 t'},
    );

    final decoded = Excel.decodeBytes(bytes);
    // Exactly one sheet — the default "Sheet1" must be gone.
    expect(decoded.tables.keys.length, 1);
    expect(decoded.tables.keys.first, isNot('Sheet1'));

    // Find the header row and a SUM formula somewhere in the sheet.
    final sheet = decoded.tables.values.first;
    var foundHeader = false;
    var foundSum = false;
    for (final row in sheet.rows) {
      for (final cell in row) {
        final v = cell?.value;
        if (v is TextCellValue && v.value.toString() == 'REFERENCE') {
          foundHeader = true;
        }
        if (v is FormulaCellValue && v.formula.startsWith('=SUM(')) {
          foundSum = true;
        }
      }
    }
    expect(foundHeader, isTrue, reason: 'header row present');
    expect(foundSum, isTrue, reason: 'auto-sum formula present');
  });

  test('no numeric columns → no crash, still one sheet', () {
    final bytes = ReconExporter.buildExcel('T', ['A', 'B'], [
      ['x', 'y'],
    ]);
    final decoded = Excel.decodeBytes(bytes);
    expect(decoded.tables.keys.length, 1);
  });
}
