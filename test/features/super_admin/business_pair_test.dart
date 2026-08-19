import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/super_admin/data/models/business_pair.dart';

void main() {
  test('derives buyer<->supplier pair from an accepted request with reason', () {
    final pairs = buildBusinessPairs(
      [
        {
          'id': 'r1',
          'status': 'accepted',
          'buyer_company_id': 'B',
          'supplier_company_id': 'A',
          'commodity': 'Chrome',
          'tons': '40000',
          'updated_at': '2026-07-12T10:00:00Z',
        },
      ],
      const [],
      const [],
    );
    expect(pairs, hasLength(1));
    expect(pairs.first.key, 'A|B');
    expect(pairs.first.reason, contains('transport request'));
    expect(pairs.first.reason, contains('Chrome'));
  });

  test('derives pair from a canonical linked request using tons_available', () {
    final pairs = buildBusinessPairs(
      [
        {
          'id': 'r1',
          'status': 'linked',
          'buyer_company_id': 'B',
          'supplier_company_id': 'A',
          'commodity': 'Chrome Ore',
          'tons_available': '70',
          'updated_at': '2026-07-13T10:00:00Z',
        },
        {
          'id': 'r2',
          'status': 'approved',
          'buyer_company_id': 'C',
          'supplier_company_id': 'A',
          'commodity': 'Coal',
          'updated_at': '2026-07-14T10:00:00Z',
        },
      ],
      const [],
      const [],
    );
    expect(pairs, hasLength(2));
    final ab = pairs.firstWhere((p) => p.key == 'A|B');
    expect(ab.reason, contains('Chrome Ore'));
    expect(ab.reason, contains('(70 t)'));
    expect(pairs.any((p) => p.key == 'A|C'), isTrue);
  });

  test('ignores non-accepted requests and self/null pairs', () {
    final pairs = buildBusinessPairs(
      [
        {
          'id': 'r1',
          'status': 'submitted',
          'buyer_company_id': 'B',
          'supplier_company_id': 'A'
        },
        {
          'id': 'r2',
          'status': 'accepted',
          'buyer_company_id': 'A',
          'supplier_company_id': 'A'
        },
        {
          'id': 'r3',
          'status': 'accepted',
          'buyer_company_id': 'B',
          'supplier_company_id': null
        },
      ],
      const [],
      const [],
    );
    expect(pairs, isEmpty);
  });

  test('most recent source wins for the same pair', () {
    final pairs = buildBusinessPairs(
      [
        {
          'id': 'r1',
          'status': 'accepted',
          'buyer_company_id': 'B',
          'supplier_company_id': 'A',
          'updated_at': '2026-07-10T00:00:00Z'
        },
      ],
      [
        {
          'id': 'd1',
          'status': 'accepted',
          'transporter_company_id': 'A',
          'request_buyer_company_id': 'B',
          'dispatched_at': '2026-07-13T00:00:00Z'
        },
      ],
      const [],
    );
    // pair A|B appears from both; keeps the later dispatch date.
    final ab = pairs.firstWhere((p) => p.key == 'A|B');
    expect(ab.date.toUtc().toIso8601String(), '2026-07-13T00:00:00.000Z');
  });
}
