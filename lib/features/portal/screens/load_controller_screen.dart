import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/models/mine_trip.dart';
import 'package:flutter_application_1/features/portal/services/trip_waybill_builder.dart';
import 'package:flutter_application_1/features/portal/services/waybill_pdf.dart';
import 'package:flutter_application_1/features/portal/models/workflow_notification.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/providers/lifecycle_provider.dart';
import 'package:flutter_application_1/features/portal/providers/workflow_notification_provider.dart';
import 'package:flutter_application_1/features/portal/services/lifecycle_service.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/photo_capture_field.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/features/profile/widgets/signature_required_prompt.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/widgets/premium_overview_widgets.dart'
    show formatTons;

/// Mine Control — the load controller's weighbridge + sealing desk on real
/// trips (ui_kits/mine-supplier MineControl). Search, KPI row, "Trucks at
/// Mine — Ready for Loading" with a Record Load slide-over (tare/gross with
/// scale photos, 4 seals with photos, wayslip), and Recent Loads. Recording
/// calls record_truck_load — the server advances the trip to loaded, deducts
/// the buyer's stockpile (FIFO) and seeds the recon.
class LoadControllerScreen extends ConsumerStatefulWidget {
  const LoadControllerScreen({super.key});

  @override
  ConsumerState<LoadControllerScreen> createState() =>
      _LoadControllerScreenState();
}

class _LoadControllerScreenState extends ConsumerState<LoadControllerScreen> {
  final _search = TextEditingController();
  String _query = '';
  bool _panelOpen = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openRecordPanel(String companyId, MineTrip trip) async {
    if (_panelOpen) return;
    _panelOpen = true;
    await showMlSlideOver<void>(
      context,
      title: 'Record Load — ${trip.reg}',
      width: 460,
      child: _RecordLoadSheet(companyId: companyId, trip: trip),
    );
    _panelOpen = false;
  }

  void _consumePending(String companyId, List<MineTrip> trips) {
    final pending = ref.watch(pendingSelectionProvider);
    if (pending == null || pending.tab != 'Controller') return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cur = ref.read(pendingSelectionProvider);
      if (cur == null || cur.tab != 'Controller') return;
      ref.read(pendingSelectionProvider.notifier).state = null;
      final t = trips
          .where((t) =>
              t.reg.toUpperCase() == cur.reg.toUpperCase() && t.isOnSite)
          .firstOrNull;
      if (t != null) {
        setState(() {
          _search.text = t.reg;
          _query = t.reg;
        });
        _openRecordPanel(companyId, t);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final async = ref.watch(mineInboundTripsProvider(companyId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlLoadFailure(
          subject: 'the weighbridge queue',
          error: e,
          onRetry: () => ref.invalidate(mineInboundTripsProvider(companyId)),
      ),
      data: (trips) {
        _consumePending(companyId, trips);
        final onSite = trips.where((t) => t.isOnSite).toList();
        final loaded = trips.where((t) => t.isLoaded).toList();
        final inbound = trips.where((t) => t.isInbound).toList();
        final q = _query.trim().toUpperCase();
        final matches = q.isEmpty
            ? onSite
            : onSite.where((t) => t.reg.toUpperCase().contains(q)).toList();
        final tonsRecorded = [
          for (final t in loaded)
            if (t.netTons != null && t.netTons! > 0) t.netTons!,
        ];
        final avgTons = tonsRecorded.isEmpty
            ? null
            : tonsRecorded.reduce((a, b) => a + b) / tonsRecorded.length;

        return MlPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlPageHeader(
                title: 'Mine Control',
                meta: '${mlCount(onSite.length, 'truck')} on site · '
                    '${loaded.length} loaded',
                description:
                    'Record loads and tonnage — weigh, seal and capture wayslip info for on-site trucks.',
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _search,
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search truck registration...',
                ),
              ),
              const SizedBox(height: 18),
              MlTileGrid.columns(
                columnsFor: (w) => w > 980 ? 4 : (w > 620 ? 2 : 1),
                children: [
                  MlStatCard(
                    label: 'Ready for Loading',
                    value: '${onSite.length}',
                    icon: Icons.local_shipping_outlined,
                    tone: MlTone.accent,
                  ),
                  MlStatCard(
                    label: 'Loads Recorded',
                    value: '${loaded.length}',
                    icon: Icons.description_outlined,
                    tone: MlTone.transit,
                  ),
                  MlStatCard(
                    label: 'Avg Tons / Load',
                    value: avgTons == null ? '—' : formatTons(avgTons),
                    // A mass metric, so a scale — not the clock this carried,
                    // which read as a duration (P8-26).
                    icon: Icons.scale_outlined,
                    tone: MlTone.done,
                  ),
                  MlStatCard(
                    label: 'Inbound Trucks',
                    value: '${inbound.length}',
                    icon: Icons.pending_actions_outlined,
                    tone: MlTone.atMine,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              MlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MlSectionTitle(
                      'Trucks at Mine — Ready for Loading',
                      icon: Icons.balance_outlined,
                      meta: mlCount(matches.length, 'truck'),
                    ),
                    if (matches.isEmpty)
                      MlEmptyState(
                        icon: Icons.local_shipping_outlined,
                        title: onSite.isEmpty
                            ? 'No trucks are on-site yet.'
                            : 'No on-site truck matches "$_query".',
                        message: onSite.isEmpty
                            ? 'Trucks appear here once security checks them in at the gate.'
                            : null,
                      )
                    else
                      Column(
                        children: [
                          for (var i = 0; i < matches.length; i++) ...[
                            if (i > 0) const SizedBox(height: 12),
                            _ReadyTruckRow(
                              trip: matches[i],
                              onRecord: () =>
                                  _openRecordPanel(companyId, matches[i]),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              MlCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MlSectionTitle('Recent Loads',
                        meta: avgTons == null
                            ? mlCount(loaded.length, 'load')
                            : '${mlCount(loaded.length, 'load')} · '
                                'avg ${avgTons.toStringAsFixed(2)} t'),
                    if (loaded.isEmpty)
                      MlEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No loads recorded yet.',
                        message:
                            'Confirmed loads appear here with tonnage and status.',
                      )
                    else
                      MlDataTable(
                        columns: const [
                          MlColumn('Truck Reg', flex: 3),
                          MlColumn('Client', flex: 3),
                          MlColumn('Material', flex: 3),
                          MlColumn('Tons', flex: 2, align: TextAlign.right),
                          MlColumn('Status', flex: 3, align: TextAlign.right),
                          MlColumn('Updated', flex: 2, align: TextAlign.right),
                        ],
                        rows: [
                          for (final t in loaded)
                            [
                              MlPlatePill(t.reg),
                              _cellText(context, t.buyerLabel, strong: true),
                              _cellText(context, t.materialLabel),
                              _monoText(context,
                                  t.netTons == null ? '—' : formatTons(t.netTons!)),
                              MlStatusBadge.forStatus(t.status.label),
                              _monoText(
                                  context,
                                  DateFormat.Hm()
                                      .format(MlTime.sast(t.updatedAt))),
                            ],
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }



  Widget _cellText(BuildContext context, String text, {bool strong = false}) {
    final semantic = MlSemantic.of(context);
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.mlText.titleSmall.copyWith(
        color: strong ? semantic.textStrong : semantic.textBody,
        fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }

  Widget _monoText(BuildContext context, String text) {
    return Text(
      text,
      maxLines: 1,
      style: context.mlText.code(
        color: MlSemantic.of(context).textMuted,
        size: 14,
        weight: FontWeight.w400,
      ),
    );
  }
}

/// One "ready for loading" row: identity well, plate, client/transporter/
/// material columns, status pill and the Record Load action.
class _ReadyTruckRow extends StatelessWidget {
  final MineTrip trip;
  final VoidCallback onRecord;

  const _ReadyTruckRow({required this.trip, required this.onRecord});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);

    Widget field(String label, String value, {bool strong = false}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: context.mlText.labelSmall.copyWith(
              color: semantic.textFaint,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.mlText.titleSmall.copyWith(
              color: strong ? semantic.textStrong : semantic.textBody,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: semantic.surfaceApp,
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        border: Border.all(color: semantic.borderCard),
      ),
      child: LayoutBuilder(builder: (context, c) {
        final narrow = c.maxWidth < 640;
        final identity = Row(
          children: [
            const MlIconWell(
                icon: Icons.local_shipping_outlined,
                tone: MlTone.transit,
                size: 48,
                radius: 12),
            const SizedBox(width: 14),
            MlPlatePill(trip.reg, fontSize: 14),
          ],
        );
        final fields = Wrap(
          spacing: 26,
          runSpacing: 10,
          children: [
            field('Client', trip.buyerLabel, strong: true),
            if (trip.transporterName != null)
              field('Transporter', trip.transporterName!),
            field('Material', trip.materialLabel),
          ],
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MlStatusBadge.forStatus(trip.status.label),
            const SizedBox(width: 12),
            MlButton.primary(
              label: 'Record Load',
              icon: Icons.inventory_2_outlined,
              compact: true,
              onPressed: onRecord,
            ),
          ],
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identity,
              const SizedBox(height: 12),
              fields,
              const SizedBox(height: 12),
              actions,
            ],
          );
        }
        return Row(
          children: [
            identity,
            const SizedBox(width: 18),
            Expanded(child: fields),
            actions,
          ],
        );
      }),
    );
  }
}

/// The Record Load slide-over: tare/gross weights with scale photos,
/// four seals with photos, wayslip info and the confirm action. Owns its
/// controllers so it survives parent rebuilds while open.
class _RecordLoadSheet extends ConsumerStatefulWidget {
  final String companyId;
  final MineTrip trip;

  const _RecordLoadSheet({required this.companyId, required this.trip});

  @override
  ConsumerState<_RecordLoadSheet> createState() => _RecordLoadSheetState();
}

class _RecordLoadSheetState extends ConsumerState<_RecordLoadSheet> {
  bool _saving = false;

  /// Why the last attempt was refused, shown inline above the confirm button.
  String? _error;
  final _empty = TextEditingController();
  final _loaded = TextEditingController();
  final _seals = List.generate(4, (_) => TextEditingController());
  final _wbNumber = TextEditingController();
  final _origin = TextEditingController();
  final _destination = TextEditingController();

  // Captured photos (evidence): tare + gross scale weighs and up to 4 seals.
  XFile? _tarePhoto;
  XFile? _grossPhoto;
  final List<XFile?> _sealPhotos = List<XFile?>.filled(4, null);

  @override
  void initState() {
    super.initState();
    // Waybill number is the shared transaction reference (§4) — not hand-typed.
    _wbNumber.text = widget.trip.reference ?? '';
    // ORIGIN/DESTINATION auto-fill from the route/transaction loading and
    // offloading points (§4).
    _origin.text = widget.trip.loadingPoint ?? '';
    _destination.text = widget.trip.offloadingPoint ?? '';
  }

  @override
  void dispose() {
    _empty.dispose();
    _loaded.dispose();
    for (final c in _seals) {
      c.dispose();
    }
    _wbNumber.dispose();
    _origin.dispose();
    _destination.dispose();
    super.dispose();
  }

  /// The cargo: the gross being typed now, less the tare already on the trip.
  ///
  /// The tare is read off the trip rather than off a field on this sheet,
  /// because it was captured at a different moment by `record_truck_tare`.
  /// The server recomputes this from the same two numbers before it commits —
  /// this copy is only so the controller can see the figure while typing.
  double? get _net {
    final tare = widget.trip.tareTons;
    final gross = double.tryParse(_loaded.text);
    if (tare == null || gross == null) return null;
    return gross - tare;
  }

  void _snack(String message) {
    // Every caller reaches here after an await, so the sheet may already be
    // gone; `ScaffoldMessenger.of` would then throw on a deactivated ancestor.
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// FIRST weigh: the empty truck, before it goes to load.
  ///
  /// Saved on its own, with its own timestamp, so the record can show that two
  /// weighs happened at two moments rather than one sheet filled in once.
  Future<void> _saveTare() async {
    final tare = double.tryParse(_empty.text.trim());
    if (tare == null || tare <= 0) {
      setState(() => _error = 'Enter the empty (tare) weight in tons.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final uploaded = <String>[];
    final lifecycle = ref.read(lifecycleServiceProvider);
    try {
      String? path;
      if (_tarePhoto != null) {
        path = await lifecycle.uploadLoadPhoto(
          companyId: widget.companyId,
          name: _tarePhoto!.name,
          bytes: await _tarePhoto!.readAsBytes(),
        );
        uploaded.add(path);
      }
      await lifecycle.recordTruckTare(
        tripId: widget.trip.tripId,
        tareTons: tare,
        tarePhotoPath: path,
      );
      ref.invalidateIfMounted(mineInboundTripsProvider(widget.companyId));
      if (mounted) {
        _snack('Empty weight saved for ${widget.trip.reg} — '
            '${tare.toStringAsFixed(2)} t. Weigh it again once it is loaded.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      await lifecycle.deletePhotos('load_photos', uploaded);
      if (mounted) {
        setState(() => _error = friendlyError(e));
        _snack('Could not save the empty weight. ${friendlyError(e)}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _save() async {
    final trip = widget.trip;
    final gross = double.tryParse(_loaded.text.trim());
    final net = _net;
    if (gross == null || net == null || net <= 0) {
      setState(() => _error = trip.tareTons == null
          ? 'Weigh the empty truck first.'
          : 'Enter a loaded weight above the empty weight of '
              '${trip.tareTons!.toStringAsFixed(2)} t.');
      return;
    }
    // Every seal the rig carries, before anything is uploaded.
    //
    // The server refuses this too (`record_truck_load` → `expected_seal_count`,
    // 20260817310000), and that refusal is the boundary that counts. This check
    // exists so the controller is told at the sheet — with the truck in front
    // of them and the seals in their hand — rather than after four photo
    // uploads and a round trip. It also names WHICH slot is short, which the
    // server cannot.
    if (trip.sealRequired) {
      final short = <int>[
        for (var i = 0; i < trip.expectedSeals; i++)
          if (_seals[i].text.trim().isEmpty || _sealPhotos[i] == null) i + 1,
      ];
      if (short.isNotEmpty) {
        setState(() => _error =
            'This load needs ${trip.expectedSeals} seals — the seal points '
            'recorded for this rig. Still missing a number or a photo on '
            '${short.length == 1 ? 'seal ${short.first}' : 'seals ${short.join(', ')}'}.');
        return;
      }
    }
    // S8-10. The waybill this load generates carries the load controller's
    // signature in its DISPATCHED BY block, and 3 of 116 profiles have one —
    // so without this the overwhelmingly likely outcome is a slip that prints
    // with an empty rule where the signature goes, and nothing anywhere says
    // so. Asked before the weights are committed, not after.
    final signature = await ensureSignatureBeforeSigning(
      context, ref,
      action: 'record this load',
      waybillBlock: 'DISPATCHED BY',
    );
    if (signature != SignaturePromptOutcome.proceedUnsigned &&
        signature != SignaturePromptOutcome.alreadySigned) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    // Track uploaded photos so a later failure doesn't orphan them in storage.
    final uploaded = <String>[];
    final lifecycle = ref.read(lifecycleServiceProvider);
    try {
      Future<String?> up(XFile? file) async {
        if (file == null) return null;
        final path = await lifecycle.uploadLoadPhoto(
          companyId: widget.companyId,
          name: file.name,
          bytes: await file.readAsBytes(),
        );
        uploaded.add(path);
        return path;
      }

      // Only the gross and seal photos are uploaded here — the tare photo was
      // captured at the first weigh and the server carries it onto the waybill.
      final grossPath = await up(_grossPhoto);
      // Bounded by what the rig needs, not by how many controllers exist. The
      // slots beyond `expectedSeals` are not rendered, so they are always
      // empty — sending them would depend on that staying true.
      final seals = <SealCapture>[];
      for (var i = 0; i < trip.expectedSeals && i < _seals.length; i++) {
        final number = _seals[i].text.trim();
        if (number.isEmpty) continue;
        seals.add(SealCapture(number: number, photoUrl: await up(_sealPhotos[i])));
      }

      await lifecycle.recordTruckLoad(
            tripId: trip.tripId,
            grossTons: gross,
            truckReg: trip.reg,
            seals: seals,
            waybill: {
              // waybill_number is set authoritatively server-side (= the
              // transaction reference, shared with recon).
              'origin': _origin.text.trim(),
              'destination': _destination.text.trim(),
              if (grossPath != null) 'gross_photo_path': grossPath,
            },
          );
      ref.invalidate(mineInboundTripsProvider(widget.companyId));
      ref.invalidate(stockpilesProvider(widget.companyId));
      ref.invalidate(stockpileLedgerDbProvider(widget.companyId));

      final notifier = ref.read(workflowNotificationProvider.notifier);
      notifier.push(
        targetRole: 'security',
        kind: WorkflowEvent.loadConfirmed,
        title: 'Load complete',
        body: '${trip.reg} loaded & sealed (${net.toStringAsFixed(2)} t). '
            'Ready to release.',
        tabLabel: 'Security',
        reg: trip.reg,
      );
      notifier.push(
        targetRole: 'mine',
        kind: WorkflowEvent.stockpileUpdated,
        title: 'Stockpile updated',
        body: '${net.toStringAsFixed(2)} t loaded for ${trip.buyerLabel} '
            '(truck ${trip.reg}).',
        tabLabel: 'Supervisor',
      );

      // The waybill is generated the moment Net Weight is known (§4). Build it
      // from the authoritative server copy (get_trip_waybill) so the number is
      // the assigned reference and the dispatch signature/name are consistent.
      final waybill = await buildTripWaybill(ref, trip.tripId);

      if (mounted) {
        _snack('Saved ${trip.reg}: ${net.toStringAsFixed(2)} t loaded. '
            'Stockpile deducted for ${trip.buyerLabel}.');
        Navigator.of(context).pop();
      }
      if (waybill != null) await WaybillPreviewer.preview(waybill);
    } catch (e) {
      // The load didn't record — remove the just-uploaded photos.
      await lifecycle.deletePhotos('load_photos', uploaded);
      if (mounted) {
        setState(() => _error = friendlyError(e));
        _snack('Could not record load. ${friendlyError(e)}');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final trip = widget.trip;
    final semantic = MlSemantic.of(context);

    if (trip.isLoaded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecordedBanner(trip: trip),
          const SizedBox(height: 16),
          MlButton.outline(
            label: 'Close',
            expand: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${trip.transporterName ?? 'Transporter'} · ${trip.buyerLabel} · ${trip.materialLabel}',
          style: context.mlText.bodyMedium.copyWith(
            color: semantic.textMuted,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 18),
        // TWO WEIGHS, TWO VISITS (Jean, 2026-08-17).
        //
        // The truck is weighed empty on arrival, goes and loads, and is weighed
        // again. This sheet used to ask for both figures at once and take them
        // in one submission, so nothing forced two visits and nothing recorded
        // that they happened — and the difference between those two numbers is
        // what the whole product bills on.
        //
        // Which half is shown is decided by the trip, not by local state: the
        // tare is on the record with its own timestamp before the truck leaves
        // the weighbridge, so reopening the sheet an hour later resumes exactly
        // where it was.
        if (!trip.isTareCaptured) ...[
          _Section(
            title: 'First weigh — empty truck',
            icon: Icons.scale_outlined,
            trailing: const MlStatusBadge(label: 'Step 1 of 2', tone: MlTone.atMine),
            child: Column(
              children: [
                _WeightRow(
                  label: 'Empty (tare)',
                  controller: _empty,
                  onChanged: () => setState(() {}),
                  photoLabel: 'Empty scale photo',
                  onPhoto: (f) => _tarePhoto = f,
                ),
                const SizedBox(height: 10),
                Text(
                  'Weigh the truck empty, then send it to load. You will weigh '
                  'it again when it comes back and the app works out the cargo.',
                  style: context.mlText.bodySmall.copyWith(
                    color: semantic.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ] else ...[
          _Section(
            title: 'Second weigh — loaded truck',
            icon: Icons.scale_outlined,
            trailing: const MlStatusBadge(label: 'Step 2 of 2', tone: MlTone.transit),
            child: Column(
              children: [
                _ReadOnly(
                  label: trip.loadingAt == null
                      ? 'Empty (tare) — first weigh'
                      : 'Empty (tare) — weighed '
                          '${DateFormat('HH:mm').format(trip.loadingAt!)}',
                  value: '${trip.tareTons!.toStringAsFixed(2)} t',
                ),
                const SizedBox(height: 12),
                _WeightRow(
                  label: 'Loaded (gross)',
                  controller: _loaded,
                  onChanged: () => setState(() {}),
                  photoLabel: 'Loaded scale photo',
                  onPhoto: (f) => _grossPhoto = f,
                ),
                const SizedBox(height: 12),
                _NetBox(net: _net),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (trip.isTareCaptured) ...[
        _Section(
          // The count is a stated fact about the vehicle
          // (`fleet_vehicles.seal_points`), not a constant and no longer a
          // guess. This heading used to read "Seals (2 per trailer · 4 total)"
          // whatever was hitched to the truck, and the server enforced only
          // "not zero" — so a two-trailer interlink was recorded with two seals
          // and another load with thirteen (measured 2026-08-17).
          title: 'Seals (${trip.expectedSeals} on this rig)',
          icon: Icons.lock_outline_rounded,
          trailing: trip.sealRequired
              ? const MlStatusBadge(label: 'Seals required', tone: MlTone.warn)
              : null,
          child: Column(
            children: [
              for (var i = 0; i < trip.expectedSeals; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                TextField(
                  controller: _seals[i],
                  decoration: InputDecoration(
                    isDense: true,
                    labelText: 'Seal ${i + 1} number',
                  ),
                ),
                const SizedBox(height: 8),
                PhotoCaptureField(
                  label: 'Seal ${i + 1} photo',
                  onChanged: (f) => _sealPhotos[i] = f,
                ),
              ],
              if (trip.sealRequired)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    'This route requires a photo of each seal & its number — '
                    "you can't complete the load without them.",
                    style: context.mlText.bodySmall.copyWith(
                      color: semantic.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Section(
          title: 'Wayslip info',
          icon: Icons.description_outlined,
          child: Column(
            children: [
              // Waybill number is the shared transaction reference (§4) —
              // auto-assigned, matches the recon WAYBILL NUMBER column.
              _ReadOnly(
                label: 'Waybill number (auto)',
                value: _wbNumber.text.isEmpty ? '—' : _wbNumber.text,
              ),
              const SizedBox(height: 12),
              _ReadOnly(label: 'Truck registration', value: trip.reg),
              const SizedBox(height: 12),
              _ReadOnly(
                  label: 'Transporter', value: trip.transporterName ?? '—'),
              const SizedBox(height: 12),
              _ReadOnly(label: 'Buyer', value: trip.buyerLabel),
              const SizedBox(height: 12),
              _ReadOnly(label: 'Material type', value: trip.materialLabel),
              const SizedBox(height: 12),
              TextField(
                controller: _origin,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Origin',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _destination,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Destination',
                ),
              ),
              const SizedBox(height: 12),
              _ReadOnly(
                label: 'Tons loaded (auto)',
                value: _net == null ? '—' : _net!.toStringAsFixed(2),
              ),
            ],
          ),
        ),
        ],
        const SizedBox(height: 18),
        // A refused load says why, right where the operator is looking.
        //
        // The catch below has always called `_snack`, but the sheet had no
        // Scaffold of its own, so the message went to the page's messenger
        // behind the barrier and was never drawn (fixed in `showMlSlideOver`).
        // A four-second snackbar is still the wrong shape for a load that will
        // not save: this states the reason and stays until the next attempt.
        if (_error != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MlTone.error.well(Theme.of(context).brightness),
              borderRadius: BorderRadius.circular(MlTokens.rMd),
              border: Border.all(
                color: MlTone.error
                    .colors(Theme.of(context).brightness)
                    .fg
                    .withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 18,
                    color:
                        MlTone.error.colors(Theme.of(context).brightness).fg),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: context.mlText.bodyMedium.copyWith(
                      color: MlTone.error.colors(Theme.of(context).brightness).fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        MlButton.go(
          label: _saving
              ? 'Saving…'
              : trip.isTareCaptured
                  ? 'Confirm load & deduct from stockpile'
                  : 'Save empty weight — truck goes to load',
          icon: trip.isTareCaptured
              ? Icons.check_circle_outline
              : Icons.scale_outlined,
          expand: true,
          onPressed: _saving
              ? null
              : (trip.isTareCaptured ? _save : _saveTare),
        ),
        const SizedBox(height: 10),
        MlButton.outline(
          label: 'Cancel',
          expand: true,
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

class _RecordedBanner extends StatelessWidget {
  final MineTrip trip;
  const _RecordedBanner({required this.trip});

  @override
  Widget build(BuildContext context) {
    final colors = MlTone.done.colors(Theme.of(context).brightness);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        border: Border.all(color: colors.fg.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline, color: colors.fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Load recorded — ${trip.netTons?.toStringAsFixed(2) ?? '—'} t '
              'deducted from ${trip.buyerLabel}\'s stockpile. '
              'Trip status: ${trip.status.label}.',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeightRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final String photoLabel;
  final ValueChanged<XFile?>? onPhoto;

  const _WeightRow({
    required this.label,
    required this.controller,
    required this.onChanged,
    required this.photoLabel,
    this.onPhoto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            isDense: true,
            labelText: '$label weight (t)',
            suffixText: 't',
          ),
        ),
        const SizedBox(height: 8),
        PhotoCaptureField(label: photoLabel, onChanged: onPhoto),
      ],
    );
  }
}

class _NetBox extends StatelessWidget {
  final double? net;
  const _NetBox({required this.net});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: PortalColors.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        border: Border.all(color: PortalColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.calculate_outlined, color: PortalColors.accent, size: 20),
          const SizedBox(width: 10),
          Text('Net minerals loaded',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant)),
          const Spacer(),
          Text(
            net == null ? '—' : '${net!.toStringAsFixed(2)} t',
            style: context.mlText.code(
              color: PortalColors.accent,
              size: 20,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _Section({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: semantic.surfaceApp,
        borderRadius: BorderRadius.circular(MlTokens.rLg),
        border: Border.all(color: semantic.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: PortalColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ReadOnly extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnly({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        isDense: true,
        labelText: label,
        filled: true,
        fillColor: scheme.surface,
      ),
      child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
