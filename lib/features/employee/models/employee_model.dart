import 'package:flutter_application_1/features/auth/models/user_type.dart';

class Employee {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String whatsappNumber;
  final String? companyId;
  final UserRole? role;
  final String? status; // Added status field to track approval status
  final DateTime createdAt;
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

  // Account-setup personal details (2026-08-07)
  final DateTime? dateOfBirth;
  final String? residentialAddress;
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? contactEmail;
  final DateTime? employmentStartDate;
  final String? licenseCodes;
  final String? psiraGrade;

  /// Mirrors `employees.is_dismissed`, which survives the removal of the
  /// dismissal feature (client ruling, 2026-08-11) because 19 functions —
  /// `is_company_staff`, `is_company_manager`, `has_company_role` among them —
  /// and the `chat_directory` view read it. Since migration `20260811180000`
  /// dropped the three dismissal RPCs, nothing can set it: it is permanently
  /// false. The other dismissal columns are still on the table and catalogued
  /// for removal in To-Do's.md P12-28; they are deliberately not modelled here,
  /// because nothing may read a value nothing can write.
  final bool isDismissed;

  Employee({
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
    this.dateOfBirth,
    this.residentialAddress,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.contactEmail,
    this.employmentStartDate,
    this.licenseCodes,
    this.psiraGrade,
    this.isDismissed = false,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'],
      userId: json['user_id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      whatsappNumber: json['whatsapp_number'],
      companyId: json['company_id'],
      role: UserRole.tryParse(json['role'] as String?),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
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
      dateOfBirth: json['date_of_birth'] != null
          ? DateTime.tryParse(json['date_of_birth'].toString())
          : null,
      residentialAddress: json['residential_address'],
      emergencyContactName: json['emergency_contact_name'],
      emergencyContactPhone: json['emergency_contact_phone'],
      contactEmail: json['contact_email'],
      employmentStartDate: json['employment_start_date'] != null
          ? DateTime.tryParse(json['employment_start_date'].toString())
          : null,
      licenseCodes: json['license_codes'],
      psiraGrade: json['psira_grade'],
      isDismissed: json['is_dismissed'] ?? false,
    );
  }

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
      'date_of_birth': dateOfBirth?.toIso8601String().substring(0, 10),
      'residential_address': residentialAddress,
      'emergency_contact_name': emergencyContactName,
      'emergency_contact_phone': emergencyContactPhone,
      'contact_email': contactEmail,
      'employment_start_date':
          employmentStartDate?.toIso8601String().substring(0, 10),
      'license_codes': licenseCodes,
      'psira_grade': psiraGrade,
      'is_dismissed': isDismissed,
    };
  }

  /// Get the full name of the employee
  String get fullName => '$firstName $lastName';

  Employee copyWith({
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
    DateTime? dateOfBirth,
    String? residentialAddress,
    String? emergencyContactName,
    String? emergencyContactPhone,
    String? contactEmail,
    DateTime? employmentStartDate,
    String? licenseCodes,
    String? psiraGrade,
    bool? isDismissed,
  }) {
    return Employee(
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
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      residentialAddress: residentialAddress ?? this.residentialAddress,
      emergencyContactName: emergencyContactName ?? this.emergencyContactName,
      emergencyContactPhone:
          emergencyContactPhone ?? this.emergencyContactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      employmentStartDate: employmentStartDate ?? this.employmentStartDate,
      licenseCodes: licenseCodes ?? this.licenseCodes,
      psiraGrade: psiraGrade ?? this.psiraGrade,
      isDismissed: isDismissed ?? this.isDismissed,
    );
  }
}
