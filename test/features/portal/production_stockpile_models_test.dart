// S9-4 — production dispatch and the stockpile audit trail, neither of which
// had a test.
//
// `ProductionDispatchDay` is the pair of numbers behind the mine's Yield % and
// Pit-to-port-loss cards. The cards divide one by the other, so the two cases
// that matter are a day with production but no dispatch (yield 0, not a crash)
// and a day with dispatch but no production (yield above 100%, which is real —
// it means the pile is being drawn down).
//
// `StockpileTransaction.delta` is signed, and `magnitude` is what the audit
// trail renders. A deduction that lost its sign would read as an addition.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/models/production_entry.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_transaction.dart';
import 'package:flutter_application_1/features/portal/models/stockpile_doc.dart';

void main() {
  group('ProductionEntry.fromJson', () {
    test('reads a full row', () {
      final e = ProductionEntry.fromJson({
        'id': 'pe-1',
        'company_id': 'co-1',
        'entry_date': '2026-08-14',
        'tons': 120.5,
        'commodity': 'Chrome',
        'pit_section': 'North Pit',
        'stockpile_id': 'sp-1',
        'notes': 'Day shift',
        'created_at': '2026-08-14T16:00:00Z',
      });
      expect(e.tons, closeTo(120.5, 1e-9));
      expect(e.entryDate, DateTime.parse('2026-08-14'));
      expect(e.pitSection, 'North Pit');
      expect(e.stockpileId, 'sp-1');
    });

    test('missing tons reads as 0, not null — the column is a sum', () {
      final e = ProductionEntry.fromJson({
        'id': 'pe-1',
        'company_id': 'co-1',
        'entry_date': '2026-08-14',
        'created_at': '2026-08-14T16:00:00Z',
      });
      expect(e.tons, 0.0);
    });

    test('an integer tonnage becomes a double', () {
      final e = ProductionEntry.fromJson({
        'id': 'pe-1',
        'company_id': 'co-1',
        'entry_date': '2026-08-14',
        'tons': 120,
        'created_at': '2026-08-14T16:00:00Z',
      });
      expect(e.tons, 120.0);
    });

    test('blank optional strings become null', () {
      final e = ProductionEntry.fromJson({
        'id': 'pe-1',
        'company_id': 'co-1',
        'entry_date': '2026-08-14',
        'created_at': '2026-08-14T16:00:00Z',
        'commodity': '  ',
        'notes': '',
        'pit_section': ' South ',
      });
      expect(e.commodity, isNull);
      expect(e.notes, isNull);
      expect(e.pitSection, 'South');
    });

    test('a production entry not tied to a pile has a null stockpileId', () {
      final e = ProductionEntry.fromJson({
        'id': 'pe-1',
        'company_id': 'co-1',
        'entry_date': '2026-08-14',
        'tons': 40,
        'created_at': '2026-08-14T16:00:00Z',
      });
      expect(e.stockpileId, isNull);
    });
  });

  group('ProductionDispatchDay — the yield cards divide these', () {
    ProductionDispatchDay day(dynamic mined, dynamic dispatched) =>
        ProductionDispatchDay.fromJson({
          'day': '2026-08-14',
          'mined_tons': mined,
          'dispatched_tons': dispatched,
        });

    test('reads the pair', () {
      final d = day(120, 35);
      expect(d.minedTons, 120.0);
      expect(d.dispatchedTons, 35.0);
      expect(d.day, DateTime.parse('2026-08-14'));
    });

    test('a null on either side is 0, so a sum never becomes null', () {
      expect(day(null, 35).minedTons, 0.0);
      expect(day(120, null).dispatchedTons, 0.0);
      expect(day(null, null).minedTons, 0.0);
    });

    test('mined with nothing dispatched is a legitimate day', () {
      final d = day(120, 0);
      expect(d.minedTons, 120.0);
      expect(d.dispatchedTons, 0.0);
    });

    test('dispatched with nothing mined is also legitimate', () {
      // Drawing an existing pile down. Yield > 100% is the correct reading of
      // this day and must not be treated as bad data.
      final d = day(0, 35);
      expect(d.minedTons, 0.0);
      expect(d.dispatchedTons, 35.0);
    });
  });

  group('StockpileTransaction — the append-only audit trail', () {
    StockpileTransaction txn(StockpileTxnType type, double delta,
            {double balanceAfter = 100}) =>
        StockpileTransaction(
          stockpileId: 'sp-1',
          stockpileName: 'Order pile',
          buyer: 'Atlas Buyer Group',
          type: type,
          delta: delta,
          balanceAfter: balanceAfter,
          at: DateTime.utc(2026, 8, 15),
        );

    test('labels match the three movement kinds', () {
      expect(StockpileTxnType.allocation.label, 'Allocated');
      expect(StockpileTxnType.addition.label, 'Added');
      expect(StockpileTxnType.deduction.label, 'Loaded out');
    });

    test('every type has a label — a new one cannot be added unnoticed', () {
      for (final t in StockpileTxnType.values) {
        expect(t.label, isNotEmpty);
      }
      expect(StockpileTxnType.values.length, 3);
    });

    test('magnitude is unsigned so a deduction renders as a positive tonnage',
        () {
      expect(txn(StockpileTxnType.deduction, -36.22).magnitude,
          closeTo(36.22, 1e-9));
      expect(txn(StockpileTxnType.addition, 30).magnitude, closeTo(30, 1e-9));
    });

    test('the sign survives on delta — direction is not lost', () {
      expect(txn(StockpileTxnType.deduction, -36.22).delta, lessThan(0));
      expect(txn(StockpileTxnType.addition, 30).delta, greaterThan(0));
    });

    test('balanceAfter is carried per row, not recomputed', () {
      // The running balance is the server's, captured at the moment of the
      // movement. Recomputing it client-side is what an audit trail exists to
      // avoid.
      final t = txn(StockpileTxnType.deduction, -30, balanceAfter: 70);
      expect(t.balanceAfter, 70);
      expect(t.magnitude, 30);
    });
  });

  group('StockpileDoc', () {
    test('reads a row and classifies a picture', () {
      final d = StockpileDoc.fromJson({
        'id': 'd1',
        'stockpile_id': 'sp-1',
        'kind': 'picture',
        'storage_path': 'req/abc.jpg',
        'file_name': 'pile.jpg',
        'created_at': '2026-08-15T08:00:00Z',
      });
      expect(d.isPicture, isTrue);
      expect(d.storagePath, 'req/abc.jpg');
    });

    test('defaults to a lab result when kind is absent', () {
      final d = StockpileDoc.fromJson({
        'id': 'd1',
        'stockpile_id': 'sp-1',
        'created_at': '2026-08-15T08:00:00Z',
      });
      expect(d.kind, 'lab_result');
      expect(d.isPicture, isFalse);
      expect(d.storagePath, '');
      expect(d.fileName, '');
    });

    test('an unknown kind is not a picture', () {
      final d = StockpileDoc.fromJson({
        'id': 'd1',
        'stockpile_id': 'sp-1',
        'kind': 'video',
        'created_at': '2026-08-15T08:00:00Z',
      });
      expect(d.isPicture, isFalse);
    });
  });
}
