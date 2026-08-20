import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/features/fleet/providers/fleet_provider.dart';
import 'package:flutter_application_1/features/portal/models/fuel_models.dart';
import 'package:flutter_application_1/features/portal/services/fuel_service.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

final _num = NumberFormat('#,##0');
final _num1 = NumberFormat('#,##0.0');
final _dateFmt = DateFormat('dd MMM yyyy');

String money(double? v) => v == null ? '—' : 'R${_num.format(v)}';

/// Fuel & operating costs: log fills (litres/cost/odometer) and one-off costs
/// (tyres, tolls), see fuel spend, l/100km and cost/km per vehicle. These costs
/// flow into the Earnings net.
class FuelCostsScreen extends ConsumerWidget {
  const FuelCostsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final fuelAsync = ref.watch(fuelEntriesProvider(companyId));
    final costsAsync = ref.watch(operatingCostsProvider(companyId));
    final breakdown =
        ref.watch(vehicleCostBreakdownProvider(companyId)).asData?.value ??
        const <VehicleCostBreakdown>[];

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions live in MlPageHeader's own `actions` slot, not a Row wrapped
          // around it. That slot makes the title and the actions siblings in one
          // Wrap, so an action drops under the title when the row runs out of
          // width -- which it does on a phone, and at an accessibility text size
          // on a tablet. A Row gives an unflexed button unbounded width instead
          // (CLAUDE.md 10.4), and a button cannot ellipsize its way out: clamping
          // one truncates its hit target, not merely its label.
          MlPageHeader(
            title: 'Fuel & costs',
            meta: mlCount(
              breakdown.length,
              'vehicle costed',
              'vehicles costed',
            ),
            description:
                'Log fuel fills and running costs. Odometer readings give '
                'you l/100km and cost/km; every cost feeds your Earnings net.',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () {
                  ref.invalidate(fuelEntriesProvider(companyId));
                  ref.invalidate(operatingCostsProvider(companyId));
                  ref.invalidate(vehicleCostBreakdownProvider(companyId));
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
              MlButton.outline(
                label: 'Log cost',
                icon: Icons.receipt_outlined,
                compact: true,
                onPressed: () =>
                    showLogCostDialog(context, ref, companyId: companyId),
              ),
              MlButton.primary(
                label: 'Log fuel',
                icon: Icons.local_gas_station_outlined,
                compact: true,
                onPressed: () =>
                    showLogFuelDialog(context, ref, companyId: companyId),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _KpiRow(breakdown: breakdown),
          const SizedBox(height: 16),
          _EconomyCard(breakdown: breakdown),
          const SizedBox(height: 16),
          _FuelListCard(companyId: companyId, async: fuelAsync),
          const SizedBox(height: 16),
          _CostListCard(companyId: companyId, async: costsAsync),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _KpiRow extends StatelessWidget {
  final List<VehicleCostBreakdown> breakdown;
  const _KpiRow({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final fuel = breakdown.fold<double>(0, (s, b) => s + b.fuelCost);
    final litres = breakdown.fold<double>(0, (s, b) => s + b.fuelLitres);
    final tyresTolls = breakdown.fold<double>(
      0,
      (s, b) => s + b.tyreCost + b.tollCost,
    );
    // Distance-weighted fleet economy from vehicles that have it.
    double wDist = 0, wL = 0, wC = 0;
    for (final b in breakdown) {
      if ((b.distanceKm ?? 0) > 0 && b.lPer100km != null) {
        wDist += b.distanceKm!;
        wL += b.lPer100km! * b.distanceKm!;
        wC += (b.costPerKm ?? 0) * b.distanceKm!;
      }
    }
    final fleetL = wDist > 0 ? wL / wDist : null;
    final fleetCk = wDist > 0 ? wC / wDist : null;

    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth > 900 ? 5 : (c.maxWidth > 460 ? 2 : 1);
        const gap = 12.0;
        final w = (c.maxWidth - gap * (cols - 1)) / cols;
        final tiles = [
          MlStatCard(
            label: 'Fuel spend',
            value: money(fuel),
            icon: Icons.local_gas_station_outlined,
            tone: MlTone.warn,
          ),
          MlStatCard(
            label: 'Litres',
            value: _num.format(litres),
            icon: Icons.water_drop_outlined,
            tone: MlTone.transit,
          ),
          MlStatCard(
            label: 'Fleet l/100km',
            value: fleetL == null ? '—' : _num1.format(fleetL),
            icon: Icons.speed_outlined,
            tone: MlTone.accent,
          ),
          MlStatCard(
            label: 'Cost / km',
            value: fleetCk == null ? '—' : 'R${_num1.format(fleetCk)}',
            icon: Icons.route_outlined,
            tone: MlTone.neutral,
          ),
          MlStatCard(
            label: 'Tyres & tolls',
            value: money(tyresTolls),
            icon: Icons.tire_repair_outlined,
            tone: MlTone.neutral,
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

class _EconomyCard extends StatelessWidget {
  final List<VehicleCostBreakdown> breakdown;
  const _EconomyCard({required this.breakdown});

  Widget _mono(BuildContext c, String s, {bool strong = false}) => Text(
    s,
    textAlign: TextAlign.right,
    maxLines: 1,
    style: TextStyle(
      fontFamily: MlTokens.fontMono,
      fontSize: 13,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
      color: MlSemantic.of(c).textStrong,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final rows = [...breakdown]
      ..sort((a, b) => b.fuelCost.compareTo(a.fuelCost));
    return MlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlSectionTitle(
            'Per vehicle',
            icon: Icons.local_shipping_outlined,
            meta: mlCount(rows.length, 'vehicle'),
            margin: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const MlEmptyState(
              icon: Icons.local_gas_station_outlined,
              title: 'No costs logged yet',
              message: 'Log a fuel fill or a running cost to see economy here.',
            )
          else
            MlDataTable(
              columns: const [
                MlColumn('Vehicle', flex: 3),
                MlColumn('Litres', flex: 2, align: TextAlign.right),
                MlColumn('l/100km', flex: 2, align: TextAlign.right),
                MlColumn('Cost/km', flex: 2, align: TextAlign.right),
                MlColumn('Fuel', flex: 2, align: TextAlign.right),
                MlColumn('Maint.', flex: 2, align: TextAlign.right),
                MlColumn('Tyre/toll', flex: 2, align: TextAlign.right),
              ],
              rows: [
                for (final b in rows)
                  [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MlPlatePill(b.reg ?? 'Vehicle', fontSize: 12),
                    ),
                    _mono(context, _num.format(b.fuelLitres)),
                    _mono(
                      context,
                      b.lPer100km == null ? '—' : _num1.format(b.lPer100km),
                    ),
                    _mono(
                      context,
                      b.costPerKm == null
                          ? '—'
                          : 'R${_num1.format(b.costPerKm)}',
                    ),
                    _mono(context, money(b.fuelCost)),
                    _mono(context, money(b.maintenanceCost)),
                    _mono(
                      context,
                      money(b.tyreCost + b.tollCost + b.otherCost),
                    ),
                  ],
              ],
            ),
        ],
      ),
    );
  }
}

class _FuelListCard extends ConsumerWidget {
  final String companyId;
  final AsyncValue<List<FuelEntry>> async;
  const _FuelListCard({required this.companyId, required this.async});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    return MlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlSectionTitle(
            'Fuel fills',
            icon: Icons.local_gas_station_outlined,
            meta: async.valueOrNull == null
                ? null
                : mlCount(async.value!.length, 'fill'),
            margin: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Could not load fuel. ${friendlyError(e)}',
              style: TextStyle(color: semantic.textMuted),
            ),
            data: (fills) {
              if (fills.isEmpty) {
                return Text(
                  'No fuel logged yet.',
                  style: TextStyle(color: semantic.textMuted),
                );
              }
              return Column(
                children: [
                  for (final f in fills)
                    _Line(
                      plate: f.reg ?? 'Vehicle',
                      primary:
                          '${_num1.format(f.litres)} L · ${money(f.costZar)}'
                          '${f.pricePerLitre != null ? ' · R${_num1.format(f.pricePerLitre)}/L' : ''}',
                      secondary:
                          '${_dateFmt.format(MlTime.sast(f.filledAt))}'
                          '${f.odometerKm != null ? ' · ${_num.format(f.odometerKm)} km' : ''}'
                          '${f.station != null ? ' · ${f.station}' : ''}',
                      onDelete: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref.read(fuelServiceProvider).deleteFuel(f.id);
                          _refresh(ref, companyId);
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(friendlyError(e))),
                          );
                        }
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CostListCard extends ConsumerWidget {
  final String companyId;
  final AsyncValue<List<OperatingCost>> async;
  const _CostListCard({required this.companyId, required this.async});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    return MlCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlSectionTitle(
            'Running costs',
            icon: Icons.receipt_long_outlined,
            meta: async.valueOrNull == null
                ? null
                : mlCount(async.value!.length, 'entry', 'entries'),
            margin: EdgeInsets.zero,
          ),
          const SizedBox(height: 12),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text(
              'Could not load costs. ${friendlyError(e)}',
              style: TextStyle(color: semantic.textMuted),
            ),
            data: (costs) {
              if (costs.isEmpty) {
                return Text(
                  'No tyre/toll/other costs logged yet.',
                  style: TextStyle(color: semantic.textMuted),
                );
              }
              return Column(
                children: [
                  for (final c in costs)
                    _Line(
                      plate: c.reg ?? 'Vehicle',
                      primary: '${c.kind.label} · ${money(c.costZar)}',
                      secondary:
                          '${_dateFmt.format(MlTime.sast(c.incurredAt))}'
                          '${c.description != null ? ' · ${c.description}' : ''}',
                      onDelete: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await ref
                              .read(fuelServiceProvider)
                              .deleteOperatingCost(c.id);
                          _refresh(ref, companyId);
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(content: Text(friendlyError(e))),
                          );
                        }
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final String plate;
  final String primary;
  final String secondary;
  final VoidCallback onDelete;
  const _Line({
    required this.plate,
    required this.primary,
    required this.secondary,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          MlPlatePill(plate, fontSize: 11),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primary,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: semantic.textStrong,
                  ),
                ),
                Text(
                  secondary,
                  style: TextStyle(fontSize: 12.5, color: semantic.textMuted),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

void _refresh(WidgetRef ref, String companyId) {
  ref.invalidate(fuelEntriesProvider(companyId));
  ref.invalidate(operatingCostsProvider(companyId));
  ref.invalidate(vehicleCostBreakdownProvider(companyId));
}

/// Log a fuel fill. When [lockedVehicleId] is given (driver quick-log) the
/// vehicle is fixed and not selectable.
Future<void> showLogFuelDialog(
  BuildContext context,
  WidgetRef ref, {
  required String companyId,
  String? lockedVehicleId,
  String? lockedVehicleReg,
  String? tripId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _LogFuelDialog(
      companyId: companyId,
      lockedVehicleId: lockedVehicleId,
      lockedVehicleReg: lockedVehicleReg,
      tripId: tripId,
    ),
  );
}

class _LogFuelDialog extends ConsumerStatefulWidget {
  final String companyId;
  final String? lockedVehicleId;
  final String? lockedVehicleReg;
  final String? tripId;
  const _LogFuelDialog({
    required this.companyId,
    this.lockedVehicleId,
    this.lockedVehicleReg,
    this.tripId,
  });

  @override
  ConsumerState<_LogFuelDialog> createState() => _LogFuelDialogState();
}

class _LogFuelDialogState extends ConsumerState<_LogFuelDialog> {
  String? _vehicleId;
  final _litres = TextEditingController();
  final _cost = TextEditingController();
  final _odo = TextEditingController();
  final _station = TextEditingController();
  DateTime _when = DateTime.now();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _vehicleId = widget.lockedVehicleId;
  }

  @override
  void dispose() {
    _litres.dispose();
    _cost.dispose();
    _odo.dispose();
    _station.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final litres = double.tryParse(_litres.text.trim());
    final cost = double.tryParse(_cost.text.trim());
    if (_vehicleId == null) return _err('Choose a vehicle.');
    if (litres == null || litres <= 0) return _err('Enter the litres filled.');
    if (cost == null || cost < 0) return _err('Enter the rand cost.');
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(fuelServiceProvider)
          .logFuel(
            companyId: widget.companyId,
            vehicleId: _vehicleId!,
            litres: litres,
            costZar: cost,
            odometerKm: double.tryParse(_odo.text.trim()),
            station: _station.text.trim().isEmpty ? null : _station.text.trim(),
            tripId: widget.tripId,
            filledAt: _when,
          );
      _refresh(ref, widget.companyId);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Fuel logged.')));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(_clean(e))));
    }
  }

  void _err(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(fleetProvider(widget.companyId)).vehicles;
    final litres = double.tryParse(_litres.text.trim());
    final cost = double.tryParse(_cost.text.trim());
    final ppl = (litres != null && litres > 0 && cost != null)
        ? cost / litres
        : null;
    // Last recorded odometer for the chosen vehicle — used to show the distance
    // since the last fill and a live l/100km, so a wrong reading is obvious.
    final fills =
        ref.watch(fuelEntriesProvider(widget.companyId)).asData?.value ??
        const <FuelEntry>[];
    double? lastOdo;
    for (final f in fills) {
      if (f.vehicleId == _vehicleId && f.odometerKm != null) {
        if (lastOdo == null || f.odometerKm! > lastOdo) lastOdo = f.odometerKm;
      }
    }
    final odo = double.tryParse(_odo.text.trim());
    String? sinceLast;
    bool sinceLastWarn = false;
    if (lastOdo != null && odo != null) {
      if (odo < lastOdo) {
        sinceLast =
            'Lower than the last reading (${_num.format(lastOdo)} km) — check.';
        sinceLastWarn = true;
      } else {
        final dist = odo - lastOdo;
        sinceLast = '+${_num.format(dist)} km since last fill';
        if (litres != null && litres > 0 && dist > 0) {
          sinceLast =
              '$sinceLast · ≈ ${_num1.format(litres / (dist / 100))} l/100km';
        }
      }
    }
    return AlertDialog(
      title: const Text('Log fuel'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.lockedVehicleId != null)
                InputDecorator(
                  decoration: const InputDecoration(labelText: 'Vehicle'),
                  child: Text(widget.lockedVehicleReg ?? 'Your truck'),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _vehicleId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Vehicle'),
                  items: [
                    for (final v in vehicles)
                      DropdownMenuItem(
                        value: v.id,
                        child: Text(v.vehicleRegistrationNumber),
                      ),
                  ],
                  onChanged: _busy
                      ? null
                      : (v) => setState(() => _vehicleId = v),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _litres,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Litres',
                        suffixText: 'L',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _cost,
                      enabled: !_busy,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Cost',
                        prefixText: 'R',
                      ),
                    ),
                  ),
                ],
              ),
              if (ppl != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '≈ R${_num1.format(ppl)} / litre',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: MlSemantic.of(context).textMuted,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _odo,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Odometer (optional)',
                  helperText: lastOdo != null
                      ? 'Last: ${_num.format(lastOdo)} km'
                      : 'Needed for l/100km & cost/km',
                  suffixText: 'km',
                ),
              ),
              if (sinceLast != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    sinceLast,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: sinceLastWarn
                          ? MlTone.error.colors(Theme.of(context).brightness).fg
                          : MlSemantic.of(context).textMuted,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _station,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Station (optional)',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _busy
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _when,
                          firstDate: DateTime(now.year - 2),
                          lastDate: now,
                        );
                        if (p != null && mounted) setState(() => _when = p);
                      },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(_dateFmt.format(_when)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        MlButton.primary(
          label: _busy ? 'Saving…' : 'Log fuel',
          compact: true,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}

/// Log a one-off running cost (tyre / toll / other). Manager-only server-side.
Future<void> showLogCostDialog(
  BuildContext context,
  WidgetRef ref, {
  required String companyId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _LogCostDialog(companyId: companyId),
  );
}

class _LogCostDialog extends ConsumerStatefulWidget {
  final String companyId;
  const _LogCostDialog({required this.companyId});

  @override
  ConsumerState<_LogCostDialog> createState() => _LogCostDialogState();
}

class _LogCostDialogState extends ConsumerState<_LogCostDialog> {
  String? _vehicleId;
  OperatingCostKind _kind = OperatingCostKind.tyre;
  final _cost = TextEditingController();
  final _desc = TextEditingController();
  DateTime _when = DateTime.now();
  bool _busy = false;

  @override
  void dispose() {
    _cost.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final cost = double.tryParse(_cost.text.trim());
    if (_vehicleId == null) return _err('Choose a vehicle.');
    if (cost == null || cost < 0) return _err('Enter the rand cost.');
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(fuelServiceProvider)
          .logOperatingCost(
            companyId: widget.companyId,
            vehicleId: _vehicleId!,
            kind: _kind,
            costZar: cost,
            incurredAt: _when,
            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
          );
      _refresh(ref, widget.companyId);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Cost logged.')));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(_clean(e))));
    }
  }

  void _err(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(fleetProvider(widget.companyId)).vehicles;
    return AlertDialog(
      title: const Text('Log running cost'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _vehicleId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Vehicle'),
                items: [
                  for (final v in vehicles)
                    DropdownMenuItem(
                      value: v.id,
                      child: Text(v.vehicleRegistrationNumber),
                    ),
                ],
                onChanged: _busy ? null : (v) => setState(() => _vehicleId = v),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<OperatingCostKind>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Kind'),
                items: [
                  for (final k in OperatingCostKind.values)
                    DropdownMenuItem(value: k, child: Text(k.label)),
                ],
                onChanged: _busy
                    ? null
                    : (k) => setState(() => _kind = k ?? _kind),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _cost,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Cost',
                  prefixText: 'R',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                enabled: !_busy,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _busy
                    ? null
                    : () async {
                        final now = DateTime.now();
                        final p = await showDatePicker(
                          context: context,
                          initialDate: _when,
                          firstDate: DateTime(now.year - 2),
                          lastDate: now,
                        );
                        if (p != null && mounted) setState(() => _when = p);
                      },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                  ),
                  child: Text(_dateFmt.format(_when)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        MlButton.primary(
          label: _busy ? 'Saving…' : 'Log cost',
          compact: true,
          onPressed: _busy ? null : _save,
        ),
      ],
    );
  }
}

String _clean(Object e) {
  final s = e.toString();
  final m = RegExp(r'message: ([^,]+)').firstMatch(s);
  if (m != null) return m.group(1)!.trim();
  return s.replaceFirst('Exception: ', '');
}
