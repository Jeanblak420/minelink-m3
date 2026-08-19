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

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'],
      userId: json['user_id'],
      companyName: json['company_name'],
      whatsappNumber: json['whatsapp_number'],
      orgType: OrgType.values.firstWhere(
        (e) => e.name == json['org_type'],
        orElse: () => OrgType.mineSupplier,
      ),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
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
