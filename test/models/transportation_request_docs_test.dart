import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/transportation_request.dart';
import 'package:flutter_application_1/features/portal/services/request_service.dart';

void main() {
  group('RequestDraft attachments', () {
    test('toColumns carries lab_result_paths and product_image_path', () {
      const draft = RequestDraft(
        requestType: 'buyer',
        labResultPaths: ['co-1/aaa_lab1.pdf', 'co-1/bbb_lab2.pdf'],
        productImagePath: 'co-1/ccc_photo.png',
      );
      final cols = draft.toColumns();
      expect(cols['lab_result_paths'],
          ['co-1/aaa_lab1.pdf', 'co-1/bbb_lab2.pdf']);
      expect(cols['product_image_path'], 'co-1/ccc_photo.png');
    });

    test('defaults to no attachments', () {
      const draft = RequestDraft(requestType: 'buyer');
      final cols = draft.toColumns();
      expect(cols['lab_result_paths'], isEmpty);
      expect(cols['product_image_path'], isNull);
    });
  });

  group('TransportationRequest attachments', () {
    Map<String, dynamic> baseJson() => {
          'id': 'r-1',
          'buyer_company_id': 'co-1',
          'request_type': 'buyer',
          'status': 'requested',
          'created_at': '2026-07-12T10:00:00Z',
          'updated_at': '2026-07-12T10:00:00Z',
        };

    test('fromJson parses lab_result_paths and product_image_path', () {
      final r = TransportationRequest.fromJson({
        ...baseJson(),
        'lab_result_paths': ['co-1/aaa_lab1.pdf', 'co-1/bbb_lab2.pdf'],
        'product_image_path': 'co-1/ccc_photo.png',
      });
      expect(r.labResultPaths, ['co-1/aaa_lab1.pdf', 'co-1/bbb_lab2.pdf']);
      expect(r.productImagePath, 'co-1/ccc_photo.png');
    });

    test('fromJson tolerates missing/null attachment columns (legacy rows)',
        () {
      final r = TransportationRequest.fromJson(baseJson());
      expect(r.labResultPaths, isEmpty);
      expect(r.productImagePath, isNull);

      final rNull = TransportationRequest.fromJson({
        ...baseJson(),
        'lab_result_paths': null,
        'product_image_path': null,
      });
      expect(rNull.labResultPaths, isEmpty);
      expect(rNull.productImagePath, isNull);
    });
  });
}
