import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/fleet/models/maintenance_record.dart';
import 'package:flutter_application_1/features/fleet/models/service_schedule.dart';

/// Everything the Maintenance module reads/writes goes through the
/// SECURITY DEFINER RPCs from migration 20260717120000 — never direct table
/// writes (RLS blocks them by design; spec 2026-07-17).
class MaintenanceService {
  final _client = SupabaseConfig.client;

  /// All maintenance records + service schedules for [companyId], newest and
  /// open-first, via `list_fleet_maintenance`.
  Future<({List<MaintenanceRecord> records, List<ServiceSchedule> schedules})>
      listFleetMaintenance(String companyId) async {
    final res = await _client.rpc(
      'list_fleet_maintenance',
      params: {'p_company_id': companyId},
    );
    final map = Map<String, dynamic>.from(res as Map);
    return (
      records: [
        for (final r in (map['records'] as List? ?? const []))
          MaintenanceRecord.fromJson(Map<String, dynamic>.from(r as Map))
      ],
      schedules: [
        for (final s in (map['schedules'] as List? ?? const []))
          ServiceSchedule.fromJson(Map<String, dynamic>.from(s as Map))
      ],
    );
  }

  /// Opens a record; when [takesOutOfService] the truck leaves the Available
  /// pool immediately and management is notified. Returns the record id.
  Future<String> openRecord({
    required String vehicleId,
    required MaintenanceKind kind,
    required String title,
    String? notes,
    bool takesOutOfService = true,
    DateTime? expectedBackAt,
    double? costZar,
    int? odometerKm,
  }) async {
    final id = await _client.rpc('open_maintenance_record', params: {
      'p_vehicle_id': vehicleId,
      'p_kind': kind.wire,
      'p_title': title,
      'p_notes': notes,
      'p_takes_out_of_service': takesOutOfService,
      'p_expected_back_at': expectedBackAt?.toUtc().toIso8601String(),
      'p_cost_zar': costZar,
      'p_odometer_km': odometerKm,
    });
    return id as String;
  }

  /// Marks the record fixed/closed — the truck is instantly Available again
  /// (availability is derived from open records; nothing else to reset).
  Future<void> closeRecord(
    String recordId, {
    String? notes,
    double? costZar,
    int? odometerKm,
  }) {
    return _client.rpc('close_maintenance_record', params: {
      'p_record_id': recordId,
      'p_notes': notes,
      'p_cost_zar': costZar,
      'p_odometer_km': odometerKm,
    });
  }

  /// Creates ([scheduleId] null) or edits a service schedule.
  Future<void> upsertSchedule({
    required String vehicleId,
    required String name,
    DateTime? dueDate,
    int? dueOdometerKm,
    int? repeatMonths,
    int? repeatKm,
    int notifyDaysBefore = 7,
    String? scheduleId,
  }) {
    return _client.rpc('upsert_service_schedule', params: {
      'p_vehicle_id': vehicleId,
      'p_name': name,
      'p_due_date': dueDate == null
          ? null
          : '${dueDate.year.toString().padLeft(4, '0')}-'
              '${dueDate.month.toString().padLeft(2, '0')}-'
              '${dueDate.day.toString().padLeft(2, '0')}',
      'p_due_odometer_km': dueOdometerKm,
      'p_repeat_months': repeatMonths,
      'p_repeat_km': repeatKm,
      'p_notify_days_before': notifyDaysBefore,
      'p_schedule_id': scheduleId,
    });
  }

  Future<void> setScheduleActive(String scheduleId, bool active) {
    return _client.rpc('set_service_schedule_active', params: {
      'p_schedule_id': scheduleId,
      'p_active': active,
    });
  }

  /// Logs the service as done (a closed record) and rolls the schedule
  /// forward; one-off schedules deactivate.
  Future<void> completeSchedule(
    String scheduleId, {
    double? costZar,
    int? odometerKm,
    String? notes,
  }) {
    return _client.rpc('complete_service_schedule', params: {
      'p_schedule_id': scheduleId,
      'p_cost_zar': costZar,
      'p_odometer_km': odometerKm,
      'p_notes': notes,
    });
  }
}
