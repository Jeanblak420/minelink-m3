int? _readInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class FleetVehicle {
  final String id;
  final DateTime? vehicleRegistrationExpiryDate;
  final String vehicleRegistrationNumber;
  final String? vehicleMake;
  final String? vehicleType;
  final int? vehicleYearModel;
  final int? vehicleOdometerKm;
  final String? firstTrailerRegs;
  final String? secondTrailerRegs;

  /// Seal points on this rig — how many seals a sealed load must carry.
  ///
  /// A stated fact about the vehicle, not a guess. It used to be worked out
  /// at load time from whether the OPTIONAL trailer-registration text above
  /// had been filled in, so leaving a registration blank silently changed how
  /// many seals the weighbridge demanded — and then refused the correct load
  /// (migration 20260817320000).
  ///
  /// Derived from the trailers when the vehicle is created and correctable
  /// afterwards by the transporter that owns it. 1-4; the waybill prints four
  /// serial lines.
  final int sealPoints;
  final String? assignedDriverEmployeeId;
  final String? driverUserId;
  final String? driverFirstName;
  final String? driverLastName;
  final String? driverIdNumber;
  final String? driverPassportNumber;
  final String? driverWorkPermit;
  final String? driversLicenseDocument;
  final String? driverIdDocumentUrl;
  final String? driverPassportDocumentUrl;
  final String? driverWorkVisaDocumentUrl;
  final String? driverLicenseDocumentUrl;
  final bool? driverIsSouthAfricanCitizen;
  final String companyId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  FleetVehicle({
    required this.id,
    this.vehicleRegistrationExpiryDate,
    required this.vehicleRegistrationNumber,
    this.vehicleMake,
    this.vehicleType,
    this.vehicleYearModel,
    this.vehicleOdometerKm,
    this.firstTrailerRegs,
    this.secondTrailerRegs,
    this.sealPoints = 4,
    String? assignedDriverEmployeeId,
    String? assignedDriverId,
    this.driverUserId,
    this.driverFirstName,
    this.driverLastName,
    this.driverIdNumber,
    this.driverPassportNumber,
    this.driverWorkPermit,
    this.driversLicenseDocument,
    this.driverIdDocumentUrl,
    this.driverPassportDocumentUrl,
    this.driverWorkVisaDocumentUrl,
    this.driverLicenseDocumentUrl,
    this.driverIsSouthAfricanCitizen,
    required this.companyId,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  }) : assignedDriverEmployeeId = assignedDriverEmployeeId ?? assignedDriverId;

  factory FleetVehicle.fromJson(Map<String, dynamic> json) {
    return FleetVehicle(
      id: json['id'],
      vehicleRegistrationExpiryDate:
          json['vehicle_registration_expiry_date'] != null
          ? DateTime.parse(json['vehicle_registration_expiry_date'])
          : null,
      vehicleRegistrationNumber: json['vehicle_registration_number'],
      vehicleMake: json['vehicle_make'] as String?,
      vehicleType: json['vehicle_type'] as String?,
      vehicleYearModel: _readInt(json['vehicle_year_model']),
      vehicleOdometerKm: _readInt(json['vehicle_odometer_km']),
      firstTrailerRegs: json['first_trailer_regs'],
      sealPoints: (json['seal_points'] as num?)?.toInt() ?? 4,
      secondTrailerRegs: json['second_trailer_regs'],
      assignedDriverEmployeeId:
          json['assigned_driver_employee_id'] ?? json['assigned_driver_id'],
      driverUserId: json['driver_user_id'],
      driverFirstName: json['driver_first_name'],
      driverLastName: json['driver_last_name'],
      driverIdNumber: json['driver_id_number'],
      driverPassportNumber: json['driver_passport_number'],
      driverWorkPermit: json['driver_work_permit'],
      driversLicenseDocument: json['drivers_license_document'],
      driverIdDocumentUrl: json['driver_id_document_url'],
      driverPassportDocumentUrl: json['driver_passport_document_url'],
      driverWorkVisaDocumentUrl: json['driver_work_visa_document_url'],
      driverLicenseDocumentUrl: json['driver_license_document_url'],
      driverIsSouthAfricanCitizen: json['driver_is_south_african_citizen'],
      companyId: json['company_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle_registration_expiry_date': vehicleRegistrationExpiryDate
          ?.toIso8601String(),
      'vehicle_registration_number': vehicleRegistrationNumber,
      'vehicle_make': vehicleMake,
      'vehicle_type': vehicleType,
      'vehicle_year_model': vehicleYearModel,
      'vehicle_odometer_km': vehicleOdometerKm,
      'first_trailer_regs': firstTrailerRegs,
      'seal_points': sealPoints,
      'second_trailer_regs': secondTrailerRegs,
      'assigned_driver_employee_id': assignedDriverEmployeeId,
      'driver_user_id': driverUserId,
      'assigned_driver_id': assignedDriverEmployeeId,
      'driver_first_name': driverFirstName,
      'driver_last_name': driverLastName,
      'driver_id_number': driverIdNumber,
      'driver_passport_number': driverPassportNumber,
      'driver_work_permit': driverWorkPermit,
      'drivers_license_document': driversLicenseDocument,
      'driver_id_document_url': driverIdDocumentUrl,
      'driver_passport_document_url': driverPassportDocumentUrl,
      'driver_work_visa_document_url': driverWorkVisaDocumentUrl,
      'driver_license_document_url': driverLicenseDocumentUrl,
      'driver_is_south_african_citizen': driverIsSouthAfricanCitizen,
      'company_id': companyId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'is_active': isActive,
    };
  }

  FleetVehicle copyWith({
    String? id,
    DateTime? vehicleRegistrationExpiryDate,
    String? vehicleRegistrationNumber,
    String? vehicleMake,
    String? vehicleType,
    int? vehicleYearModel,
    int? vehicleOdometerKm,
    String? firstTrailerRegs,
    String? secondTrailerRegs,
    int? sealPoints,
    String? assignedDriverEmployeeId,
    String? assignedDriverId,
    String? driverUserId,
    String? driverFirstName,
    String? driverLastName,
    String? driverIdNumber,
    String? driverPassportNumber,
    String? driverWorkPermit,
    String? driversLicenseDocument,
    String? driverIdDocumentUrl,
    String? driverPassportDocumentUrl,
    String? driverWorkVisaDocumentUrl,
    String? driverLicenseDocumentUrl,
    bool? driverIsSouthAfricanCitizen,
    String? companyId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    return FleetVehicle(
      id: id ?? this.id,
      vehicleRegistrationExpiryDate:
          vehicleRegistrationExpiryDate ?? this.vehicleRegistrationExpiryDate,
      vehicleRegistrationNumber:
          vehicleRegistrationNumber ?? this.vehicleRegistrationNumber,
      vehicleMake: vehicleMake ?? this.vehicleMake,
      vehicleType: vehicleType ?? this.vehicleType,
      vehicleYearModel: vehicleYearModel ?? this.vehicleYearModel,
      vehicleOdometerKm: vehicleOdometerKm ?? this.vehicleOdometerKm,
      firstTrailerRegs: firstTrailerRegs ?? this.firstTrailerRegs,
      sealPoints: sealPoints ?? this.sealPoints,
      secondTrailerRegs: secondTrailerRegs ?? this.secondTrailerRegs,
      assignedDriverEmployeeId:
          assignedDriverEmployeeId ??
          assignedDriverId ??
          this.assignedDriverEmployeeId,
      driverUserId: driverUserId ?? this.driverUserId,
      driverFirstName: driverFirstName ?? this.driverFirstName,
      driverLastName: driverLastName ?? this.driverLastName,
      driverIdNumber: driverIdNumber ?? this.driverIdNumber,
      driverPassportNumber: driverPassportNumber ?? this.driverPassportNumber,
      driverWorkPermit: driverWorkPermit ?? this.driverWorkPermit,
      driversLicenseDocument:
          driversLicenseDocument ?? this.driversLicenseDocument,
      driverIdDocumentUrl: driverIdDocumentUrl ?? this.driverIdDocumentUrl,
      driverPassportDocumentUrl:
          driverPassportDocumentUrl ?? this.driverPassportDocumentUrl,
      driverWorkVisaDocumentUrl:
          driverWorkVisaDocumentUrl ?? this.driverWorkVisaDocumentUrl,
      driverLicenseDocumentUrl:
          driverLicenseDocumentUrl ?? this.driverLicenseDocumentUrl,
      driverIsSouthAfricanCitizen:
          driverIsSouthAfricanCitizen ?? this.driverIsSouthAfricanCitizen,
      companyId: companyId ?? this.companyId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FleetVehicle &&
        other.id == id &&
        other.vehicleRegistrationExpiryDate == vehicleRegistrationExpiryDate &&
        other.vehicleRegistrationNumber == vehicleRegistrationNumber &&
        other.vehicleMake == vehicleMake &&
        other.vehicleType == vehicleType &&
        other.vehicleYearModel == vehicleYearModel &&
        other.vehicleOdometerKm == vehicleOdometerKm &&
        other.firstTrailerRegs == firstTrailerRegs &&
        other.sealPoints == sealPoints &&
        other.secondTrailerRegs == secondTrailerRegs &&
        other.assignedDriverEmployeeId == assignedDriverEmployeeId &&
        other.driverUserId == driverUserId &&
        other.driverFirstName == driverFirstName &&
        other.driverLastName == driverLastName &&
        other.driverIdNumber == driverIdNumber &&
        other.driverPassportNumber == driverPassportNumber &&
        other.driverWorkPermit == driverWorkPermit &&
        other.driversLicenseDocument == driversLicenseDocument &&
        other.driverIdDocumentUrl == driverIdDocumentUrl &&
        other.driverPassportDocumentUrl == driverPassportDocumentUrl &&
        other.driverWorkVisaDocumentUrl == driverWorkVisaDocumentUrl &&
        other.driverLicenseDocumentUrl == driverLicenseDocumentUrl &&
        other.driverIsSouthAfricanCitizen == driverIsSouthAfricanCitizen &&
        other.companyId == companyId &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    // Object.hash has a limit of 20 arguments, so we need to combine some fields
    final driverDocuments = Object.hash(
      driverIdDocumentUrl,
      driverPassportDocumentUrl,
      driverWorkVisaDocumentUrl,
      driverLicenseDocumentUrl,
      driverIsSouthAfricanCitizen,
    );

    final vehicleIdentity = Object.hash(
      vehicleMake,
      vehicleType,
      vehicleYearModel,
      vehicleOdometerKm,
    );

    return Object.hash(
      id,
      vehicleRegistrationExpiryDate,
      vehicleRegistrationNumber,
      vehicleIdentity,
      firstTrailerRegs,
      secondTrailerRegs,
      assignedDriverEmployeeId,
      driverUserId,
      driverFirstName,
      driverLastName,
      driverIdNumber,
      driverPassportNumber,
      driverWorkPermit,
      driversLicenseDocument,
      driverDocuments, // Combined field
      companyId,
      createdAt,
      updatedAt,
      isActive,
    );
  }

  String? get assignedDriverId => assignedDriverEmployeeId;

  bool get hasAssignedDriver => assignedDriverEmployeeId != null;

  String get driverFullName {
    if (driverFirstName != null && driverLastName != null) {
      return '$driverFirstName $driverLastName';
    }
    return 'No driver assigned';
  }

  String get formattedExpiryDate {
    if (vehicleRegistrationExpiryDate == null) {
      return 'Not specified';
    }
    return '${vehicleRegistrationExpiryDate!.day}/${vehicleRegistrationExpiryDate!.month}/${vehicleRegistrationExpiryDate!.year}';
  }

  bool get hasVehicleDetails =>
      (vehicleMake != null && vehicleMake!.isNotEmpty) ||
      (vehicleType != null && vehicleType!.isNotEmpty) ||
      vehicleYearModel != null ||
      vehicleOdometerKm != null;

  /// Compact line for tables: "Opel · Astra J · 2018"
  String get vehicleIdentityLine {
    final parts = <String>[];
    if (vehicleMake != null && vehicleMake!.trim().isNotEmpty) {
      parts.add(vehicleMake!.trim());
    }
    if (vehicleType != null && vehicleType!.trim().isNotEmpty) {
      parts.add(vehicleType!.trim());
    }
    if (vehicleYearModel != null) {
      parts.add('${vehicleYearModel!}');
    }
    return parts.isEmpty ? '—' : parts.join(' · ');
  }

  String get formattedOdometer {
    if (vehicleOdometerKm == null) return '—';
    final s = vehicleOdometerKm.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '${buf.toString()} km';
  }
}
