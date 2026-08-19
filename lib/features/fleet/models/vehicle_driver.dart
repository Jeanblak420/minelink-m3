/// One driver assigned to a truck (`driver_assignments` via
/// `list_vehicle_drivers`). Multi-driver per truck, CLAUDE.md §4: a driver
/// rides at most one truck; their On-Route status is derived from that
/// truck's active trip (shown red while on route).
class VehicleDriver {
  final String assignmentId;
  final String vehicleId;
  final String registration;
  final String driverEmployeeId;
  final String? driverName;
  final bool onRoute;
  final DateTime assignedAt;

  const VehicleDriver({
    required this.assignmentId,
    required this.vehicleId,
    required this.registration,
    required this.driverEmployeeId,
    required this.onRoute,
    required this.assignedAt,
    this.driverName,
  });

  String get nameLabel =>
      (driverName == null || driverName!.trim().isEmpty) ? '—' : driverName!;

  factory VehicleDriver.fromJson(Map<String, dynamic> j) => VehicleDriver(
    assignmentId: j['assignment_id'] as String,
    vehicleId: j['vehicle_id'] as String,
    registration: (j['registration'] as String?) ?? '—',
    driverEmployeeId: j['driver_employee_id'] as String,
    driverName: (j['driver_name'] as String?)?.trim(),
    onRoute: (j['on_route'] as bool?) ?? false,
    assignedAt: DateTime.parse(j['assigned_at'] as String),
  );
}

/// A transporter's request to raise a truck's driver limit (default 2, max 5),
/// decided by the super-admin (`driver_limit_requests`).
class DriverLimitRequest {
  final String id;
  final String companyId;
  final String? companyName;
  final String vehicleId;
  final String registration;
  final int currentLimit;
  final int requestedLimit;
  final String status; // pending | approved | declined
  final String? requestedByName;
  final DateTime createdAt;
  final DateTime? decidedAt;

  const DriverLimitRequest({
    required this.id,
    required this.companyId,
    required this.vehicleId,
    required this.registration,
    required this.currentLimit,
    required this.requestedLimit,
    required this.status,
    required this.createdAt,
    this.companyName,
    this.requestedByName,
    this.decidedAt,
  });

  bool get isPending => status == 'pending';

  factory DriverLimitRequest.fromJson(Map<String, dynamic> j) =>
      DriverLimitRequest(
        id: j['id'] as String,
        companyId: j['company_id'] as String,
        companyName: (j['company_name'] as String?)?.trim(),
        vehicleId: j['vehicle_id'] as String,
        registration: (j['registration'] as String?) ?? '—',
        currentLimit: (j['current_limit'] as num?)?.toInt() ?? 2,
        requestedLimit: (j['requested_limit'] as num?)?.toInt() ?? 0,
        status: (j['status'] as String?) ?? 'pending',
        requestedByName: (j['requested_by_name'] as String?)?.trim(),
        createdAt: DateTime.parse(j['created_at'] as String),
        decidedAt: j['decided_at'] == null
            ? null
            : DateTime.tryParse(j['decided_at'] as String),
      );
}
