import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/super_admin/utils/organization_search.dart';

void main() {
  group('OrganizationSearch', () {
    test('matches company name and owner email', () {
      final org = <String, dynamic>{
        'id': 'fc245c74-0d37-4f1b-9cd2-feef374150fe',
        'company_name': 'Vis Mine',
        'whatsapp_number': '+27110000000',
        'ceo_first_name': 'Live',
        'ceo_last_name': 'Owner',
        'org_type': 'mineSupplier',
        'status': 'pendingActivation',
        'owner_profile': {
          'email': 'owner@example.com',
          'display_name': 'Mine Owner',
        },
      };

      org['_search_blob'] = OrganizationSearch.buildSearchBlob(org: org);

      expect(OrganizationSearch.matches(org, 'vis mine'), isTrue);
      expect(OrganizationSearch.matches(org, 'owner@example'), isTrue);
      expect(OrganizationSearch.matches(org, 'live owner'), isTrue);
      expect(OrganizationSearch.matches(org, '27110000000'), isTrue);
      expect(OrganizationSearch.matches(org, 'fc245c74'), isTrue);
      expect(OrganizationSearch.matches(org, 'not-found-xyz'), isFalse);
    });

    test('matches employee names and id numbers', () {
      final org = <String, dynamic>{
        'id': 'company-1',
        'company_name': 'Test Transporter',
        'org_type': 'transporter',
        'status': 'active',
      };

      org['_search_blob'] = OrganizationSearch.buildSearchBlob(
        org: org,
        employees: [
          {
            'first_name': 'Thabo',
            'last_name': 'Mokoena',
            'whatsapp_number': '0821234567',
            'id_number': '8001015800085',
            'user_id': 'user-1',
          },
        ],
        employeeProfilesByUserId: {
          'user-1': {'email': 'thabo@transporter.co.za'},
        },
      );

      expect(OrganizationSearch.matches(org, 'thabo'), isTrue);
      expect(OrganizationSearch.matches(org, 'mokoena'), isTrue);
      expect(OrganizationSearch.matches(org, '8001015800085'), isTrue);
      expect(OrganizationSearch.matches(org, 'thabo@transporter'), isTrue);
      expect(OrganizationSearch.matches(org, '0821234567'), isTrue);
    });

    test('matches fleet registration and token preview', () {
      final org = <String, dynamic>{
        'id': 'company-2',
        'company_name': 'Fleet Co',
        'org_type': 'transporter',
        'status': 'active',
      };

      org['_search_blob'] = OrganizationSearch.buildSearchBlob(
        org: org,
        fleetVehicles: [
          {
            'vehicle_registration_number': 'CA123GP',
            'driver_first_name': 'Sam',
            'driver_last_name': 'Driver',
          },
        ],
        serialTokens: [
          {'token_preview': 'ABCD-1234', 'organization_name': 'Fleet Co'},
        ],
      );

      expect(OrganizationSearch.matches(org, 'ca123gp'), isTrue);
      expect(OrganizationSearch.matches(org, 'abcd-1234'), isTrue);
      expect(OrganizationSearch.matches(org, 'sam driver'), isTrue);
    });
  });
}
