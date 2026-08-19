/// Represents a seat within an organization's seat allocation
class OrganizationSeat {
  final String id;
  final String organizationId;
  final int seatNumber;
  final String status; // available, occupied, disabled
  final String? occupiedByUserId;
  final String? occupiedByEmployeeId;
  final String? occupiedByName;
  final String? occupiedByEmail;
  final String? occupiedByEmployeeRole;
  /// Populated when seats are loaded with an `employees` embed.
  final String? employeeFirstName;
  final String? employeeLastName;
  final String? employeeWhatsapp;
  final String? employeeIdNumber;
  final String? employeeProfilePhotoUrl;
  /// The seat's serial — the unit the serial token sells. Every seat carries
  /// one from 2026-08-15; before that `generate_seat_serial` had zero callers
  /// and all 106 seats held null.
  final String? serialNumber;

  /// A seat may be pinned to one role. `reassign_seat` refuses an occupant
  /// whose role does not match.
  final String? roleBinding;

  final DateTime? assignedAt;
  final DateTime? releasedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrganizationSeat({
    required this.id,
    required this.organizationId,
    required this.seatNumber,
    required this.status,
    this.occupiedByUserId,
    this.occupiedByEmployeeId,
    this.occupiedByName,
    this.occupiedByEmail,
    this.occupiedByEmployeeRole,
    this.employeeFirstName,
    this.employeeLastName,
    this.employeeWhatsapp,
    this.employeeIdNumber,
    this.employeeProfilePhotoUrl,
    this.serialNumber,
    this.roleBinding,
    this.assignedAt,
    this.releasedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrganizationSeat.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? emp;
    final rawEmp = json['employees'];
    if (rawEmp is List && rawEmp.isNotEmpty && rawEmp.first is Map) {
      emp = Map<String, dynamic>.from(rawEmp.first as Map);
    } else if (rawEmp is Map) {
      emp = Map<String, dynamic>.from(rawEmp);
    }

    return OrganizationSeat(
      id: json['id'] as String,
      organizationId: json['organization_id'] as String,
      seatNumber: json['seat_number'] as int,
      status: json['status'] as String,
      occupiedByUserId: json['occupied_by_user_id'] as String?,
      occupiedByEmployeeId: json['occupied_by_employee_id'] as String?,
      occupiedByName: json['occupied_by_name'] as String?,
      occupiedByEmail: json['occupied_by_email'] as String?,
      occupiedByEmployeeRole: json['occupied_by_employee_role'] as String?,
      employeeFirstName: emp?['first_name'] as String?,
      employeeLastName: emp?['last_name'] as String?,
      employeeWhatsapp: emp?['whatsapp_number'] as String?,
      employeeIdNumber: emp?['id_number'] as String?,
      employeeProfilePhotoUrl: emp?['profile_photo_url'] as String?,
      serialNumber: json['serial_number'] as String?,
      roleBinding: json['role_binding'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
      releasedAt: json['released_at'] != null
          ? DateTime.parse(json['released_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isAvailable => status == 'available';
  bool get isOccupied => status == 'occupied';
  bool get isDisabled => status == 'disabled';
}
