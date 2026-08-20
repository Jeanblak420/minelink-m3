import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/fleet/models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/features/fleet/models/vehicle_driver.dart';
import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/features/tabs/screens/driver_tab_screen.dart';

/// Fleet → **Drivers** for a transporter: who is on the books, which truck each
/// of them rides, and who is free to take the next load.
///
/// WHY THIS SCREEN EXISTS
/// ----------------------
/// `/portal/transporter/drivers` used to build `DriverTabScreen` — the
/// *personal* driver workspace. Opened by a transporter admin (driven live on
/// 2026-08-17 as `roadhaul.admin`) it rendered "Driver Workspace · View your
/// real driver assignment … Assignment: **None**, Documents: **0**" — the
/// admin's own non-existent driving job, under a Fleet heading, on a company
/// with three drivers and three trucks. There was nowhere in the product that
/// listed a transporter's drivers.
///
/// A driver who opens the same destination still gets their own workspace, so
/// nothing is taken away from them.
class TransporterDriversScreen extends ConsumerStatefulWidget {
  const TransporterDriversScreen({super.key});

  @override
  ConsumerState<TransporterDriversScreen> createState() =>
      _TransporterDriversScreenState();
}

class _TransporterDriversScreenState
    extends ConsumerState<TransporterDriversScreen> {
  @override
  void initState() {
    super.initState();
    // `FleetNotifier` loads its VEHICLES in its constructor but not its
    // drivers — `loadAvailableDrivers()` only ran after a mutation or a
    // realtime event. Opening this screen cold therefore showed the assigned
    // drivers (which come from `vehicleDriversProvider`) and an empty
    // "Not on a truck" list, i.e. "Everyone is rostered" for a company with an
    // unassigned driver sitting in it. Caught by rendering the screen, not by
    // reading it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final companyId = resolvePortalCompanyId(ref);
      if (companyId == null) return;
      ref.read(fleetProvider(companyId).notifier).loadAvailableDrivers();
    });
  }

  @override
  Widget build(BuildContext context) {
    final employee = ref.watch(employeeProvider).employee;
    final role = employee?.role;
    // A driver's Drivers page is their own workspace — that is the one reading
    // of this destination for which the old screen was right.
    if (role == UserRole.driver) return const DriverTabScreen();

    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) return const PortalCompanyRequired();

    final fleet = ref.watch(fleetProvider(companyId));
    final assignmentsAsync = ref.watch(vehicleDriversProvider(companyId));
    final statusAsync = ref.watch(fleetStatusProvider(companyId));

    if (assignmentsAsync.hasError) {
      return MlLoadFailure(
        subject: 'your drivers',
        error: assignmentsAsync.error!,
        onRetry: () => ref.invalidate(vehicleDriversProvider(companyId)),
      );
    }
    if (!assignmentsAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }

    final assigned = assignmentsAsync.requireValue;
    // "Available" here means what `getAvailableDrivers` means by it: an active
    // driver employee with no assignment row at all. Together the two lists are
    // every driver on the company's books, with no third query.
    final unassigned = fleet.availableDrivers;
    final onRoute = assigned.where((d) => d.onRoute).length;
    final total = assigned.length + unassigned.length;

    Future<void> refresh() async {
      ref.invalidate(vehicleDriversProvider(companyId));
      ref.invalidate(fleetStatusProvider(companyId));
      await ref.read(fleetProvider(companyId).notifier).loadAvailableDrivers();
    }

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Drivers',
            meta: mlCount(total, 'driver'),
            description: 'Everyone on your books, the truck they ride, and who '
                'is free for the next load.',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
                child: _Stat(
                    value: '$total',
                    label: 'Drivers',
                    tone: MlTone.neutral,
                    icon: Icons.badge_outlined)),
            const SizedBox(width: 12),
            Expanded(
                child: _Stat(
                    value: '$onRoute',
                    label: 'On route',
                    tone: MlTone.transit,
                    icon: Icons.local_shipping_outlined)),
            const SizedBox(width: 12),
            Expanded(
                child: _Stat(
                    value: '${assigned.length - onRoute + unassigned.length}',
                    label: 'Available',
                    tone: MlTone.done,
                    icon: Icons.how_to_reg_outlined)),
          ]),
          const SizedBox(height: 22),
          MlSectionTitle('On a truck',
              icon: Icons.link_rounded, meta: mlCount(assigned.length, 'driver')),
          if (assigned.isEmpty)
            MlCard(
              child: MlEmptyState(
                icon: Icons.person_off_outlined,
                title: 'No driver is on a truck.',
                message: 'Every truck you send out without one cannot report '
                    'its position or upload a proof of delivery.',
              ),
            )
          else
            MlCard(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                for (var i = 0; i < assigned.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: MlSemantic.of(context).divider),
                  _AssignedDriverTile(
                    driver: assigned[i],
                    companyId: companyId,
                    onDone: refresh,
                  ),
                ],
              ]),
            ),
          const SizedBox(height: 22),
          MlSectionTitle('Not on a truck',
              icon: Icons.person_search_outlined,
              meta: mlCount(unassigned.length, 'driver')),
          if (unassigned.isEmpty)
            MlCard(
              child: MlEmptyState(
                icon: Icons.check_circle_outline,
                title: 'Everyone is rostered.',
                message: 'Every active driver on your books is on a truck.',
              ),
            )
          else
            MlCard(
              padding: const EdgeInsets.all(8),
              child: Column(children: [
                for (var i = 0; i < unassigned.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, color: MlSemantic.of(context).divider),
                  _UnassignedDriverTile(
                    driver: unassigned[i],
                    companyId: companyId,
                    trucks: statusAsync.valueOrNull ?? const [],
                    onDone: refresh,
                  ),
                ],
              ]),
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final MlTone tone;
  final IconData icon;
  const _Stat(
      {required this.value,
      required this.label,
      required this.tone,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return MlCard(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        MlIconWell(icon: icon, tone: tone, size: 42, radius: 12),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.titleLarge.copyWith(
                    color: semantic.textStrong,
                    fontWeight: FontWeight.w800,
                  )),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.mlText.bodyMedium.copyWith(
                    color: semantic.textMuted,
                  )),
            ],
          ),
        ),
      ]),
    );
  }
}

class _AssignedDriverTile extends ConsumerStatefulWidget {
  final VehicleDriver driver;
  final String companyId;
  final Future<void> Function() onDone;
  const _AssignedDriverTile(
      {required this.driver, required this.companyId, required this.onDone});

  @override
  ConsumerState<_AssignedDriverTile> createState() =>
      _AssignedDriverTileState();
}

class _AssignedDriverTileState extends ConsumerState<_AssignedDriverTile> {
  bool _busy = false;

  Future<void> _remove() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Take this driver off the truck?'),
        content: Text(
          widget.driver.onRoute
              ? '${widget.driver.nameLabel} is ON ROUTE on '
                  '${widget.driver.registration}. Removing them now leaves that '
                  'load with nobody able to report its position or upload a '
                  'proof of delivery until you assign someone else.'
              : '${widget.driver.nameLabel} will come off '
                  '${widget.driver.registration} and become available for '
                  'another truck.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(c).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(c).pop(true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(fleetServiceProvider).removeVehicleDriver(
            vehicleId: widget.driver.vehicleId,
            driverEmployeeId: widget.driver.driverEmployeeId,
          );
      await widget.onDone();
      messenger.showSnackBar(SnackBar(
          content: Text('${widget.driver.nameLabel} removed from '
              '${widget.driver.registration}.')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not remove the driver. ${friendlyError(e)}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.driver;
    return ListTile(
      leading: MlIconWell(
          icon: Icons.person_rounded,
          tone: d.onRoute ? MlTone.transit : MlTone.done,
          size: 38,
          radius: 11),
      title: Text(d.nameLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Row(children: [
        MlPlatePill(d.registration, fontSize: 11),
        const SizedBox(width: 8),
        Flexible(
          child: MlStatusBadge.forStatus(
              d.onRoute ? 'Driver on route' : 'Available'),
        ),
      ]),
      trailing: _busy
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton.icon(
              onPressed: _remove,
              icon: const Icon(Icons.link_off_rounded, size: 16),
              label: const Text('Remove'),
            ),
    );
  }
}

class _UnassignedDriverTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> driver;
  final String companyId;
  final List<FleetVehicleStatus> trucks;
  final Future<void> Function() onDone;
  const _UnassignedDriverTile(
      {required this.driver,
      required this.companyId,
      required this.trucks,
      required this.onDone});

  @override
  ConsumerState<_UnassignedDriverTile> createState() =>
      _UnassignedDriverTileState();
}

class _UnassignedDriverTileState extends ConsumerState<_UnassignedDriverTile> {
  bool _busy = false;

  String get _name {
    final first = '${widget.driver['first_name'] ?? ''}'.trim();
    final last = '${widget.driver['last_name'] ?? ''}'.trim();
    final full = '$first $last'.trim();
    return full.isEmpty ? '${widget.driver['email'] ?? 'Driver'}' : full;
  }

  Future<void> _assign() async {
    final messenger = ScaffoldMessenger.of(context);
    // Only trucks with room. `add_vehicle_driver` enforces the same limit
    // server-side; offering a full truck here would just produce an error the
    // dispatcher could have been spared.
    final withRoom = widget.trucks
        .where((t) => t.isActive && t.driverCount < t.maxDrivers)
        .toList();
    if (withRoom.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Every active truck is already at its driver limit. '
              'Request an increase from the MineLink admin on the truck.')));
      return;
    }
    final vehicleId = await showDialog<String>(
      context: context,
      builder: (c) => SimpleDialog(
        title: Text('Put $_name on a truck'),
        children: [
          for (final t in withRoom)
            SimpleDialogOption(
              onPressed: () => Navigator.of(c).pop(t.vehicleId),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: MlPlatePill(t.registration, fontSize: 12),
                title: Text(t.driversLabel,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${t.driverCount}/${t.maxDrivers} drivers'
                    '${t.onRoute ? ' · on route now' : ''}'),
              ),
            ),
        ],
      ),
    );
    if (vehicleId == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(fleetServiceProvider).addVehicleDriver(
            vehicleId: vehicleId,
            driverEmployeeId: widget.driver['id'] as String,
          );
      await widget.onDone();
      messenger.showSnackBar(
          SnackBar(content: Text('$_name assigned. They have been notified '
              'with the collection details.')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not assign the driver. ${friendlyError(e)}')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const MlIconWell(
          icon: Icons.person_outline_rounded,
          tone: MlTone.neutral,
          size: 38,
          radius: 11),
      title: Text(_name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('No truck assigned',
          style: TextStyle(color: MlSemantic.of(context).textMuted)),
      trailing: _busy
          ? const SizedBox(
              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
          : TextButton.icon(
              onPressed: _assign,
              icon: const Icon(Icons.add_link_rounded, size: 16),
              label: const Text('Assign'),
            ),
    );
  }
}
