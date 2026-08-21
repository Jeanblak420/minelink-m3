import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/features/fleet/models/vehicle_driver.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/utils/ml_count.dart';

/// Manage the drivers riding one truck (CLAUDE.md §4 driver-per-truck rule):
/// up to `fleet_vehicles.max_drivers` (default 2) drivers per vehicle, each
/// removable; at the cap the admin can ask the super-admin for an increase
/// (3–5). A driver already on another truck never appears in the add list.
class DriverAssignmentDialog extends ConsumerStatefulWidget {
  final FleetVehicle vehicle;
  final String companyId;

  const DriverAssignmentDialog({
    super.key,
    required this.vehicle,
    required this.companyId,
  });

  @override
  ConsumerState<DriverAssignmentDialog> createState() =>
      _DriverAssignmentDialogState();
}

class _DriverAssignmentDialogState
    extends ConsumerState<DriverAssignmentDialog> {
  bool _busy = false;
  bool _requestingLimit = false;
  int _requestedLimit = 3;

  void _refreshAll() {
    // Callers reach here after an await; the snackbar below each call site was
    // already `mounted`-guarded, but this refresh was not, and `ref` throws
    // once the dialog is gone.
    if (!mounted) return;
    ref.invalidate(vehicleDriversProvider(widget.companyId));
    ref.invalidate(fleetStatusProvider(widget.companyId));
    final notifier = ref.read(fleetProvider(widget.companyId).notifier);
    notifier.loadFleetVehicles();
    notifier.loadAvailableDrivers();
  }

  Future<void> _run(Future<void> Function() action, String doneMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(doneMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addDriver(String driverEmployeeId) {
    return _run(
      () => ref
          .read(fleetServiceProvider)
          .addVehicleDriver(
            vehicleId: widget.vehicle.id,
            driverEmployeeId: driverEmployeeId,
          ),
      'Driver added',
    );
  }

  Future<void> _removeDriver(VehicleDriver d) {
    return _run(
      () => ref
          .read(fleetServiceProvider)
          .removeVehicleDriver(
            vehicleId: widget.vehicle.id,
            driverEmployeeId: d.driverEmployeeId,
          ),
      'Driver removed',
    );
  }

  Future<void> _sendLimitRequest() {
    return _run(
      () => ref
          .read(fleetServiceProvider)
          .requestDriverLimit(
            vehicleId: widget.vehicle.id,
            newLimit: _requestedLimit,
          ),
      'Request sent to the MineLink admin',
    ).then((_) {
      if (mounted) setState(() => _requestingLimit = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fleetState = ref.watch(fleetProvider(widget.companyId));
    final driversAsync = ref.watch(vehicleDriversProvider(widget.companyId));
    final statusAsync = ref.watch(fleetStatusProvider(widget.companyId));

    final maxDrivers =
        statusAsync.valueOrNull
            ?.where((s) => s.vehicleId == widget.vehicle.id)
            .firstOrNull
            ?.maxDrivers ??
        2;

    return AlertDialog(
      title: Text('Drivers — ${widget.vehicle.vehicleRegistrationNumber}'),
      content: SizedBox(
        width: 440,
        child: driversAsync.when(
          loading: () => const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Text('Could not load drivers. ${friendlyError(e)}'),
          data: (all) {
            final assigned = all
                .where((d) => d.vehicleId == widget.vehicle.id)
                .toList();
            final atCap = assigned.length >= maxDrivers;

            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${assigned.length}/${mlCount(maxDrivers, 'driver')} assigned '
                    '(default 2 for long-distance; max 5).',
                    style: context.mlText.bodyMedium.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (assigned.isEmpty)
                    Text(
                      'No drivers on this truck yet.',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    )
                  else
                    for (final d in assigned)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          child: Text(d.nameLabel.substring(0, 1)),
                        ),
                        title: Text(d.nameLabel),
                        subtitle: d.onRoute
                            ? Text(
                                'DRIVER ON ROUTE',
                                style: context.mlText.labelSmall.copyWith(
                                  color: scheme.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : const Text('Available'),
                        trailing: IconButton(
                          tooltip: 'Remove from truck',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: _busy ? null : () => _removeDriver(d),
                        ),
                      ),
                  const Divider(height: 24),
                  if (atCap) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.5,
                        ),
                        borderRadius: MlShape.radiusMedium,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Driver limit reached for this truck.',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (!_requestingLimit)
                            OutlinedButton.icon(
                              onPressed: (_busy || maxDrivers >= 5)
                                  ? null
                                  : () => setState(() {
                                      _requestingLimit = true;
                                      _requestedLimit = maxDrivers + 1;
                                    }),
                              icon: const Icon(
                                Icons.add_moderator_outlined,
                                size: 18,
                              ),
                              label: Text(
                                maxDrivers >= 5
                                    ? 'Maximum of 5 drivers reached'
                                    : 'Request more drivers (up to 5)',
                              ),
                            )
                          else
                            // A Wrap, not a Row. Both children are unflexed and
                            // neither can ellipsize its way out of trouble — a
                            // clamped button truncates its hit target, not just
                            // its label — so at an accessibility text size in a
                            // dialog the only correct answer is for the button
                            // to drop onto its own line.
                            Wrap(
                              spacing: 10,
                              runSpacing: 8,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                // Capped rather than left to size itself: in a
                                // Wrap, `isExpanded` alone would claim the
                                // whole line and put the button below it at
                                // every width, not only the narrow ones.
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 160),
                                  child: DropdownButton<int>(
                                    value: _requestedLimit,
                                    isExpanded: true,
                                    items: [
                                      for (var n = maxDrivers + 1; n <= 5; n++)
                                        DropdownMenuItem(
                                          value: n,
                                          child: Text(mlCount(n, 'driver'),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                        ),
                                    ],
                                    onChanged: (v) => setState(
                                        () => _requestedLimit = v ?? 3),
                                  ),
                                ),
                                FilledButton(
                                  onPressed: _busy ? null : _sendLimitRequest,
                                  child: const Text('Send request'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'Add a driver:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    if (fleetState.isLoadingDrivers)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (fleetState.availableDrivers.isEmpty)
                      Text(
                        'No available drivers — every active driver is already '
                        'on a truck, or none have the "driver" role.',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      )
                    else
                      for (final driver in fleetState.availableDrivers)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: CircleAvatar(
                            radius: 16,
                            child: Text(
                              ('${driver['first_name'] ?? '?'}').substring(
                                0,
                                1,
                              ),
                            ),
                          ),
                          title: Text(
                            '${driver['first_name']} ${driver['last_name']}',
                          ),
                          subtitle: Text(
                            'ID: ${driver['id_number'] ?? 'Not specified'}',
                          ),
                          trailing: const Icon(Icons.person_add_alt_outlined),
                          onTap: _busy
                              ? null
                              : () => _addDriver(driver['id'] as String),
                        ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
