import 'package:flutter_application_1/core/mcp/models/supabase_model.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';

/// MCP implementation of the Company model
class CompanyMCP
    implements
        SupabaseModelWithId,
        SupabaseModelWithTimestamps,
        SupabaseModelWithUserId {
  @override
  final String id;

  @override
  final String userId;

  final String companyName;
  final String whatsappNumber;
  final OrgType orgType;

  @override
  final DateTime createdAt;

  @override
  final DateTime? updatedAt;

  final String? logoUrl;
  final String? ceoFirstName;
  final String? ceoLastName;

  /// The permanent, system-issued company reference (S8-11): 3 letters + at
  /// least 3 digits, e.g. `ABC001`. Assigned by the database on insert and
  /// immutable thereafter, so it is safe to quote in a support call, on a
  /// document, or between two parties to a transaction.
  ///
  /// Deliberately distinct from `registration_number`, which is free text the
  /// customer types, is unvalidated, and may change at any time — which is why
  /// it could never serve as a reference.
  final String? regRef;

  CompanyMCP({
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
    this.regRef,
  });

  /// Creates a CompanyMCP from a JSON map
  factory CompanyMCP.fromJson(Map<String, dynamic> json) {
    return CompanyMCP(
      id: json['id'],
      userId: json['user_id'],
      companyName: json['company_name'],
      whatsappNumber: json['whatsapp_number'],
      orgType: OrgType.values.firstWhere(
        (e) => e.name == json['org_type'],
        orElse: () => OrgType.mineSupplier,
      ),
      createdAt: json['created_at'] is String
          ? DateTime.parse(json['created_at'])
          : json['created_at'],
      updatedAt: json['updated_at'] != null
          ? (json['updated_at'] is String
                ? DateTime.parse(json['updated_at'])
                : json['updated_at'])
          : null,
      logoUrl: json['logo_url'],
      ceoFirstName: json['ceo_first_name'],
      ceoLastName: json['ceo_last_name'],
      regRef: json['reg_ref'] as String?,
    );
  }

  /// Converts the CompanyMCP to a JSON map
  @override
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
    };
  }

  /// Creates a copy of this CompanyMCP with the given fields replaced with the new values
  CompanyMCP copyWith({
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
  }) {
    return CompanyMCP(
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
    );
  }

  /// Converts a legacy Company model to a CompanyMCP model
  factory CompanyMCP.fromLegacyModel(dynamic company) {
    return CompanyMCP(
      id: company.id,
      userId: company.userId,
      companyName: company.companyName,
      whatsappNumber: company.whatsappNumber,
      orgType: company.orgType,
      createdAt: company.createdAt,
      updatedAt: company.updatedAt,
      logoUrl: company.logoUrl,
      ceoFirstName: company.ceoFirstName,
      ceoLastName: company.ceoLastName,
    );
  }
}
