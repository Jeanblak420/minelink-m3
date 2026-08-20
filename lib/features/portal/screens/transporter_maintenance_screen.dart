import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/models/maintenance_record.dart';
import 'package:flutter_application_1/features/fleet/models/service_schedule.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/fleet/providers/maintenance_providers.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Transporter Maintenance & Downtime (spec 2026-07-17): log services,
/// repairs, breakdowns and inspections per vehicle; an open out-of-service
/// record removes the truck from the Available pool (server-enforced) and
/// "Mark fixed" is the single action that returns it. Service schedules
/// remind fleet managers by due date and/or odometer.
class TransporterMaintenanceScreen extends ConsumerWidget {
  const TransporterMaintenanceScreen({super.key});

  void _refresh(WidgetRef ref, String companyId) {
    // Every caller reaches here after an await, and this is a ConsumerWidget
    // with no `mounted` of its own — see `invalidateIfMounted`.
    ref.invalidateIfMounted(fleetMaintenanceProvider(companyId));
    // Open/closed out-of-service records change which trucks are Available.
    ref.invalidateIfMounted(fleetStatusProvider(companyId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final maintAsync = ref.watch(fleetMaintenanceProvider(companyId));
    final fleetAsync = ref.watch(fleetStatusProvider(companyId));

    return maintAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
          subject: 'the maintenance records',
          error: e,
          onRetry: () => ref.invalidate(fleetMaintenanceProvider(companyId)),
      ),
      data: (data) {
        final open =
            data.records.where((r) => r.isOpen).toList(growable: false);
        final closed =
            data.records.where((r) => !r.isOpen).toList(growable: false);
        final downCount = open.where((r) => r.takesOutOfService).length;
        final schedules = data.schedules;
        final dueSoon =
            schedules.where((s) => s.dueSoon).toList(growable: false);
        final fleet = fleetAsync.asData?.value ?? const <FleetVehicleStatus>[];

        return MlPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MlPageHeader(
                          title: 'Maintenance',
                          meta: '$downCount out of service · '
                              '${mlCount(dueSoon.length, 'service')} due soon',
                          description:
                              'Service schedules, breakdowns and vehicle downtime. '
                              'A truck in maintenance cannot be assigned to routes '
                              'until it is marked fixed.',
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: () => _refresh(ref, companyId),
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(builder: (context, c) {
                final cols = c.maxWidth > 620 ? 3 : 1;
                const gap = 14.0;
                final w = cols == 1
                    ? c.maxWidth
                    : (c.maxWidth - gap * (cols - 1)) / cols;
                final tiles = [
                  MlStatCard(
                    label: 'In maintenance',
                    value: '$downCount',
                    icon: Icons.build_circle_outlined,
                    tone: MlTone.warn,
                  ),
                  MlStatCard(
                    label: 'Open records',
                    value: '${open.length}',
                    icon: Icons.pending_actions_outlined,
                    tone: MlTone.atMine,
                  ),
                  MlStatCard(
                    label: 'Services due soon',
                    value: '${dueSoon.length}',
                    icon: Icons.schedule_outlined,
                    tone: dueSoon.isEmpty ? MlTone.done : MlTone.accent,
                  ),
                ];
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final t in tiles) SizedBox(width: w, child: t),
                  ],
                );
              }),
              const SizedBox(height: 20),
              MlSectionTitle(
                'Open maintenance',
                meta: '${mlCount(open.length, 'record')} · '
                    '$downCount out of service',
                icon: Icons.build_outlined,
                action: MlButton.primary(
                  label: 'Log maintenance',
                  icon: Icons.add_rounded,
                  compact: true,
                  onPressed: fleet.isEmpty
                      ? null
                      : () => _openRecordDialog(context, ref, companyId, fleet),
                ),
              ),
              if (open.isEmpty)
                MlCard(
                  child: const MlEmptyState(
                    icon: Icons.task_alt_outlined,
                    title: 'No open maintenance.',
                    message:
                        'Every truck is in service. Log a breakdown, repair, '
                        'service or inspection with "Log maintenance".',
                  ),
                )
              else
                for (final r in open) ...[
                  _OpenRecordCard(
                    record: r,
                    onClose: () =>
                        _closeRecordDialog(context, ref, companyId, r),
                  ),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 20),
              MlSectionTitle(
                'Service schedules',
                meta: '${mlCount(schedules.length, 'schedule')} · '
                    '${dueSoon.length} due soon',
                icon: Icons.event_repeat_outlined,
                action: MlButton.outline(
                  label: 'Add schedule',
                  icon: Icons.add_rounded,
                  compact: true,
                  onPressed: fleet.isEmpty
                      ? null
                      : () => _scheduleDialog(context, ref, companyId, fleet),
                ),
              ),
              if (schedules.isEmpty)
                MlCard(
                  child: const MlEmptyState(
                    icon: Icons.event_repeat_outlined,
                    title: 'No service schedules yet.',
                    message:
                        'Add a schedule per truck (by date and/or odometer) and '
                        'the fleet managers are reminded before it is due.',
                  ),
                )
              else
                for (final s in schedules) ...[
                  _ScheduleCard(
                    schedule: s,
                    onDone: () =>
                        _completeScheduleDialog(context, ref, companyId, s),
                    onEdit: () =>
                        _scheduleDialog(context, ref, companyId, fleet,
                            existing: s),
                    onToggleActive: () async {
                      await ref
                          .read(maintenanceServiceProvider)
                          .setScheduleActive(s.id, !s.active);
                      _refresh(ref, companyId);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              if (closed.isNotEmpty) ...[
                const SizedBox(height: 20),
                _HistorySection(records: closed),
              ],
            ],
          ),
        );
      },
    );
  }

  // ---- dialogs -------------------------------------------------------------

  Future<void> _openRecordDialog(BuildContext context, WidgetRef ref,
      String companyId, List<FleetVehicleStatus> fleet) async {
    final formKey = GlobalKey<FormState>();
    var vehicleId = fleet.first.vehicleId;
    var kind = MaintenanceKind.repair;
    var outOfService = true;
    final title = TextEditingController();
    final notes = TextEditingController();
    final cost = TextEditingController();
    final odo = TextEditingController();
    DateTime? expectedBack;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('Log maintenance'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: vehicleId,
                      decoration: const InputDecoration(labelText: 'Vehicle'),
                      items: [
                        for (final v in fleet)
                          DropdownMenuItem(
                            value: v.vehicleId,
                            child: Text(v.registration),
                          ),
                      ],
                      onChanged: (v) => vehicleId = v ?? vehicleId,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<MaintenanceKind>(
                      initialValue: kind,
                      decoration: const InputDecoration(labelText: 'Kind'),
                      items: [
                        for (final k in MaintenanceKind.values)
                          DropdownMenuItem(value: k, child: Text(k.label)),
                      ],
                      onChanged: (v) => kind = v ?? kind,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'What is wrong / being done? *',
                        hintText: 'e.g. Gearbox overhaul',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Give the record a title'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: outOfService,
                      onChanged: (v) => setState(() => outOfService = v),
                      title: const Text('Truck out of service'),
                      subtitle: const Text(
                          'Removes it from Available until marked fixed'),
                    ),
                    if (outOfService)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(expectedBack == null
                            ? 'Expected back (optional)'
                            : 'Expected back: '
                                '${MaterialLocalizations.of(ctx).formatMediumDate(expectedBack!)}'),
                        trailing: const Icon(Icons.calendar_month_outlined),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            firstDate: DateTime.now(),
                            lastDate:
                                MlTime.now().add(const Duration(days: 365)),
                            initialDate:
                                MlTime.now().add(const Duration(days: 2)),
                          );
                          if (picked != null && ctx.mounted) {
                            setState(() => expectedBack = picked);
                          }
                        },
                      ),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: cost,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Cost (R)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: odo,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Odometer (km)'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: notes,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const Text('Log maintenance'),
            ),
          ],
        );
      }),
    );

    if (saved != true || !context.mounted) return;
    try {
      await ref.read(maintenanceServiceProvider).openRecord(
            vehicleId: vehicleId,
            kind: kind,
            title: title.text.trim(),
            notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
            takesOutOfService: outOfService,
            expectedBackAt: expectedBack,
            costZar: double.tryParse(cost.text.trim()),
            odometerKm: int.tryParse(odo.text.trim()),
          );
      _refresh(ref, companyId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not log. ${friendlyError(e)}')));
      }
    }
  }

  Future<void> _closeRecordDialog(BuildContext context, WidgetRef ref,
      String companyId, MaintenanceRecord record) async {
    final notes = TextEditingController();
    final cost = TextEditingController(
        text: record.costZar == null ? '' : '${record.costZar}');
    final odo = TextEditingController(
        text: record.odometerKm == null ? '' : '${record.odometerKm}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
        title: const Text('Mark fixed — return to service'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(record.takesOutOfService
                  ? '${record.registration} goes straight back into the '
                      'Available pool and can be assigned to routes again.'
                  : 'Closes "${record.title}" on ${record.registration}.'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: cost,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Final cost (R)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: odo,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Odometer (km)'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(
                    labelText: 'Closing notes (optional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Mark fixed'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(maintenanceServiceProvider).closeRecord(
            record.id,
            notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
            costZar: double.tryParse(cost.text.trim()),
            odometerKm: int.tryParse(odo.text.trim()),
          );
      _refresh(ref, companyId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${record.registration} is back in service and available for routes.'),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not close. ${friendlyError(e)}')));
      }
    }
  }

  Future<void> _scheduleDialog(BuildContext context, WidgetRef ref,
      String companyId, List<FleetVehicleStatus> fleet,
      {ServiceSchedule? existing}) async {
    if (fleet.isEmpty && existing == null) return;
    final formKey = GlobalKey<FormState>();
    var vehicleId = existing?.vehicleId ??
        (fleet.isEmpty ? '' : fleet.first.vehicleId);
    final name = TextEditingController(text: existing?.name ?? '');
    final dueKm = TextEditingController(
        text:
            existing?.dueOdometerKm == null ? '' : '${existing!.dueOdometerKm}');
    final repMonths = TextEditingController(
        text:
            existing?.repeatMonths == null ? '' : '${existing!.repeatMonths}');
    final repKm = TextEditingController(
        text: existing?.repeatKm == null ? '' : '${existing!.repeatKm}');
    final notifyDays =
        TextEditingController(text: '${existing?.notifyDaysBefore ?? 7}');
    DateTime? dueDate = existing?.dueDate;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title:
              Text(existing == null ? 'Add service schedule' : 'Edit schedule'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (fleet.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue:
                            fleet.any((v) => v.vehicleId == vehicleId)
                                ? vehicleId
                                : fleet.first.vehicleId,
                        decoration:
                            const InputDecoration(labelText: 'Vehicle'),
                        items: [
                          for (final v in fleet)
                            DropdownMenuItem(
                              value: v.vehicleId,
                              child: Text(v.registration),
                            ),
                        ],
                        onChanged: (v) => vehicleId = v ?? vehicleId,
                      ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Schedule name *',
                        hintText: 'e.g. Minor service',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name the schedule'
                          : null,
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(dueDate == null
                          ? 'Due date (optional)'
                          : 'Due: '
                              '${MaterialLocalizations.of(ctx).formatMediumDate(dueDate!)}'),
                      trailing: dueDate == null
                          ? const Icon(Icons.calendar_month_outlined)
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => dueDate = null),
                            ),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365 * 3)),
                          initialDate: dueDate ??
                              MlTime.now().add(const Duration(days: 30)),
                        );
                        if (picked != null && ctx.mounted) {
                          setState(() => dueDate = picked);
                        }
                      },
                    ),
                    TextFormField(
                      controller: dueKm,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Due at odometer (km, optional)'),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: TextFormField(
                          controller: repMonths,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Repeat every (months)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: repKm,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Repeat every (km)'),
                        ),
                      ),
                    ]),
                    TextFormField(
                      controller: notifyDays,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Remind (days before due date)'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!(formKey.currentState?.validate() ?? false)) return;
                if (dueDate == null && dueKm.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                      content: Text('Set a due date and/or a due odometer.')));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(existing == null ? 'Add schedule' : 'Save'),
            ),
          ],
        );
      }),
    );

    if (saved != true || !context.mounted) return;
    try {
      await ref.read(maintenanceServiceProvider).upsertSchedule(
            vehicleId: vehicleId,
            name: name.text.trim(),
            dueDate: dueDate,
            dueOdometerKm: int.tryParse(dueKm.text.trim()),
            repeatMonths: int.tryParse(repMonths.text.trim()),
            repeatKm: int.tryParse(repKm.text.trim()),
            notifyDaysBefore: int.tryParse(notifyDays.text.trim()) ?? 7,
            scheduleId: existing?.id,
          );
      _refresh(ref, companyId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save. ${friendlyError(e)}')));
      }
    }
  }

  Future<void> _completeScheduleDialog(BuildContext context, WidgetRef ref,
      String companyId, ServiceSchedule s) async {
    final cost = TextEditingController();
    final odo = TextEditingController();
    final notes = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
        title: const Text('Log service done'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logs "${s.name}" as done for ${s.registration} and rolls '
                  'the schedule to its next due point.'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: cost,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Cost (R)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: odo,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Odometer (km)'),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              TextField(
                controller: notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log done'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(maintenanceServiceProvider).completeSchedule(
            s.id,
            costZar: double.tryParse(cost.text.trim()),
            odometerKm: int.tryParse(odo.text.trim()),
            notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
          );
      _refresh(ref, companyId);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not log. ${friendlyError(e)}')));
      }
    }
  }
}

MlTone _kindTone(MaintenanceKind kind) => switch (kind) {
      MaintenanceKind.breakdown => MlTone.error,
      MaintenanceKind.repair => MlTone.warn,
      MaintenanceKind.service => MlTone.accent,
      MaintenanceKind.inspection => MlTone.neutral,
    };

class _OpenRecordCard extends StatelessWidget {
  final MaintenanceRecord record;
  final VoidCallback onClose;

  const _OpenRecordCard({required this.record, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    return MlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MlPlatePill(record.registration),
              MlStatusBadge(
                  label: record.kind.label, tone: _kindTone(record.kind)),
              if (record.takesOutOfService)
                const MlStatusBadge(label: 'OUT OF SERVICE', tone: MlTone.warn)
              else
                const MlStatusBadge(label: 'IN SERVICE', tone: MlTone.done),
            ],
          ),
          const SizedBox(height: 10),
          Text(record.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            [
              if (record.startedAt != null)
                'Since ${loc.formatMediumDate(record.startedAt!)}',
              if (record.expectedBackAt != null)
                'expected back ${loc.formatMediumDate(record.expectedBackAt!)}',
              if (record.costZar != null)
                'R ${record.costZar!.toStringAsFixed(2)}',
              if (record.odometerKm != null) '${record.odometerKm} km',
            ].join(' · '),
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
          if (record.notes != null) ...[
            const SizedBox(height: 6),
            Text(record.notes!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: muted)),
          ],
          const SizedBox(height: 12),
          MlButton.go(
            label: 'Mark fixed — return to service',
            icon: Icons.task_alt_rounded,
            compact: true,
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final ServiceSchedule schedule;
  final VoidCallback onDone;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  const _ScheduleCard({
    required this.schedule,
    required this.onDone,
    required this.onEdit,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final s = schedule;
    return MlCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              MlPlatePill(s.registration),
              if (!s.active)
                const MlStatusBadge(label: 'PAUSED', tone: MlTone.neutral)
              else if (s.dueSoon)
                const MlStatusBadge(label: 'DUE SOON', tone: MlTone.warn)
              else
                const MlStatusBadge(label: 'SCHEDULED', tone: MlTone.done),
            ],
          ),
          const SizedBox(height: 10),
          Text(s.name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            [
              if (s.dueDate != null) 'Due ${loc.formatMediumDate(s.dueDate!)}',
              if (s.dueOdometerKm != null)
                'due at ${s.dueOdometerKm} km'
                    '${s.vehicleOdometerKm != null ? ' (now ${s.vehicleOdometerKm} km)' : ''}',
              if (s.repeatMonths != null) 'every ${s.repeatMonths} mo',
              if (s.repeatKm != null) 'every ${s.repeatKm} km',
              if (s.lastDoneAt != null)
                'last done ${loc.formatMediumDate(s.lastDoneAt!)}',
            ].join(' · '),
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (s.active)
                MlButton.primary(
                  label: 'Log service done',
                  icon: Icons.task_alt_rounded,
                  compact: true,
                  onPressed: onDone,
                ),
              MlButton.outline(
                label: 'Edit',
                icon: Icons.edit_outlined,
                compact: true,
                onPressed: onEdit,
              ),
              MlButton.ghost(
                label: s.active ? 'Pause' : 'Resume',
                icon: s.active
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
                compact: true,
                onPressed: onToggleActive,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistorySection extends StatefulWidget {
  final List<MaintenanceRecord> records;

  const _HistorySection({required this.records});

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final shown = _expanded ? widget.records : widget.records.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MlSectionTitle(
          // The count used to be part of the title. It belongs in the slot
          // built for it (S5-22), where it reads as data rather than as a
          // heading that happens to contain a number.
          'History — closed',
          meta: shown.length == widget.records.length
              ? mlCount(widget.records.length, 'record')
              : '${shown.length} of ${widget.records.length} shown',
          icon: Icons.history_rounded,
          action: widget.records.length > 5
              ? MlButton.ghost(
                  label: _expanded ? 'Show less' : 'Show all',
                  compact: true,
                  onPressed: () => setState(() => _expanded = !_expanded),
                )
              : null,
        ),
        MlCard(
          child: Column(
            children: [
              for (final r in shown)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      MlPlatePill(r.registration, fontSize: 11),
                      const SizedBox(width: 10),
                      MlStatusBadge(
                          label: r.kind.label, tone: _kindTone(r.kind)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          r.title,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        [
                          if (r.costZar != null)
                            'R ${r.costZar!.toStringAsFixed(0)}',
                          if (r.closedAt != null)
                            loc.formatMediumDate(r.closedAt!),
                        ].join(' · '),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
