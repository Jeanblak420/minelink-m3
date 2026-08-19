import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/services/request_service.dart';

void main() {
  group('Request period (Ongoing | Single request)', () {
    test('ongoing keeps the start date and drops the end date', () {
      final draft = RequestDraft(
        isOngoing: true,
        startingDate: DateTime(2026, 8, 1),
        endingDate: DateTime(2026, 9, 1),
      );
      final cols = draft.toColumns();
      expect(cols['starting_date'], '2026-08-01');
      expect(cols['ending_date'], isNull);
      expect(cols['is_ongoing'], isTrue);
    });

    test('single request carries both dates', () {
      final draft = RequestDraft(
        isOngoing: false,
        startingDate: DateTime(2026, 8, 1),
        endingDate: DateTime(2026, 9, 1),
      );
      final cols = draft.toColumns();
      expect(cols['starting_date'], '2026-08-01');
      expect(cols['ending_date'], '2026-09-01');
    });

    test('TransportationRequest parses ending_date', () {
      final r = TransportationRequest.fromJson({
        'id': 'r-1',
        'buyer_company_id': 'co-1',
        'status': 'requested',
        'starting_date': '2026-08-01',
        'ending_date': '2026-09-01',
        'is_ongoing': false,
        'created_at': '2026-07-12T10:00:00Z',
        'updated_at': '2026-07-12T10:00:00Z',
      });
      expect(r.startingDate, DateTime(2026, 8, 1));
      expect(r.endingDate, DateTime(2026, 9, 1));
    });
  });
}
