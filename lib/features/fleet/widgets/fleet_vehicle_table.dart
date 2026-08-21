import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/layout/app_breakpoints.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/fleet_vehicle_model.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

class FleetVehicleTable extends StatelessWidget {
  final List<FleetVehicle> vehicles;
  final bool showDriver;
  final void Function(FleetVehicle vehicle)? onAssignDriver;
  final void Function(FleetVehicle vehicle)? onUnassignDriver;
  final void Function(FleetVehicle vehicle)? onEditVehicle;
  final void Function(FleetVehicle vehicle)? onRemoveVehicle;
  final void Function(FleetVehicle vehicle)? onReactivateVehicle;

  const FleetVehicleTable({
    super.key,
    required this.vehicles,
    this.showDriver = true,
    this.onAssignDriver,
    this.onUnassignDriver,
    this.onEditVehicle,
    this.onRemoveVehicle,
    this.onReactivateVehicle,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < AppBreakpoints.compactTableMax) {
          return _buildCompactList(context);
        }
        return _buildWideTable(context);
      },
    );
  }

  Widget _buildCompactList(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (vehicles.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        for (var i = 0; i < vehicles.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _buildCompactCard(context, vehicles[i], scheme),
        ],
      ],
    );
  }

  Widget _buildCompactCard(
    BuildContext context,
    FleetVehicle vehicle,
    ColorScheme scheme,
  ) {
    final isAssigned = vehicle.assignedDriverId != null;
    final details = <String>[
      if (vehicle.vehicleMake != null && vehicle.vehicleMake!.trim().isNotEmpty)
        vehicle.vehicleMake!.trim(),
      if (vehicle.vehicleType != null && vehicle.vehicleType!.trim().isNotEmpty)
        vehicle.vehicleType!.trim(),
      if (vehicle.vehicleYearModel != null)
        vehicle.vehicleYearModel.toString(),
    ].join(' · ');

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    vehicle.vehicleRegistrationNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                _statusChip(vehicle, isAssigned),
              ],
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                details,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 8),
            _compactDetailRow(
              'Odometer',
              vehicle.vehicleOdometerKm == null
                  ? '—'
                  : vehicle.formattedOdometer,
            ),
            _compactDetailRow(
              'Disk expiry',
              vehicle.vehicleRegistrationExpiryDate != null
                  ? DateFormat('yyyy-MM-dd')
                      .format(vehicle.vehicleRegistrationExpiryDate!)
                  : '—',
            ),
            if (vehicle.firstTrailerRegs != null &&
                vehicle.firstTrailerRegs!.isNotEmpty)
              _compactDetailRow('1st trailer', vehicle.firstTrailerRegs!),
            if (vehicle.secondTrailerRegs != null &&
                vehicle.secondTrailerRegs!.isNotEmpty)
              _compactDetailRow('2nd trailer', vehicle.secondTrailerRegs!),
            if (showDriver && isAssigned) ...[
              const SizedBox(height: 4),
              _compactDetailRow('Driver', vehicle.driverFullName),
            ],
            const SizedBox(height: 8),
            _buildActionButtons(context, vehicle, scheme, isAssigned),
          ],
        ),
      ),
    );
  }

  Widget _compactDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildWideTable(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ClipRRect(
        borderRadius: MlShape.radiusExtraLarge,
        // Thirteen columns do not fit a laptop and should not be truncated to
        // try — but a bare horizontal scroll view draws no bar, so what a
        // reader saw was "Passport Num…" cut off at the edge and no reason to
        // think there was anything past it.
        child: MlWideTable(
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              scheme.surfaceContainerHighest,
            ),
            dataRowColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return scheme.secondaryContainer.withAlpha(160);
              }
              return scheme.surface;
            }),
            columnSpacing: 16, // Reduced from 24 to save space
            horizontalMargin: 12, // Reduced from 16 to save space
            columns: [
              const DataColumn(
                label: SizedBox(
                  width: 108,
                  child: Text(
                    'Registration',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              _headerColumn('Make', 88),
              _headerColumn('Type', 96),
              _headerColumn('Year', 64),
              _headerColumn('Odometer', 96),
              const DataColumn(
                label: SizedBox(
                  width: 100,
                  child: Text(
                    'Disk expiry',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const DataColumn(
                label: SizedBox(
                  // A REGISTRATION, so it needs a registration's width.
                  //
                  // 80 cut `CK 85 RT GP` to `CK 85 RT …` at 1600px, in a table
                  // that already scrolls horizontally and had empty space to
                  // the right of it. A plate is the row's identity and the
                  // whole reason the column exists; `kPlateColumnMinWidth` is
                  // the measured figure and was named precisely so this stops
                  // being guessed per table.
                  width: kPlateColumnMinWidth,
                  child: Text(
                    '1st Trailer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const DataColumn(
                label: SizedBox(
                  width: kPlateColumnMinWidth,
                  child: Text(
                    '2nd Trailer',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              if (showDriver)
                const DataColumn(
                  label: SizedBox(
                    width: 120,
                    child: Text(
                      'Assigned Driver',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              if (showDriver)
                const DataColumn(
                  label: SizedBox(
                    width: 100,
                    child: Text(
                      'ID Number',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              if (showDriver)
                const DataColumn(
                  label: SizedBox(
                    width: 80,
                    child: Text(
                      'ID Doc',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              if (showDriver)
                const DataColumn(
                  label: SizedBox(
                    width: 100,
                    child: Text(
                      'Passport Number',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              if (showDriver)
                const DataColumn(
                  label: SizedBox(
                    width: 80,
                    child: Text(
                      'Passport Doc',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              if (showDriver)
                const DataColumn(
                  label: SizedBox(
                    width: 100,
                    child: Text(
                      'Work Permit Doc',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              if (showDriver)
                const DataColumn(
                  label: SizedBox(
                    width: 80,
                    child: Text(
                      'License Doc',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              const DataColumn(
                label: SizedBox(
                  width: 80,
                  child: Text(
                    'Status',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const DataColumn(
                label: SizedBox(
                  width: 80,
                  child: Text(
                    'Actions',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            rows: vehicles.map((vehicle) {
              final isAssigned = vehicle.assignedDriverId != null;
              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: 108,
                      child: Text(
                        vehicle.vehicleRegistrationNumber,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  DataCell(_cellText(vehicle.vehicleMake, width: 88)),
                  DataCell(_cellText(vehicle.vehicleType, width: 96)),
                  DataCell(
                    _cellText(
                      vehicle.vehicleYearModel?.toString(),
                      width: 64,
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 96,
                      child: Text(
                        vehicle.vehicleOdometerKm == null
                            ? '—'
                            : vehicle.formattedOdometer.replaceAll(' km', ''),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: 100,
                      child: Text(
                        vehicle.vehicleRegistrationExpiryDate != null
                            ? DateFormat(
                                'yyyy-MM-dd',
                              ).format(vehicle.vehicleRegistrationExpiryDate!)
                            : '—',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: kPlateColumnMinWidth,
                      child: Text(
                        vehicle.firstTrailerRegs ?? '-',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: kPlateColumnMinWidth,
                      child: Text(
                        vehicle.secondTrailerRegs ?? '-',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  if (showDriver)
                    DataCell(
                      SizedBox(
                        width: 120,
                        child: Text(
                          isAssigned ? vehicle.driverFullName : '-',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (showDriver)
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          isAssigned ? (vehicle.driverIdNumber ?? '-') : '-',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (showDriver)
                    DataCell(
                      SizedBox(
                        width: 80,
                        child: isAssigned && vehicle.driverIdDocumentUrl != null
                            ? TextButton(
                                onPressed: () {
                                  // Open the ID document URL in a browser
                                  _openDocumentUrl(
                                    context,
                                    vehicle.driverIdDocumentUrl!,
                                  );
                                },
                                child: const Text(
                                  'View Doc',
                                  style: TextStyle(color: MlTokens.accent),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : const Text('-'),
                      ),
                    ),
                  if (showDriver)
                    DataCell(
                      SizedBox(
                        width: 100,
                        child: Text(
                          isAssigned
                              ? (vehicle.driverPassportNumber ?? '-')
                              : '-',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (showDriver)
                    DataCell(
                      SizedBox(
                        width: 80,
                        child:
                            isAssigned &&
                                vehicle.driverPassportDocumentUrl != null
                            ? TextButton(
                                onPressed: () {
                                  // Open the passport document URL in a browser
                                  _openDocumentUrl(
                                    context,
                                    vehicle.driverPassportDocumentUrl!,
                                  );
                                },
                                child: const Text(
                                  'View Doc',
                                  style: TextStyle(color: MlTokens.accent),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : const Text('-'),
                      ),
                    ),
                  if (showDriver)
                    DataCell(
                      SizedBox(
                        width: 100,
                        child:
                            isAssigned &&
                                vehicle.driverWorkVisaDocumentUrl != null
                            ? TextButton(
                                onPressed: () {
                                  // Open the work visa document URL in a browser
                                  _openDocumentUrl(
                                    context,
                                    vehicle.driverWorkVisaDocumentUrl!,
                                  );
                                },
                                child: const Text(
                                  'View Doc',
                                  style: TextStyle(color: MlTokens.accent),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : const Text('-'),
                      ),
                    ),
                  if (showDriver)
                    DataCell(
                      SizedBox(
                        width: 80,
                        child:
                            isAssigned &&
                                vehicle.driverLicenseDocumentUrl != null
                            ? TextButton(
                                onPressed: () {
                                  // Open the license document URL in a browser
                                  _openDocumentUrl(
                                    context,
                                    vehicle.driverLicenseDocumentUrl!,
                                  );
                                },
                                child: const Text(
                                  'View Doc',
                                  style: TextStyle(color: MlTokens.accent),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                            : const Text('-'),
                      ),
                    ),
                  DataCell(_statusChip(vehicle, isAssigned)),
                  DataCell(
                    _buildActionButtons(context, vehicle, scheme, isAssigned),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _statusChip(FleetVehicle vehicle, bool isAssigned) {
    // Named once, so the fill and the ink chosen FOR that fill cannot end up
    // describing two different pills.
    final fill = !vehicle.isActive
        ? const [MlTokens.slate400, MlTokens.slate500]
        : isAssigned
            ? const [MlTokens.emerald400, MlTokens.emerald500]
            : const [MlTokens.red400, MlTokens.red500];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: MlShape.pill,
        gradient: LinearGradient(colors: fill),
      ),
      child: Text(
        !vehicle.isActive
            ? 'Inactive'
            : isAssigned
                ? 'Assigned'
                : 'Unassigned',
        style: TextStyle(
          // Measured against THIS pill's own gradient, not assumed white.
          // These are mid-saturation status hues and white lost on both of
          // the ones that matter: 2.09:1 on the emerald ("Assigned") and
          // 3.44:1 on the red ("Unassigned").
          color: MlTokens.inkOnFills(fill),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        textAlign: TextAlign.center,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    FleetVehicle vehicle,
    ColorScheme scheme,
    bool isAssigned,
  ) {
    return Wrap(
      spacing: 0,
      children: [
        if (onEditVehicle != null && vehicle.isActive)
          IconButton(
            icon: Icon(Icons.edit_outlined, color: scheme.primary, size: 20),
            tooltip: 'Edit vehicle details',
            onPressed: () => onEditVehicle!(vehicle),
            constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
            padding: EdgeInsets.zero,
          ),
        if (!isAssigned && onAssignDriver != null && vehicle.isActive)
          IconButton(
            icon: const Icon(Icons.person_add, color: MlTokens.emerald500, size: 20),
            tooltip: 'Assign Driver',
            onPressed: () => onAssignDriver!(vehicle),
            constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
            padding: EdgeInsets.zero,
          ),
        if (isAssigned && onUnassignDriver != null && vehicle.isActive)
          IconButton(
            icon: const Icon(Icons.person_remove, color: MlTokens.red400, size: 20),
            tooltip: 'Unassign Driver',
            onPressed: () => onUnassignDriver!(vehicle),
            constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
            padding: EdgeInsets.zero,
          ),
        if (onRemoveVehicle != null && vehicle.isActive)
          IconButton(
            icon: const Icon(Icons.delete, color: MlTokens.red600, size: 20),
            tooltip: 'Mark as Inactive',
            onPressed: () => onRemoveVehicle!(vehicle),
            constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
            padding: EdgeInsets.zero,
          ),
        if (onReactivateVehicle != null && !vehicle.isActive)
          IconButton(
            icon: const Icon(Icons.restore, color: MlTokens.green600, size: 20),
            tooltip: 'Reactivate Vehicle',
            onPressed: () => onReactivateVehicle!(vehicle),
            constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
            padding: EdgeInsets.zero,
          ),
      ],
    );
  }

  static DataColumn _headerColumn(String label, double width) {
    return DataColumn(
      label: SizedBox(
        width: width,
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  static Widget _cellText(String? value, {required double width}) {
    final display = (value == null || value.trim().isEmpty) ? '—' : value.trim();
    return SizedBox(
      width: width,
      child: Text(
        display,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  void _openDocumentUrl(BuildContext context, String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Show error if URL can't be launched
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open document: $url'),
            backgroundColor: MlTokens.red600,
          ),
        );
      }
    }
  }
}
