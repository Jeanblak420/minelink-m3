import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/company_location.dart';
import 'package:flutter_application_1/features/portal/providers/company_location_provider.dart';
import 'package:flutter_application_1/features/portal/utils/maps_short_link.dart';
import 'package:flutter_application_1/features/portal/widgets/location_picker.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// "Locations" on the company profile (spec 2026-07-16 §3): named map points,
/// one primary. The primary is what drivers automatically navigate to when a
/// trip has no coordinate loading/offloading point.
class CompanyLocationsSection extends ConsumerWidget {
  final String companyId;
  const CompanyLocationsSection({required this.companyId, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companyLocationsProvider(companyId));
    final semantic = MlSemantic.of(context);

    return MlCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const MlIconWell(
                icon: Icons.location_on_outlined,
                tone: MlTone.accent,
                size: 40,
                radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Locations',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: semantic.textStrong)),
                    Text('Drivers are routed to the primary location automatically.',
                        style:
                            TextStyle(fontSize: 12.5, color: semantic.textMuted)),
                  ]),
            ),
            MlButton.tonal(
                label: 'Add location',
                icon: Icons.add_location_alt_outlined,
                onPressed: () => _addOrEdit(context, ref)),
          ]),
          const SizedBox(height: 14),
          async.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => MlLoadFailure(
                icon: Icons.wifi_off_rounded,
                subject: 'your saved locations',
                error: e,
                onRetry: () => ref.invalidate(companyLocationsProvider(companyId))),
            data: (rows) => rows.isEmpty
                ? const MlEmptyState(
                    icon: Icons.add_location_alt_outlined,
                    title: 'No locations saved yet.',
                    message:
                        'Add your collection point so drivers get directions automatically.')
                : Column(
                    children: [for (final l in rows) _row(context, ref, l, semantic)]),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, CompanyLocation l,
      MlSemantic semantic) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: semantic.divider))),
      child: Row(children: [
        Icon(l.isPrimary ? Icons.star_rounded : Icons.location_on_outlined,
            size: 20,
            color: l.isPrimary
                ? MlTone.done.colors(Theme.of(context).brightness).fg
                : semantic.textFaint),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.name,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: semantic.textStrong)),
            Text(
                l.point == null
                    ? l.mapLink
                    : '${l.point!.latitude.toStringAsFixed(6)}, '
                        '${l.point!.longitude.toStringAsFixed(6)}'
                        '${l.isPrimary ? ' · Primary' : ''}',
                style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 11.5,
                    color: semantic.textMuted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  )),
          ]),
        ),
        if (!l.isPrimary)
          IconButton(
              tooltip: 'Set as primary',
              icon: const Icon(Icons.star_outline_rounded, size: 20),
              onPressed: () => _mutate(context, ref,
                  () => ref.read(companyLocationServiceProvider).setPrimary(l.id))),
        IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined, size: 19),
            onPressed: () => _addOrEdit(context, ref, existing: l)),
        IconButton(
            tooltip: 'Delete',
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            onPressed: () => _delete(context, ref, l)),
      ]),
    );
  }

  Future<void> _mutate(
      BuildContext context, WidgetRef ref, Future<void> Function() op) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
      ref.invalidateIfMounted(companyLocationsProvider(companyId));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save. ${friendlyError(e)}')));
    }
  }

  Future<void> _delete(
      BuildContext context, WidgetRef ref, CompanyLocation l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete location?'),
        content: Text('"${l.name}" will be removed. Drivers will no longer be '
            'routed here automatically.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await _mutate(
          context, ref, () => ref.read(companyLocationServiceProvider).remove(l.id));
    }
  }

  Future<void> _addOrEdit(BuildContext context, WidgetRef ref,
      {CompanyLocation? existing}) async {
    final result = await showDialog<({String name, String mapLink})>(
      context: context,
      builder: (_) => _LocationEditDialog(existing: existing),
    );
    if (result == null || !context.mounted) return;
    // Resolved out here rather than inside the closure: the guard above has
    // just confirmed the widget is alive, so this read cannot throw.
    final svc = ref.read(companyLocationServiceProvider);
    await _mutate(context, ref, () async {
      if (existing == null) {
        await svc.add(companyId, result.name, result.mapLink);
      } else {
        await svc.rename(existing.id, result.name);
        if (result.mapLink != existing.mapLink) {
          await svc.move(existing.id, result.mapLink);
        }
      }
    });
  }
}

/// Name + point entry: pick on the free OSM map, or paste any Google Maps
/// link (short maps.app.goo.gl links are expanded automatically).
class _LocationEditDialog extends StatefulWidget {
  final CompanyLocation? existing;
  const _LocationEditDialog({this.existing});

  @override
  State<_LocationEditDialog> createState() => _LocationEditDialogState();
}

class _LocationEditDialogState extends State<_LocationEditDialog> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  final _link = TextEditingController();
  String? _mapLink;
  String? _error;
  bool _resolving = false;

  @override
  void initState() {
    super.initState();
    _mapLink = widget.existing?.mapLink;
  }

  @override
  void dispose() {
    _name.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final picked = await showLocationPickerDialog(context, initial: _mapLink);
    if (picked != null) {
      if (mounted) {
        setState(() {
          _mapLink = picked;
          _error = null;
        });
      }
    }
  }

  Future<void> _useLink() async {
    setState(() {
      _resolving = true;
      _error = null;
    });
    final p = await resolveMapsLink(_link.text);
    if (!mounted) return;
    setState(() {
      _resolving = false;
      if (p == null) {
        _error = 'Could not read a location from that link.';
      } else {
        _mapLink = googleMapsLink(p.latitude, p.longitude);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
      title: Text(widget.existing == null ? 'Add location' : 'Edit location'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Main gate / Weighbridge 2')),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: MlButton.outline(
                    label: _mapLink == null ? 'Pick on map' : 'Change on map',
                    icon: Icons.map_outlined,
                    onPressed: _pickOnMap)),
          ]),
          const SizedBox(height: 10),
          TextField(
            controller: _link,
            decoration: InputDecoration(
              labelText: 'Or paste a Google Maps link',
              hintText: 'https://maps.app.goo.gl/…',
              suffixIcon: _resolving
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : IconButton(
                      icon: const Icon(Icons.check_rounded),
                      onPressed: _useLink),
            ),
            onSubmitted: (_) => _useLink(),
          ),
          const SizedBox(height: 10),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_error!,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: MlTone.error
                          .colors(Theme.of(context).brightness)
                          .fg)),
            ),
          if (_mapLink != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Saved point: $_mapLink',
                  style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: semantic.textMuted,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    )),
            ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) {
              setState(() => _error = 'Give the location a name.');
              return;
            }
            if (_mapLink == null) {
              setState(() => _error = 'Pick a point on the map or paste a link.');
              return;
            }
            Navigator.pop(context, (name: _name.text, mapLink: _mapLink!));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
