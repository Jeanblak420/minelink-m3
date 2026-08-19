/// Fleet maintenance/downtime record, backed by `fleet_maintenance_records`
/// (spec docs/superpowers/specs/2026-07-17-fleet-maintenance-design.md).
///
/// A record with [takesOutOfService] keeps its truck out of the Available pool
/// while [status] is open; closing it is the only step needed to return the
/// truck to service (availability is derived server-side, never a stale flag).
library;

import 'package:flutter_application_1/core/time/ml_time.dart';

/// What kind of maintenance event this is. Wire strings match the DB check
/// constraint; [parse] is tolerant per the house enum pattern.
enum MaintenanceKind {
  service('service', 'Service'),
  repair('repair', 'Repair'),
  breakdown('breakdown', 'Breakdown'),
  inspection('inspection', 'Inspection');

  const MaintenanceKind(this.wire, this.label);

  final String wire;
  final String label;

  static MaintenanceKind parse(String? value) {
    for (final k in MaintenanceKind.values) {
      if (k.wire == value) return k;
    }
    return MaintenanceKind.repair;
  }
}

/// Open → closed lifecycle of a maintenance record.
enum MaintenanceStatus {
  open('open', 'Open'),
  closed('closed', 'Closed');

  const MaintenanceStatus(this.wire, this.label);

  final String wire;
  final String label;

  static MaintenanceStatus parse(String? value) {
    for (final s in MaintenanceStatus.values) {
      if (s.wire == value) return s;
    }
    return MaintenanceStatus.closed;
  }
}

class MaintenanceRecord {
  final String id;
  final String vehicleId;
  final String registration;
  final MaintenanceKind kind;
  final String title;
  final String? notes;
  final MaintenanceStatus status;
  final bool takesOutOfService;
  final DateTime? startedAt;
  final DateTime? expectedBackAt;
  final DateTime? closedAt;
  final double? costZar;
  final int? odometerKm;

  const MaintenanceRecord({
    required this.id,
    required this.vehicleId,
    required this.registration,
    required this.kind,
    required this.title,
    required this.status,
    required this.takesOutOfService,
    this.notes,
    this.startedAt,
    this.expectedBackAt,
    this.closedAt,
    this.costZar,
    this.odometerKm,
  });

  bool get isOpen => status == MaintenanceStatus.open;

  /// Whether this record is currently keeping its truck out of service.
  bool get blocksAssignment => isOpen && takesOutOfService;

  static DateTime? _date(dynamic v) =>
      v is String && v.isNotEmpty ? MlTime.sastOrNull(DateTime.tryParse(v)) : null;

  factory MaintenanceRecord.fromJson(Map<String, dynamic> j) {
    return MaintenanceRecord(
      id: j['id'] as String,
      vehicleId: j['vehicle_id'] as String,
      registration: (j['registration'] as String?) ?? '—',
      kind: MaintenanceKind.parse(j['kind'] as String?),
      title: (j['title'] as String?) ?? '',
      notes: (j['notes'] as String?)?.trim().isEmpty ?? true
          ? null
          : (j['notes'] as String).trim(),
      status: MaintenanceStatus.parse(j['status'] as String?),
      takesOutOfService: (j['takes_out_of_service'] as bool?) ?? true,
      startedAt: _date(j['started_at']),
      expectedBackAt: _date(j['expected_back_at']),
      closedAt: _date(j['closed_at']),
      costZar: (j['cost_zar'] as num?)?.toDouble(),
      odometerKm: (j['odometer_km'] as num?)?.toInt(),
    );
  }
}
