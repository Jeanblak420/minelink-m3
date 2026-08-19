/// Compliance document model — one expiring document (vehicle / employee /
/// company) backed by list_compliance_documents and mutated via the compliance
/// RPCs. Enums carry `.wire` + tolerant `parse` (same pattern as TripStatus).
library;

enum ComplianceStatus {
  valid('valid', 'Valid'),
  expiring('expiring', 'Expiring soon'),
  expired('expired', 'Expired'),
  noExpiry('no_expiry', 'No expiry');

  const ComplianceStatus(this.wire, this.label);
  final String wire;
  final String label;

  static ComplianceStatus parse(String? v) {
    for (final s in ComplianceStatus.values) {
      if (s.wire == v) return s;
    }
    return ComplianceStatus.noExpiry;
  }
}

enum ComplianceOwnerType {
  vehicle('vehicle', 'Vehicle'),
  employee('employee', 'Employee / Driver'),
  company('company', 'Company');

  const ComplianceOwnerType(this.wire, this.label);
  final String wire;
  final String label;

  static ComplianceOwnerType parse(String? v) {
    for (final o in ComplianceOwnerType.values) {
      if (o.wire == v) return o;
    }
    return ComplianceOwnerType.company;
  }

  /// Suggested document types for this owner type (wire → label). Free text is
  /// still allowed via "Other".
  List<MapEntry<String, String>> get suggestedDocTypes => switch (this) {
        ComplianceOwnerType.vehicle => const [
            MapEntry('vehicle_registration', 'Vehicle registration'),
            MapEntry('license_disc', 'Licence disc'),
            MapEntry('cof', 'Certificate of Fitness (COF)'),
            MapEntry('roadworthy', 'Roadworthy'),
            MapEntry('insurance', 'Insurance'),
            MapEntry('git', 'Goods-in-transit (GIT)'),
            MapEntry('cross_border_permit', 'Cross-border permit'),
          ],
        ComplianceOwnerType.employee => const [
            MapEntry('drivers_license', "Driver's licence"),
            MapEntry('prdp', 'Professional driving permit (PrDP)'),
            MapEntry('id_document', 'ID document'),
            MapEntry('passport', 'Passport'),
            MapEntry('work_visa', 'Work visa'),
            MapEntry('medical', 'Medical certificate'),
            MapEntry('other_medical', 'Other medical record'),
            MapEntry('induction', 'Site induction'),
            MapEntry('psira', 'PSIRA registration'),
            MapEntry('firearm_competency', 'Firearm competency'),
            MapEntry('weighbridge_competency', 'Weighbridge competency'),
            MapEntry('supervisor_appointment', 'Supervisor appointment'),
            MapEntry('first_aid', 'First-aid certificate'),
          ],
        ComplianceOwnerType.company => const [
            MapEntry('mining_right', 'Mining right'),
            MapEntry('dmre_return', 'DMRE return'),
            MapEntry('explosives_permit', 'Explosives permit'),
            MapEntry('water_use_licence', 'Water-use licence'),
            MapEntry('company_registration', 'Company registration (CIPC)'),
            MapEntry('tax_clearance', 'Tax clearance'),
            MapEntry('bee_certificate', 'B-BBEE certificate'),
            MapEntry('vat_registration', 'VAT registration'),
            MapEntry('operating_licence', 'Operating licence'),
            MapEntry('git_insurance', 'GIT insurance'),
          ],
      };
}

/// Friendly label for a stored doc_type wire string (falls back to a
/// title-cased version of the raw value).
String complianceDocTypeLabel(String wire) {
  for (final o in ComplianceOwnerType.values) {
    for (final e in o.suggestedDocTypes) {
      if (e.key == wire) return e.value;
    }
  }
  return wire
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

class ComplianceDocument {
  final String id;
  final String companyId;
  final ComplianceOwnerType ownerType;
  final String ownerId;
  final String? ownerName;
  final String docType;
  final String? title;
  final String? docNumber;
  final DateTime? issuedAt;
  final DateTime? expiresAt;
  final String? filePath;
  final String? notes;
  final int? daysToExpiry;
  final ComplianceStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ComplianceDocument({
    required this.id,
    required this.companyId,
    required this.ownerType,
    required this.ownerId,
    required this.docType,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.ownerName,
    this.title,
    this.docNumber,
    this.issuedAt,
    this.expiresAt,
    this.filePath,
    this.notes,
    this.daysToExpiry,
  });

  String get displayTitle =>
      (title != null && title!.trim().isNotEmpty)
          ? title!
          : complianceDocTypeLabel(docType);

  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory ComplianceDocument.fromJson(Map<String, dynamic> j) =>
      ComplianceDocument(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        ownerType: ComplianceOwnerType.parse(_s(j['owner_type'])),
        ownerId: j['owner_id'] as String,
        ownerName: _s(j['owner_name']),
        docType: (j['doc_type'] ?? '').toString(),
        title: _s(j['title']),
        docNumber: _s(j['doc_number']),
        issuedAt: _date(j['issued_at']),
        expiresAt: _date(j['expires_at']),
        filePath: _s(j['file_path']),
        notes: _s(j['notes']),
        daysToExpiry: (j['days_to_expiry'] as num?)?.toInt(),
        status: ComplianceStatus.parse(_s(j['status'])),
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}
