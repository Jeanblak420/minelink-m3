import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/raw_recon_row.dart';
import 'package:flutter_application_1/features/portal/services/recon_exporter.dart';
import 'package:flutter_application_1/features/portal/widgets/raw_recon_view.dart';

void main() {
  group('RawReconRow', () {
    test('parses a full list_raw_recon_rows row', () {
      final r = RawReconRow.fromJson({
        'trip_id': 't-1',
        'trip_date': '2026-07-12T06:30:00Z',
        'time_in': '2026-07-12T06:30:00Z',
        'waybill_number': 'TRP-ABC123',
        'transporter_name': 'Haul Co',
        'truck_reg': 'ABC 123 GP',
        'destination': 'Vanderbijlpark',
        'product': 'Chrome 38/40',
        'source_name': 'Duma Mine',
        'customer_name': 'SteelWorks',
        'net_mass': 36.22,
        'delivered_tons': 36.10,
        'time_out': '2026-07-12T08:05:00Z',
        'trip_status': 'completed',
      });
      expect(r.waybillNumber, 'TRP-ABC123');
      expect(r.netMass, 36.22);
      expect(r.deliveredTons, 36.10);
      expect(r.timeOut, isNotNull);
    });

    test('tolerates sparse rows (pre-weigh trips)', () {
      final r = RawReconRow.fromJson({
        'trip_id': 't-2',
        'trip_date': '2026-07-12T06:30:00Z',
      });
      expect(r.netMass, isNull);
      expect(r.timeIn, isNull);
      expect(r.waybillNumber, isNull);
    });
  });

  group('ReconUploadPair', () {
    test('parses original-only and full pairs', () {
      final originalOnly = ReconUploadPair.fromJson({
        'id': 'p-1',
        'company_id': 'co-1',
        'side': 'A',
        'original_path': 'co-1/x_sideA_original.csv',
        'original_created_at': '2026-07-12T09:00:00Z',
        'edited_path': null,
        'edited_uploaded_at': null,
      });
      expect(originalOnly.editedPath, isNull);

      final full = ReconUploadPair.fromJson({
        'id': 'p-2',
        'company_id': 'co-1',
        'side': 'B',
        'original_path': 'co-1/y_sideB_original.csv',
        'original_created_at': '2026-07-12T09:00:00Z',
        'edited_path': 'co-1/z_edited.xlsx',
        'edited_uploaded_at': '2026-07-12T10:00:00Z',
      });
      expect(full.side, 'B');
      expect(full.editedPath, 'co-1/z_edited.xlsx');
      expect(full.editedUploadedAt, isNotNull);
    });
  });

  group('ReconExporter.buildCsv', () {
    test('escapes commas, quotes and newlines', () {
      final csv = ReconExporter.buildCsv(
        ['A', 'B'],
        [
          ['plain', 'has,comma'],
          ['has "quote"', 'has\nnewline'],
        ],
      );
      final lines = csv.trim().split('\n');
      expect(lines.first, 'A,B');
      expect(csv, contains('"has,comma"'));
      expect(csv, contains('"has ""quote"""'));
      expect(csv, contains('"has\nnewline"'));
    });
  });

  group('RawReconView.csvRows', () {
    test('renders the recon-table columns in order', () {
      final rows = RawReconView.csvRows([
        RawReconRow(
          tripId: 't-1',
          tripDate: DateTime.utc(2026, 7, 12, 6, 30),
          waybillNumber: 'TRP-1',
          transporterName: 'Haul Co',
          truckReg: 'ABC 123 GP',
          destination: 'Depot',
          product: 'Coal RB2',
          sourceName: 'Duma Mine',
          customerName: 'SteelWorks',
          netMass: 34.5,
        ),
      ]);
      expect(rows, hasLength(1));
      expect(rows.first, hasLength(RawReconView.csvHeaders.length));
      expect(rows.first[2], 'TRP-1');
      expect(rows.first[9], '34.50');
      expect(rows.first[10], ''); // no time-out yet
    });
  });
}
