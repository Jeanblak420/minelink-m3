import 'package:flutter_application_1/core/mcp/models/supabase_model.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';

/// MCP implementation of the Employee model
class EmployeeMCP
    implements
        SupabaseModelWithId,
        SupabaseModelWithTimestamps,
        SupabaseModelWithUserId {
  @override
  final String id;

  @override
  final String userId;

  final String firstName;
  final String lastName;
  final String whatsappNumber;
  final String? companyId;
  final UserRole? role;
  final String? status;

  @override
  final DateTime createdAt;

  @override
  final DateTime? updatedAt;

  final String? profilePhotoUrl;
  final bool isSouthAfricanCitizen;
  final String? idNumber;
  final String? passportOrWorkersPermit;
  final String? licenseDocument;
  final String? idDocumentUrl;
  final String? passportDocumentUrl;
  final String? workVisaDocumentUrl;
  final String? licenseDocumentUrl;

  /// Mirrors `employees.is_dismissed`, kept because 19 functions and the
  /// `chat_directory` view read it. Permanently false since migration
  /// `20260811180000` dropped the dismissal RPCs (client ruling, 2026-08-11).
  final bool isDismissed;

  EmployeeMCP({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.whatsappNumber,
    this.companyId,
    this.role,
    this.status,
    required this.createdAt,
    this.updatedAt,
    this.profilePhotoUrl,
    this.isSouthAfricanCitizen = true,
    this.idNumber,
    this.passportOrWorkersPermit,
    this.licenseDocument,
    this.idDocumentUrl,
    this.passportDocumentUrl,
    this.workVisaDocumentUrl,
    this.licenseDocumentUrl,
    this.isDismissed = false,
  });

  /// Creates an EmployeeMCP from a JSON map
  factory EmployeeMCP.fromJson(Map<String, dynamic> json) {
    return EmployeeMCP(
      id: json['id'],
      userId: json['user_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      whatsappNumber: json['whatsapp_number'] ?? '',
      companyId: json['company_id'],
      role: UserRole.tryParse(json['role'] as String?),
      status: json['status'],
      createdAt: json['created_at'] is String
          ? DateTime.parse(json['created_at'])
          : json['created_at'],
      updatedAt: json['updated_at'] != null
          ? (json['updated_at'] is String
                ? DateTime.parse(json['updated_at'])
                : json['updated_at'])
          : null,
      profilePhotoUrl: json['profile_photo_url'],
      isSouthAfricanCitizen: json['is_south_african_citizen'] ?? true,
      idNumber: json['id_number'],
      passportOrWorkersPermit: json['passport_or_workers_permit'],
      licenseDocument: json['license_document'],
      idDocumentUrl: json['id_document_url'],
      passportDocumentUrl: json['passport_document_url'],
      workVisaDocumentUrl: json['work_visa_document_url'],
      licenseDocumentUrl: json['license_document_url'],
      isDismissed: json['is_dismissed'] ?? false,
    );
  }

  /// Converts the EmployeeMCP to a JSON map
  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'whatsapp_number': whatsappNumber,
      'company_id': companyId,
      'role': role?.name,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'profile_photo_url': profilePhotoUrl,
      'is_south_african_citizen': isSouthAfricanCitizen,
      'id_number': idNumber,
      'passport_or_workers_permit': passportOrWorkersPermit,
      'license_document': licenseDocument,
      'id_document_url': idDocumentUrl,
      'passport_document_url': passportDocumentUrl,
      'work_visa_document_url': workVisaDocumentUrl,
      'license_document_url': licenseDocumentUrl,
      'is_dismissed': isDismissed,
    };
  }

  /// Get the full name of the employee
  String get fullName => '$firstName $lastName';

  /// Creates a copy of this EmployeeMCP with the given fields replaced with the new values
  EmployeeMCP copyWith({
    String? id,
    String? userId,
    String? firstName,
    String? lastName,
    String? whatsappNumber,
    String? companyId,
    UserRole? role,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? profilePhotoUrl,
    bool? isSouthAfricanCitizen,
    String? idNumber,
    String? passportOrWorkersPermit,
    String? licenseDocument,
    String? idDocumentUrl,
    String? passportDocumentUrl,
    String? workVisaDocumentUrl,
    String? licenseDocumentUrl,
    bool? isDismissed,
  }) {
    return EmployeeMCP(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      whatsappNumber: whatsappNumber ?? this.whatsappNumber,
      companyId: companyId ?? this.companyId,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      isSouthAfricanCitizen:
          isSouthAfricanCitizen ?? this.isSouthAfricanCitizen,
      idNumber: idNumber ?? this.idNumber,
      passportOrWorkersPermit:
          passportOrWorkersPermit ?? this.passportOrWorkersPermit,
      licenseDocument: licenseDocument ?? this.licenseDocument,
      idDocumentUrl: idDocumentUrl ?? this.idDocumentUrl,
      passportDocumentUrl: passportDocumentUrl ?? this.passportDocumentUrl,
      workVisaDocumentUrl: workVisaDocumentUrl ?? this.workVisaDocumentUrl,
      licenseDocumentUrl: licenseDocumentUrl ?? this.licenseDocumentUrl,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }

  /// Converts a legacy Employee model to an EmployeeMCP model
  factory EmployeeMCP.fromLegacyModel(dynamic employee) {
    return EmployeeMCP(
      id: employee.id,
      userId: employee.userId,
      firstName: employee.firstName,
      lastName: employee.lastName,
      whatsappNumber: employee.whatsappNumber,
      companyId: employee.companyId,
      role: employee.role,
      status: employee.status,
      createdAt: employee.createdAt,
      updatedAt: employee.updatedAt,
      profilePhotoUrl: employee.profilePhotoUrl,
      isSouthAfricanCitizen: employee.isSouthAfricanCitizen,
      idNumber: employee.idNumber,
      passportOrWorkersPermit: employee.passportOrWorkersPermit,
      licenseDocument: employee.licenseDocument,
      idDocumentUrl: employee.idDocumentUrl,
      passportDocumentUrl: employee.passportDocumentUrl,
      workVisaDocumentUrl: employee.workVisaDocumentUrl,
      licenseDocumentUrl: employee.licenseDocumentUrl,
      isDismissed: employee.isDismissed,
    );
  }
}
