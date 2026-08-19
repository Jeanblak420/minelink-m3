import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/features/profile_setup/models/profile_setup.dart';

void main() {
  group('SetupItemStatus', () {
    test('parses wire values and falls back to missing', () {
      expect(SetupItemStatus.parse('complete'), SetupItemStatus.complete);
      expect(SetupItemStatus.parse('expiring'), SetupItemStatus.expiring);
      expect(
          SetupItemStatus.parse('needs_expiry'), SetupItemStatus.needsExpiry);
      expect(SetupItemStatus.parse('expired'), SetupItemStatus.expired);
      expect(SetupItemStatus.parse('missing'), SetupItemStatus.missing);
      expect(SetupItemStatus.parse('garbage'), SetupItemStatus.missing);
      expect(SetupItemStatus.parse(null), SetupItemStatus.missing);
    });

    test('completion semantics match the server', () {
      expect(SetupItemStatus.complete.countsComplete, isTrue);
      expect(SetupItemStatus.expiring.countsComplete, isTrue);
      expect(SetupItemStatus.needsExpiry.countsComplete, isFalse);
      expect(SetupItemStatus.expired.countsComplete, isFalse);
      expect(SetupItemStatus.missing.countsComplete, isFalse);
    });
  });

  group('ProfileSetup.fromJson', () {
    Map<String, dynamic> payload() => {
          'audience': 'employee',
          'subject_id': 'e-1',
          'org_type': 'transporter',
          'role': 'driver',
          'company_id': 'c-1',
          'is_sa_citizen': true,
          'items': [
            {
              'item_key': 'drivers_license',
              'label': "Driver's licence",
              'category': 'licences',
              'item_kind': 'document',
              'is_required': true,
              'requires_expiry': true,
              'requires_file': true,
              'sort_order': 90,
              'status': 'expiring',
              'source': 'compliance_doc',
              'document_id': 'd-1',
              'file_present': true,
              'expires_at': '2026-08-17',
              'days_to_expiry': 10,
            },
            {
              'item_key': 'profile_photo',
              'label': 'Profile photo',
              'category': 'personal',
              'item_kind': 'photo',
              'is_required': true,
              'requires_expiry': false,
              'requires_file': false,
              'sort_order': 10,
              'status': 'missing',
              'source': 'field',
              'document_id': null,
              'file_present': false,
              'expires_at': null,
              'days_to_expiry': null,
            },
            {
              'item_key': 'medical',
              'label': 'Medical certificate of fitness',
              'category': 'medical',
              'item_kind': 'document',
              'is_required': true,
              'requires_expiry': true,
              'requires_file': true,
              'sort_order': 80,
              'status': 'complete',
              'source': 'compliance_doc',
              'document_id': 'd-2',
              'file_present': true,
              'expires_at': '2027-01-05',
              'days_to_expiry': 151,
            },
          ],
          'summary': {
            'total_items': 3,
            'complete_items': 2,
            'required_total': 3,
            'required_complete': 2,
            'completion_percent': 67,
            'missing_required': ['Profile photo'],
            'missing_count': 1,
            'expiring_count': 1,
            'expired_count': 0,
          },
        };

    test('parses payload and sorts items by category then sort order', () {
      final setup = ProfileSetup.fromJson(payload());
      expect(setup.isApplicable, isTrue);
      expect(setup.isEmployee, isTrue);
      expect(setup.role, 'driver');
      expect(setup.items, hasLength(3));
      // personal (photo) before medical before licences
      expect(setup.items.first.itemKey, 'profile_photo');
      expect(setup.items[1].itemKey, 'medical');
      expect(setup.items.last.itemKey, 'drivers_license');
      expect(setup.items.last.expiresAt, DateTime.parse('2026-08-17'));
      expect(setup.items.last.daysToExpiry, 10);
    });

    test('summary + categories', () {
      final setup = ProfileSetup.fromJson(payload());
      expect(setup.summary.completionPercent, 67);
      expect(setup.summary.needsAttention, isTrue);
      expect(setup.summary.hasOutstandingRequired, isTrue);
      expect(setup.summary.missingRequired, ['Profile photo']);
      expect(setup.categories, [
        SetupCategory.personal,
        SetupCategory.medical,
        SetupCategory.licences,
      ]);
      expect(setup.itemsIn(SetupCategory.medical).single.itemKey, 'medical');
    });

    test('null-audience payload (platform admin) is not applicable', () {
      final setup = ProfileSetup.fromJson({
        'audience': null,
        'items': [],
        'summary': {
          'total_items': 0,
          'complete_items': 0,
          'required_total': 0,
          'required_complete': 0,
          'completion_percent': 100,
          'missing_required': [],
          'missing_count': 0,
          'expiring_count': 0,
          'expired_count': 0,
        },
      });
      expect(setup.isApplicable, isFalse);
      expect(setup.summary.needsAttention, isFalse);
      expect(setup.summary.completionPercent, 100);
    });
  });
}
