import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/fleet/models/maintenance_record.dart';
import 'package:flutter_application_1/features/fleet/models/service_schedule.dart';
import 'package:flutter_application_1/features/fleet/services/maintenance_service.dart';

final maintenanceServiceProvider =
    Provider<MaintenanceService>((ref) => MaintenanceService());

/// Records + schedules for one company's fleet (Maintenance screen).
/// Invalidate after any open/close/schedule mutation — and invalidate
/// [fleetStatusProvider] too, since open out-of-service records change which
/// trucks are Available.
final fleetMaintenanceProvider = FutureProvider.family<
    ({List<MaintenanceRecord> records, List<ServiceSchedule> schedules}),
    String>((ref, companyId) {
  return ref.read(maintenanceServiceProvider).listFleetMaintenance(companyId);
});
