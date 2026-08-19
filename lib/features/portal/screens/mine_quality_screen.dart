import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/load_quality.dart';
import 'package:flutter_application_1/features/portal/services/quality_service.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/load_quality_table.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/design/components/ml_page_body.dart';
import 'package:flutter_application_1/core/design/components/ml_page_header.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Mine/Supplier "Quality" screen (CLAUDE.md §4 quality certificates):
///  - the contract quality spec per route (target Cr₂O₃ %, max moisture %,
///    sizing) — the yardstick every load is judged against;
///  - the per-load certificate table where the mine attaches each delivered
///    load's lab certificate and sees the payable-tons penalty calc.
class MineQualityScreen extends ConsumerWidget {
  const MineQualityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    final specsAsync = ref.watch(supplierRouteSpecsProvider(companyId));
    final semantic = MlSemantic.of(context);

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Quality',
            meta: specsAsync.valueOrNull == null
                ? null
                : mlCount(specsAsync.value!.length, 'route spec'),
            description:
                'Set the contract quality spec per route, then certify each '
                'delivered load — Cr₂O₃ %, moisture % and sizing, with the lab '
                'PDF attached to the load itself. Excess moisture and low grade '
                'reduce the payable tons automatically.',
          ),

          // Contract specs per route.
          MlCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MlSectionTitle(
                        'Contract quality specs',
                        meta: specsAsync.valueOrNull == null
                            ? null
                            : mlCount(specsAsync.value!.length, 'route'),
                        icon: Icons.rule_outlined,
                        margin: EdgeInsets.zero,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: () => ref
                          .invalidate(supplierRouteSpecsProvider(companyId)),
                      icon: const Icon(Icons.refresh_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'One spec per Route ID. Loads on the route are judged '
                  'against these values.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: semantic.textMuted),
                ),
                const SizedBox(height: 12),
                specsAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) => Text('Could not load routes. ${friendlyError(e)}',
                      style: TextStyle(color: semantic.textMuted)),
                  data: (specs) {
                    if (specs.isEmpty) {
                      return MlEmptyState(
                        icon: Icons.rule_outlined,
                        title: 'No routes yet.',
                        message:
                            'Routes appear here once the MineLink admin links '
                            'an order to this mine.',
                      );
                    }
                    return Column(
                      children: [
                        for (final s in specs)
                          _RouteSpecTile(spec: s, companyId: companyId),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Per-load certificates (editable for the mine).
          LoadQualityTable(
            companyId: companyId,
            canEdit: true,
            supplierCompanyId: companyId,
          ),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

class _RouteSpecTile extends ConsumerWidget {
  final RouteQualitySpec spec;
  final String companyId;
  const _RouteSpecTile({required this.spec, required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: semantic.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  spec.routeNumber ?? 'Route',
                  style: TextStyle(
                    fontFamily: MlTokens.fontMono,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: semantic.textStrong,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  [
                    if (spec.commodity != null) spec.commodity!,
                    if (spec.offloadingPoint != null)
                      '→ ${spec.offloadingPoint!}',
                  ].join(' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: semantic.textMuted),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              spec.hasSpec
                  ? [
                      if (spec.specCr2o3Pct != null)
                        'Cr₂O₃ ≥ ${spec.specCr2o3Pct}%',
                      if (spec.specMoistureMaxPct != null)
                        'moisture ≤ ${spec.specMoistureMaxPct}%',
                      if (spec.specSizing != null)
                        'sizing ${spec.specSizing}',
                    ].join(' · ')
                  : 'No spec set — loads on this route are not penalised.',
              style: TextStyle(
                fontSize: 12.5,
                color:
                    spec.hasSpec ? semantic.textBody : semantic.textFaint,
              ),
            ),
          ),
          MlButton.ghost(
            label: spec.hasSpec ? 'Edit spec' : 'Set spec',
            icon: Icons.tune_rounded,
            compact: true,
            onPressed: () => _editSpec(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _editSpec(BuildContext context, WidgetRef ref) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SpecDialog(spec: spec),
    );
    if (saved == true) {
      ref.invalidateIfMounted(supplierRouteSpecsProvider(companyId));
      ref.invalidateIfMounted(loadQualityProvider(companyId));
    }
  }
}

class _SpecDialog extends ConsumerStatefulWidget {
  final RouteQualitySpec spec;
  const _SpecDialog({required this.spec});

  @override
  ConsumerState<_SpecDialog> createState() => _SpecDialogState();
}

class _SpecDialogState extends ConsumerState<_SpecDialog> {
  late final TextEditingController _cr2o3;
  late final TextEditingController _moisture;
  late final TextEditingController _sizing;
  late bool _sealRequired;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _cr2o3 = TextEditingController(
        text: widget.spec.specCr2o3Pct?.toString() ?? '');
    _moisture = TextEditingController(
        text: widget.spec.specMoistureMaxPct?.toString() ?? '');
    _sizing = TextEditingController(text: widget.spec.specSizing ?? '');
    _sealRequired = widget.spec.sealRequired;
  }

  @override
  void dispose() {
    _cr2o3.dispose();
    _moisture.dispose();
    _sizing.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    double? parsePct(TextEditingController c) =>
        c.text.trim().isEmpty ? null : double.tryParse(c.text.trim());
    final cr2o3 = parsePct(_cr2o3);
    final moisture = parsePct(_moisture);
    if (_cr2o3.text.trim().isNotEmpty && cr2o3 == null ||
        _moisture.text.trim().isNotEmpty && moisture == null) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter valid percentages.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(qualityServiceProvider).setRouteQualitySpec(
            routeId: widget.spec.routeId,
            specCr2o3Pct: cr2o3,
            specMoistureMaxPct: moisture,
            specSizing:
                _sizing.text.trim().isEmpty ? null : _sizing.text.trim(),
          );
      if (_sealRequired != widget.spec.sealRequired) {
        await ref.read(qualityServiceProvider).setRouteSealRequirement(
              routeId: widget.spec.routeId,
              required: _sealRequired,
            );
      }
      navigator.pop(true);
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger
          .showSnackBar(SnackBar(content: Text('Could not save the spec. ${friendlyError(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
      title: Text('Contract spec — ${widget.spec.routeNumber ?? 'route'}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cr2o3,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Target Cr₂O₃ %',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _moisture,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Max moisture %',
                      border: OutlineInputBorder(),
                      suffixText: '%',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sizing,
              decoration: const InputDecoration(
                labelText: 'Sizing spec',
                hintText: 'e.g. 6–15 mm lumpy',
                border: OutlineInputBorder(),
              ),
            ),
            const Divider(height: 24),
            // The mine applies the seals, so the mine says whether this route
            // needs them. Reaches `routes.seal_required`, which the Load
            // Controller's capture rule and `record_truck_load`'s server-side
            // enforcement both read — and which nothing in the product could
            // write until 2026-08-17.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Seals required on this route'),
              subtitle: const Text(
                'The Load Controller cannot complete a load without a number '
                'and a photo for each seal.',
              ),
              value: _sealRequired,
              onChanged:
                  _saving ? null : (v) => setState(() => _sealRequired = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save spec'),
        ),
      ],
    );
  }
}
