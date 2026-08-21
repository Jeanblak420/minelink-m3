import 'package:flutter_application_1/features/auth/models/user_type.dart';

class Company {
  final String id;
  final String userId;
  final String companyName;
  final String whatsappNumber;
  final OrgType orgType;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? logoUrl;
  final String? ceoFirstName;
  final String? ceoLastName;
  final String? supportContactEmail;
  final String? registrationNumber;
  final String? vatNumber;
  final String? physicalAddress;

  Company({
    required this.id,
    required this.userId,
    required this.companyName,
    required this.whatsappNumber,
    required this.orgType,
    required this.createdAt,
    this.updatedAt,
    this.logoUrl,
    this.ceoFirstName,
    this.ceoLastName,
    this.supportContactEmail,
    this.registrationNumber,
    this.vatNumber,
    this.physicalAddress,
  });

  /// TOLERANT on every field, per the house rule for anything that crosses
  /// the wire — the same rule `CompanyDirectoryEntry.fromJson` states for
  /// `org_type`: "an unrecognised value must not crash a picker".
  ///
  /// Five fields were assigned straight into non-nullable `String`s and one
  /// into a non-nullable `DateTime`, so a single null took the whole screen
  /// down with `type 'Null' is not a subtype of type 'String'` — a red box,
  /// not a missing field. Found 2026-08-21 the first time the company mirror
  /// was rendered: it builds a `Company` out of
  /// `organizationDetailProvider`'s raw row, and the row it was handed had no
  /// `user_id`. `getOrganizationById` reads that same column as
  /// `map['user_id'] as String?` two lines earlier, so the repository already
  /// treats it as possibly absent.
  ///
  /// The fallbacks are deliberately EMPTY rather than invented: an empty id
  /// makes a query find nothing, which is a visible dead end, while a made-up
  /// one would quietly address a different company. `createdAt` falls back to
  /// the epoch, which sorts to the bottom and reads as obviously wrong.
  factory Company.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic v) =>
        (v is String ? DateTime.tryParse(v) : null) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return Company(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      companyName: (json['company_name'] as String?) ?? '',
      whatsappNumber: (json['whatsapp_number'] as String?) ?? '',
      orgType: OrgType.values.firstWhere(
        (e) => e.name == json['org_type'],
        orElse: () => OrgType.mineSupplier,
      ),
      createdAt: parseDate(json['created_at']),
      updatedAt:
          json['updated_at'] == null ? null : parseDate(json['updated_at']),
      logoUrl: json['logo_url'],
      ceoFirstName: json['ceo_first_name'],
      ceoLastName: json['ceo_last_name'],
      supportContactEmail: json['support_contact_email'],
      registrationNumber: json['registration_number'],
      vatNumber: json['vat_number'],
      physicalAddress: json['physical_address'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'company_name': companyName,
      'whatsapp_number': whatsappNumber,
      'org_type': orgType.name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'logo_url': logoUrl,
      'ceo_first_name': ceoFirstName,
      'ceo_last_name': ceoLastName,
      'support_contact_email': supportContactEmail,
      'registration_number': registrationNumber,
      'vat_number': vatNumber,
      'physical_address': physicalAddress,
    };
  }

  Company copyWith({
    String? id,
    String? userId,
    String? companyName,
    String? whatsappNumber,
    OrgType? orgType,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? logoUrl,
    String? ceoFirstName,
    String? ceoLastName,
    String? supportContactEmail,
    String? registrationNumber,
    String? vatNumber,
    String? physicalAddress,
  }) {
    return Company(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyName: companyName ?? this.companyName,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      orgType: orgType ?? this.orgType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      logoUrl: logoUrl ?? this.logoUrl,
      ceoFirstName: ceoFirstName ?? this.ceoFirstName,
      ceoLastName: ceoLastName ?? this.ceoLastName,
      supportContactEmail: supportContactEmail ?? this.supportContactEmail,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      vatNumber: vatNumber ?? this.vatNumber,
      physicalAddress: physicalAddress ?? this.physicalAddress,
    );
  }
}
