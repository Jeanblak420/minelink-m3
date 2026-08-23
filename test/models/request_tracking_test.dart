import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/portal/models/request_tracking.dart';
import 'package:flutter_application_1/features/portal/models/transportation_request.dart';

void main() {
  group('RequestTrackingRow', () {
    Map<String, dynamic> base() => {
          'request_id': 'r-1',
          'request_type': 'transportation',
          'status': 'linked',
          'requester_name': 'SteelWorks',
          'supplier_name': 'Duma Mine',
          'transporter_names': 'Haul Co, FastFreight',
          'loading_point': 'Duma Mine',
          'offloading_point': 'Saldanha Port',
          'trips_total': 4,
          'trips_completed': 4,
          'tons_delivered': 144.9,
          'is_completed': true,
          'updated_at': '2026-07-12T10:00:00Z',
        };

    test('completed request shows Completed over linked', () {
      final r = RequestTrackingRow.fromJson(base());
      expect(r.isCompleted, isTrue);
      expect(r.displayStatus, 'Completed');
      expect(r.routeLabel, 'Duma Mine → Saldanha Port');
      expect(r.transporterNames, contains('FastFreight'));
    });

    test('in-flight request keeps its lifecycle status', () {
      final r = RequestTrackingRow.fromJson({
        ...base(),
        'trips_completed': 2,
        'is_completed': false,
      });
      expect(r.displayStatus, 'linked');
      expect(r.tripsCompleted, 2);
    });

    test('product request uses the commodity as its label', () {
      final r = RequestTrackingRow.fromJson({
        ...base(),
        'request_type': 'product',
        'commodity': 'Chrome 38/40',
      });
      expect(r.typeLabel, 'Product');
      expect(r.routeLabel, 'Chrome 38/40');
    });
  });

  group('RequestCompanyInfo', () {
    test('parses the embedded requester company', () {
      final c = RequestCompanyInfo.fromJson({
        'id': 'co-1',
        'company_name': 'SteelWorks',
        'org_type': 'buyer',
        'whatsapp_number': '+27 82 000 0000',
        'ceo_first_name': 'Eli',
        'ceo_last_name': 'Brown',
        'support_contact_email': 'ops@steelworks.co.za',
        'status': 'active',
        'created_at': '2026-03-22T14:20:00Z',
      });
      expect(c.name, 'SteelWorks');
      expect(c.orgTypeLabel, 'Buyer');
      expect(c.ceoName, 'Eli Brown');
      expect(c.memberSince, isNotNull);
    });

    test('TransportationRequest carries the embedded requester', () {
      final r = TransportationRequest.fromJson({
        'id': 'r-1',
        'buyer_company_id': 'co-1',
        'status': 'requested',
        'created_at': '2026-07-12T10:00:00Z',
        'updated_at': '2026-07-12T10:00:00Z',
        'requester_company': {
          'id': 'co-1',
          'company_name': 'Duma Mine',
          'org_type': 'mineSupplier',
        },
      });
      expect(r.requesterCompany?.name, 'Duma Mine');
      expect(r.requesterCompany?.orgTypeLabel, 'Mine/Supplier');
      expect(r.isFromMine, isTrue);
    });
  });
}
