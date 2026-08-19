/// Recurring service plan for a fleet vehicle, backed by
/// `fleet_service_schedules` (spec 2026-07-17). Due by date and/or odometer;
/// completing a cycle logs a closed service record and rolls the schedule
/// forward by [repeatMonths] / [repeatKm] (one-off schedules deactivate).
library;

import 'package:flutter_application_1/core/time/ml_time.dart';

class ServiceSchedule {
  final String id;
  final String vehicleId;
  final String registration;

  /// Vehicle's current odometer (from fleet_vehicles), for due-by-km display.
  final int? vehicleOdometerKm;
  final String name;
  final DateTime? dueDate;
  final int? dueOdometerKm;
  final int? repeatMonths;
  final int? repeatKm;
  final int notifyDaysBefore;
  final bool active;
  final DateTime? lastDoneAt;

  const ServiceSchedule({
    required this.id,
    required this.vehicleId,
    required this.registration,
    required this.name,
    required this.notifyDaysBefore,
    required this.active,
    this.vehicleOdometerKm,
    this.dueDate,
    this.dueOdometerKm,
    this.repeatMonths,
    this.repeatKm,
    this.lastDoneAt,
  });

  /// Due (or inside the reminder window) right now — mirrors the server-side
  /// notify_service_due_job predicate so the screen and the notifications agree.
  bool get dueSoon {
    if (!active) return false;
    final now = DateTime.now();
    if (dueDate != null &&
        !dueDate!
            .subtract(Duration(days: notifyDaysBefore))
            .isAfter(now)) {
      return true;
    }
    if (dueOdometerKm != null &&
        vehicleOdometerKm != null &&
        vehicleOdometerKm! >= dueOdometerKm! - 500) {
      return true;
    }
    return false;
  }

  static DateTime? _date(dynamic v) =>
      v is String && v.isNotEmpty ? MlTime.sastOrNull(DateTime.tryParse(v)) : null;

  factory ServiceSchedule.fromJson(Map<String, dynamic> j) {
    return ServiceSchedule(
      id: j['id'] as String,
      vehicleId: j['vehicle_id'] as String,
      registration: (j['registration'] as String?) ?? '—',
      vehicleOdometerKm: (j['vehicle_odometer_km'] as num?)?.toInt(),
      name: (j['name'] as String?) ?? '',
      dueDate: _date(j['due_date']),
      dueOdometerKm: (j['due_odometer_km'] as num?)?.toInt(),
      repeatMonths: (j['repeat_months'] as num?)?.toInt(),
      repeatKm: (j['repeat_km'] as num?)?.toInt(),
      notifyDaysBefore: (j['notify_days_before'] as num?)?.toInt() ?? 7,
      active: (j['active'] as bool?) ?? true,
      lastDoneAt: _date(j['last_done_at']),
    );
  }
}
