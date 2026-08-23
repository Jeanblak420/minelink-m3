import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/layout/app_breakpoints.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/fleet_vehicle_model.dart';
import '../models/fleet_vehicle_status.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

class FleetVehicleTable extends StatelessWidget {
  final List<FleetVehicle> vehicles;

  /// The DERIVED fleet state per vehicle id, from `fleetStatusProvider`.
  ///
  /// ⚠ THE ROWS AND THE STAT CARDS ABOVE THEM MUST ANSWER THE SAME
  /// QUESTION. Until 2026-08-23 this table decided a truck's status from
  /// `assignedDriverId` — "Assigned" or "Unassigned" — while the four cards
  /// directly above it read `fleetStatusProvider`, and the comment beside
  /// those cards says in as many words that reading `hasAssignedDriver` "put
  /// every one of Roadhaul's three trucks in the WRONG bucket": the two
  /// carrying loads had no driver row and counted as available, while the one
  /// parked truck had a driver and counted as on trip.
  ///
  /// So the cards read `1 On route · 2 Available` and the rows underneath them
  /// read `Assigned · Assigned · Unassigned · Unassigned`, of the same four
  /// trucks, on the same screen. Availability in this product is derived
  /// server-side from active trips and open maintenance records (CLAUDE.md
  /// §4); whether anybody is rostered is a DIFFERENT fact, and it has its own
  /// column.
  ///
  /// Null while the read is in flight, which renders as "—" rather than as a
  /// confident wrong answer — the same choice the cards make.
  final Map<String, FleetVehicleStatus>? statusByVehicleId;

  final bool showDriver;
  final void Function(FleetVehicle vehicle)? onAssignDriver;
  final void Function(FleetVehicle vehicle)? onUnassignDriver;
  final void Function(FleetVehicle vehicle)? onEditVehicle;
  final void Function(FleetVehicle vehicle)? onRemoveVehicle;
  final void Function(FleetVehicle vehicle)? onReactivateVehicle;

  const FleetVehicleTable({
    super.key,
    required this.vehicles,
    this.statusByVehicleId,
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
                // A plate pill, like every other registration in the
                // product. `Flexible`, because a non-flex child of a Row is
                // laid out against unbounded width (CLAUDE.md §10.4) and the
                // pill's own ellipsis would never engage.
                Flexible(
                  child: MlPlatePill(vehicle.vehicleRegistrationNumber,
                      fontSize: 14),
                ),
                const SizedBox(width: 10),
                _statusBadge(vehicle),
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
            if (showDriver && _driversOf(vehicle) != null) ...[
              const SizedBox(height: 4),
              // Plural: a truck carries up to two drivers by default.
              _compactDetailRow('Drivers', _driversOf(vehicle)!),
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

  // THIS TABLE USED TO BE A MATERIAL `DataTable`, AND IT WAS THE LAST ONE.
  //
  // Transporter pass, 2026-08-23 (reviewer finding #5). It carried a filled
  // heading band (`headingRowColor: surfaceContainerHighest`) and bold
  // sans title-case heads, where every other register in this product draws
  // uppercase letter-spaced overline heads on a plain surface; it drew
  // registrations in plain sans while the same plates are `MlPlatePill`
  // everywhere else; and it used BOTH `-` and `—` for "empty", in the same
  // row — `—` for a missing odometer and `-` for a missing trailer, one cell
  // apart.
  //
  // ## Seventeen columns, and Status was the fifteenth
  //
  // The rebuild is not only a re-skin. At seventeen columns the table was
  // wider than a 1600px desktop, so the STATUS column — the whole subject of
  // the screen, and of the four cards above it — was off the right-hand edge
  // and had NEVER BEEN PHOTOGRAPHED. `screen-fleet-desktop-dark` shows the
  // register from Registration to `ID Doc` and stops.
  //
  // Two changes fix that without losing a single fact:
  //
  //  * **Status is second**, next to the identity it describes.
  //  * **The driver's four document links became one `Documents` cell.** They
  //    are four columns of the word "View Doc" — 360px of chrome to say
  //    nothing about which document is which — and they belong to a PERSON,
  //    not to the truck the row is about. As chips they name themselves (ID,
  //    Passport, Permit, Licence) and take one column.
  //
  // Thirteen columns, all of them on a laptop, and the table still scrolls
  // rather than compresses when the text is scaled — `MlColumn.minWidth` on
  // the three plate columns, which `_effectiveMinWidth` scales with the
  // reader's type size.
  /// The truck's derived fleet state, as the rest of the product draws a
  /// status: [MlStatusBadge], toned through the one shared status map.
  ///
  /// This replaced a hand-rolled solid-gradient pill that read
  /// Assigned / Unassigned / Inactive — a fourth status vocabulary, and the
  /// only one in the product that painted **RED for "Unassigned"**. A truck
  /// with no driver is not an error; it is the truck an admin allocates from.
  /// Red is this design system's declined/error tone (§5), so the register
  /// drew the fleet's most useful state in the colour reserved for its worst.
  ///
  /// The four states it draws now are the three derived ones plus Inactive,
  /// and they tone as transit / done / warn / neutral. `toneForStatus` could
  /// only tell them apart from 2026-08-23: `'on route'` matched nothing (it is
  /// not `'en route'`) and `'Inactive'` came out GREEN, because
  /// `"inactive".contains("active")` is true.
  Widget _statusBadge(FleetVehicle vehicle) {
    // Asked of the vehicle row, not of the derived feed: a truck taken out of
    // service is inactive whatever a stale status row says, and the inactive
    // table is built from vehicles the feed may not carry at all.
    if (!vehicle.isActive) return MlStatusBadge.forStatus('Inactive');

    final status = statusByVehicleId?[vehicle.id];
    // In flight. The cards say "—" here and so does this; a status is a claim
    // about a truck on a road, and there is nothing yet to claim.
    if (status == null) return const Text('—');

    if (status.inMaintenance) return MlStatusBadge.forStatus('In maintenance');
    if (status.onRoute) return MlStatusBadge.forStatus('On route');
    return MlStatusBadge.forStatus('Available');
  }

  Widget _buildWideTable(BuildContext context) {
    return MlCard(
      padding: const EdgeInsets.all(18),
      child: MlDataTable(
        // MEASURED BY RENDERING IT, not by arithmetic. The first draft kept
        // thirteen columns at `minWidth: 1180`, and the register at 1600px has
        // only ~1250px to lay them out in — so the table COMPRESSED instead of
        // scrolling and Flutter broke inside the words: the header read
        // `YEA / R`, a four-digit year rendered `202…`, `Freightliner` became
        // `Freightlin…` and the status pill itself read `IN MAINTENA…`.
        // Nothing overflowed — a wrapped cell is a cell that fits — so no
        // sweep would ever have caught it. Exactly the fault
        // `raw_recon_view.dart` documents at length for the recon table.
        //
        // The floor SCALES WITH THE TEXT, because a fixed pixel floor under a
        // user-controlled type size is the fault `MlDataTable._effectiveMinWidth`
        // was written about. The three plate columns and the status column
        // declare their own `minWidth`, which that method scales; this figure
        // is the floor for everything else.
        minWidth: 1180,
        columns: [
          const MlColumn('Registration',
              flex: 4, minWidth: kPlateColumnMinWidth),
          const MlColumn('Status', flex: 5, minWidth: 140),
          // ONE COLUMN, because make, type and year are one fact: what the
          // truck IS. Three columns of two words each cost ~90px of gutter and
          // heading to say what the compact card already says on one line as
          // `Freightliner · Interlink · 2021`.
          const MlColumn('Vehicle', flex: 4),
          // Flex 3, not 2. At 2 the head itself broke: `ODOMETE / R`, the
          // moment the actions column went to 184 and took the width back out
          // of the flex pool. A figure column is sized by its HEAD here, not
          // by its digits — `ODOMETER` is longer than `412 300`.
          const MlColumn('Odometer', flex: 3, align: TextAlign.right),
          const MlColumn('Disk expiry', flex: 3),
          // Likewise: a rig has trailers, and it usually has none or one. Two
          // 120px plate columns to hold, on average, half a plate.
          const MlColumn('Trailers', flex: 4, minWidth: kPlateColumnMinWidth),
          // ONE PERSON, ONE BLOCK: who is on the truck, their ID number, and
          // their documents. Those were four columns of the words "View Doc"
          // plus a name plus an ID — six columns and ~560px to describe a
          // PERSON, on a row whose subject is a TRUCK.
          //
          // "Drivers", plural: a truck carries up to two by default and five
          // with the super-admin's approval (CLAUDE.md §4), and the old
          // `Assigned Driver` column showed only the primary one — so the
          // second driver on a truck appeared nowhere in the register at all.
          if (showDriver) const MlColumn('Drivers', flex: 5),
          // 204 — MEASURED, not read off the code. Each of these buttons
          // declares `BoxConstraints(maxWidth: 40)` and RENDERS AT 48: an
          // IconButton keeps Material's 48px padded tap target whatever its
          // own constraints say, which is correct and is not what the number in
          // the source says. Four of them are 192, plus the cell's 12px right
          // gutter. At 168 and again at 184 the fourth button wrapped onto a
          // second row and took the whole row's height with it, on exactly the
          // two rows that have a driver to unassign.
          const MlColumn('', width: 204, align: TextAlign.right),
        ],
        rows: [
          for (final vehicle in vehicles)
            [
              MlPlatePill(vehicle.vehicleRegistrationNumber),
              _statusBadge(vehicle),
              _text(context, _describe(vehicle), maxLines: 2),
              _mono(
                context,
                vehicle.vehicleOdometerKm == null
                    ? null
                    : vehicle.formattedOdometer.replaceAll(' km', ''),
                align: TextAlign.right,
              ),
              _mono(
                context,
                vehicle.vehicleRegistrationExpiryDate == null
                    ? null
                    : DateFormat('yyyy-MM-dd')
                        .format(vehicle.vehicleRegistrationExpiryDate!),
              ),
              _trailers(context, vehicle),
              if (showDriver) _driverBlock(context, vehicle),
              _buildActionButtons(
                context,
                vehicle,
                Theme.of(context).colorScheme,
                vehicle.assignedDriverId != null,
              ),
            ],
        ],
      ),
    );
  }

  /// What the truck is: `Freightliner · Interlink · 2021`. The same sentence
  /// the compact card has always drawn, now in the wide table too.
  static String? _describe(FleetVehicle vehicle) {
    final parts = <String>[
      if (vehicle.vehicleMake != null && vehicle.vehicleMake!.trim().isNotEmpty)
        vehicle.vehicleMake!.trim(),
      if (vehicle.vehicleType != null && vehicle.vehicleType!.trim().isNotEmpty)
        vehicle.vehicleType!.trim(),
      if (vehicle.vehicleYearModel != null) '${vehicle.vehicleYearModel}',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  /// Both trailer plates, stacked. Most rigs have one or none.
  static Widget _trailers(BuildContext context, FleetVehicle vehicle) {
    final regs = <String>[
      if (vehicle.firstTrailerRegs != null &&
          vehicle.firstTrailerRegs!.trim().isNotEmpty)
        vehicle.firstTrailerRegs!.trim(),
      if (vehicle.secondTrailerRegs != null &&
          vehicle.secondTrailerRegs!.trim().isNotEmpty)
        vehicle.secondTrailerRegs!.trim(),
    ];
    if (regs.isEmpty) return _dash(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < regs.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          MlPlatePill(regs[i], fontSize: 12),
        ],
      ],
    );
  }

  /// Everybody rostered on the truck, or the primary driver if the derived
  /// feed has not arrived.
  String? _driversOf(FleetVehicle vehicle) {
    final derived = statusByVehicleId?[vehicle.id];
    if (derived != null && derived.hasDriver) return derived.drivers;
    return vehicle.assignedDriverId == null ? null : vehicle.driverFullName;
  }

  /// Who is on the truck, their ID number, and their documents — one block,
  /// because they are one person.
  Widget _driverBlock(BuildContext context, FleetVehicle vehicle) {
    final drivers = _driversOf(vehicle);
    final idNumber =
        vehicle.assignedDriverId == null ? null : vehicle.driverIdNumber;
    final documents = _documents(context, vehicle);
    if (drivers == null && idNumber == null) return _dash(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _text(context, drivers, maxLines: 2),
        if (idNumber != null && idNumber.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          _mono(context, idNumber),
        ],
        const SizedBox(height: 6),
        documents,
      ],
    );
  }

  /// The driver's documents, named. Four columns of "View Doc" said which
  /// document only by which column it was in, and three of those columns were
  /// off the edge of a 1600px screen.
  Widget _documents(BuildContext context, FleetVehicle vehicle) {
    if (vehicle.assignedDriverId == null) return _dash(context);
    final links = <(String, String)>[
      if (vehicle.driverIdDocumentUrl != null)
        ('ID', vehicle.driverIdDocumentUrl!),
      if (vehicle.driverPassportDocumentUrl != null)
        ('Passport', vehicle.driverPassportDocumentUrl!),
      if (vehicle.driverWorkVisaDocumentUrl != null)
        ('Permit', vehicle.driverWorkVisaDocumentUrl!),
      if (vehicle.driverLicenseDocumentUrl != null)
        ('Licence', vehicle.driverLicenseDocumentUrl!),
    ];
    if (links.isEmpty) return _dash(context);
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final (label, url) in links)
          MlButton.ghost(
            label: label,
            icon: Icons.description_outlined,
            compact: true,
            onPressed: () => _openDocumentUrl(context, url),
          ),
      ],
    );
  }

  /// ONE empty marker, an em dash. This file used `—` for a missing
  /// odometer and `-` for a missing trailer one cell to its right.
  static Widget _dash(BuildContext context) => Text(
        '\u2014',
        style: context.mlText.bodyMedium
            .copyWith(color: MlSemantic.of(context).textFaint),
      );

  static Widget _text(BuildContext context, String? value,
      {int maxLines = 1}) {
    final s = value?.trim();
    if (s == null || s.isEmpty) return _dash(context);
    return Text(
      s,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: context.mlText.bodyMedium
          .copyWith(color: MlSemantic.of(context).textBody),
    );
  }

  /// Years, odometers and ID numbers are CODES — figures read digit by digit
  /// and compared down a column — so they are set in the mono face, like every
  /// other figure in this product's tables.
  static Widget _mono(
    BuildContext context,
    String? value, {
    TextAlign align = TextAlign.left,
  }) {
    final s = value?.trim();
    if (s == null || s.isEmpty) return _dash(context);
    return Text(
      s,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.mlText.code(
        color: MlSemantic.of(context).textStrong,
        size: 13,
        weight: FontWeight.w600,
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
        // Offered whether or not a driver is already on the truck. The
        // dialog behind it manages UP TO `fleet_vehicles.max_drivers` (two by
        // default, five with the super-admin's approval) and is the only
        // place the second driver, or the "request more" path, can be added
        // from — and until 2026-08-23 it was only reachable while the truck
        // had NO driver, so the multi-driver rule in §4 had no entry point at
        // all once the first driver was assigned. Driven and measured: the
        // Fleet row offered Edit + Unassign, the Trucks-on-route card offered
        // nothing, and `DriverAssignmentDialog` could never show its
        // "1/2 drivers assigned" state from the UI.
        if (onAssignDriver != null && vehicle.isActive)
          IconButton(
            icon: Icon(
              isAssigned ? Icons.group_add_outlined : Icons.person_add,
              color: MlTokens.emerald500,
              size: 20,
            ),
            tooltip: isAssigned ? 'Manage drivers' : 'Assign driver',
            onPressed: () => onAssignDriver!(vehicle),
            constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
            padding: EdgeInsets.zero,
          ),
        if (isAssigned && onUnassignDriver != null && vehicle.isActive)
          IconButton(
            icon: const Icon(Icons.person_remove, color: MlTokens.red400, size: 20),
            tooltip: 'Unassign driver',
            onPressed: () => onUnassignDriver!(vehicle),
            constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
            padding: EdgeInsets.zero,
          ),
        if (onRemoveVehicle != null && vehicle.isActive)
          IconButton(
            icon: const Icon(Icons.delete, color: MlTokens.red600, size: 20),
            tooltip: 'Mark as inactive',
            onPressed: () => onRemoveVehicle!(vehicle),
            constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
            padding: EdgeInsets.zero,
          ),
        if (onReactivateVehicle != null && !vehicle.isActive)
          IconButton(
            icon: const Icon(Icons.restore, color: MlTokens.green600, size: 20),
            tooltip: 'Reactivate vehicle',
            onPressed: () => onReactivateVehicle!(vehicle),
            constraints: const BoxConstraints(maxWidth: 40, maxHeight: 40),
            padding: EdgeInsets.zero,
          ),
      ],
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
