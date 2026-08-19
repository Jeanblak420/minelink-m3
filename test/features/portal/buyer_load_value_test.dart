// S9-4 — the buyer's money row, which had no test.
//
// `BuyerLoadValue` is the one model that carries Rand figures to a customer,
// and the standing constraint on it is a NEGATIVE one: `list_buyer_trip_values`
// must never return the admin margin or the transporter's price. The model is
// the last place that could leak them, so the first group below asserts the
// absence — a field that does not exist cannot be rendered by accident.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/models/buyer_load_value.dart';

BuyerLoadValue fromJson(Map<String, dynamic> extra) =>
    BuyerLoadValue.fromJson({
      'trip_id': 't1',
      'updated_at': '2026-08-15T00:00:00Z',
      ...extra,
    });

void main() {
  group('what the buyer must never be handed', () {
    test('extra margin/transporter keys on the row are silently dropped', () {
      // If the RPC ever regressed and started returning these, fromJson must
      // not surface them. Nothing reads them, so nothing can render them.
      final v = fromJson({
        'rate_per_ton': 1200,
        'admin_margin': 250,
        'transporter_rate_per_ton': 950,
        'margin_total': 9000,
      });
      expect(v.ratePerTon, 1200.0);
      expect(v.toString(), isNot(contains('950')));
      expect(v.toString(), isNot(contains('250')));
    });
  });

  group('currency', () {
    test('defaults to ZAR — the platform is Rand-only', () {
      expect(fromJson({}).currency, 'ZAR');
      expect(fromJson({'currency': null}).currency, 'ZAR');
      expect(fromJson({'currency': '   '}).currency, 'ZAR',
          reason: 'a blank currency must fall back, not render as empty');
    });

    test('an explicit currency is respected', () {
      expect(fromJson({'currency': 'USD'}).currency, 'USD');
    });
  });

  group('state flags drive which columns the table shows', () {
    test('isPriced follows the agreed rate, including a zero rate', () {
      expect(fromJson({}).isPriced, isFalse);
      expect(fromJson({'rate_per_ton': 1200}).isPriced, isTrue);
      expect(fromJson({'rate_per_ton': 0}).isPriced, isTrue,
          reason: 'R0/ton is a priced load, not an unpriced one');
    });

    test('hasInvoice follows the captured amount, including zero', () {
      expect(fromJson({}).hasInvoice, isFalse);
      expect(fromJson({'invoice_number': 'INV-1'}).hasInvoice, isFalse,
          reason: 'a number with no amount is not a captured invoice');
      expect(fromJson({'invoiced_amount': 0}).hasInvoice, isTrue);
      expect(fromJson({'invoiced_amount': 43200}).hasInvoice, isTrue);
    });

    test('isDelivered follows delivered tons, including a zero delivery', () {
      expect(fromJson({}).isDelivered, isFalse);
      expect(fromJson({'delivered_tons': 0}).isDelivered, isTrue,
          reason: 'a load that arrived empty is delivered and is a dispute, '
              'not an undelivered load');
      expect(fromJson({'delivered_tons': 35.8}).isDelivered, isTrue);
    });
  });

  group('the values as the server sends them', () {
    test('a full priced, delivered, invoiced row reads back intact', () {
      final v = fromJson({
        'reference': 'TRP-000123',
        'truck_reg': 'ABC 123 GP',
        'commodity': 'Chrome',
        'source_name': 'Iron Hills Mining',
        'transporter_name': 'Roadhaul Logistics',
        'net_tons': 36.22,
        'delivered_tons': 35.80,
        'rate_per_ton': 1200,
        'loaded_value': 43464.0,
        'delivered_value': 42960.0,
        'payable_tons': 34.10,
        'grade_factor': 0.9048,
        'payable_value': 40920.0,
        'invoice_id': 'inv-1',
        'invoice_number': 'INV-2026-0001',
        'invoiced_tons': 35.80,
        'invoiced_amount': 42960.0,
        'invoice_date': '2026-08-01',
        'invoice_variance': 2040.0,
        'trip_status': 'completed',
      });
      expect(v.isPriced, isTrue);
      expect(v.isDelivered, isTrue);
      expect(v.hasInvoice, isTrue);
      expect(v.netTons, closeTo(36.22, 1e-9));
      expect(v.loadedValue, closeTo(43464.0, 1e-9));
      expect(v.payableValue, closeTo(40920.0, 1e-9));
      expect(v.invoiceDate, DateTime.parse('2026-08-01'));
      expect(v.currency, 'ZAR');
    });

    test('variance keeps its sign — over-invoicing must not look like under',
        () {
      // invoice_variance = invoiced - payable, so a positive figure means the
      // buyer was billed MORE than the load is worth. Losing the sign here
      // would turn an overcharge into an undercharge on the buyer's screen.
      expect(fromJson({'invoice_variance': 2040.0}).invoiceVariance,
          closeTo(2040.0, 1e-9));
      expect(fromJson({'invoice_variance': -515.5}).invoiceVariance,
          closeTo(-515.5, 1e-9));
      expect(fromJson({'invoice_variance': 0}).invoiceVariance, 0.0);
    });

    test('a bad invoice_date is null rather than an exception', () {
      expect(fromJson({'invoice_date': 'not a date'}).invoiceDate, isNull);
    });

    test('an undelivered load carries nulls, not zeros', () {
      final v = fromJson({'rate_per_ton': 1200, 'net_tons': 36});
      expect(v.deliveredTons, isNull);
      expect(v.deliveredValue, isNull);
      expect(v.payableValue, isNull);
      expect(v.invoiceVariance, isNull,
          reason: 'null means "not yet", 0 means "exactly nil" — the money '
              'columns must be able to tell those apart');
    });
  });
}
