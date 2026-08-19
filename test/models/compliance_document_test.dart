import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/features/portal/models/compliance_document.dart';

void main() {
  group('ComplianceStatus / ComplianceOwnerType', () {
    test('wire round-trips + tolerant parse', () {
      for (final s in ComplianceStatus.values) {
        expect(ComplianceStatus.parse(s.wire), s);
      }
      expect(ComplianceStatus.parse('???'), ComplianceStatus.noExpiry);
      for (final o in ComplianceOwnerType.values) {
        expect(ComplianceOwnerType.parse(o.wire), o);
      }
      expect(ComplianceOwnerType.parse(null), ComplianceOwnerType.company);
    });

    test('each owner type suggests document types', () {
      for (final o in ComplianceOwnerType.values) {
        expect(o.suggestedDocTypes, isNotEmpty);
      }
    });
  });

  group('complianceDocTypeLabel', () {
    test('known wire → friendly label', () {
      expect(complianceDocTypeLabel('cof'), 'Certificate of Fitness (COF)');
      expect(complianceDocTypeLabel('prdp'),
          'Professional driving permit (PrDP)');
    });
    test('unknown wire → title-cased fallback', () {
      expect(complianceDocTypeLabel('custom_permit'), 'Custom Permit');
    });
  });

  test('ComplianceDocument.fromJson maps status + owner + expiry', () {
    final d = ComplianceDocument.fromJson({
      'id': 'd1',
      'company_id': 'c1',
      'owner_type': 'vehicle',
      'owner_id': 'v1',
      'owner_name': 'ND 123-456',
      'doc_type': 'license_disc',
      'title': null,
      'doc_number': 'LD-99',
      'issued_at': '2026-01-01',
      'expires_at': '2026-08-05',
      'file_path': null,
      'notes': 'renew at post office',
      'days_to_expiry': 9,
      'status': 'expiring',
      'created_at': '2026-07-27T10:00:00Z',
      'updated_at': '2026-07-27T10:00:00Z',
    });

    expect(d.ownerType, ComplianceOwnerType.vehicle);
    expect(d.ownerName, 'ND 123-456');
    expect(d.status, ComplianceStatus.expiring);
    expect(d.daysToExpiry, 9);
    expect(d.expiresAt, DateTime.parse('2026-08-05'));
    // displayTitle falls back to the doc-type label when title is null.
    expect(d.displayTitle, 'Licence disc');
  });
}
