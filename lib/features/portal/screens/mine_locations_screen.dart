import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/portal/models/mine_location.dart';
import 'package:flutter_application_1/features/portal/providers/mine_location_provider.dart';
import 'package:flutter_application_1/features/portal/utils/maps_link.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/company_locations_section.dart';
import 'package:flutter_application_1/features/portal/widgets/location_picker.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/features/portal/providers/company_location_provider.dart';

/// `/portal/mine/locations` (phase-5 design §3.1) — BOTH location datasets on
/// one page:
///
/// 1. **Mine anchor points** (`mine_locations`): Main Gate / Weighbridge /
///    Loading Point — drive `auto_generate_trip_waypoints`.
/// 2. **General locations** ([CompanyLocationsSection], `company_locations`):
///    the named points + primary collection point that
///    `get_trip_nav_destination` resolves trip destinations from. Kept
///    composed, never replaced — the destination chain depends on it.
class MineLocationsScreen extends ConsumerWidget {
  const MineLocationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }
    // Same provider `_MineAnchorsSection` reads; Riverpod dedupes it.
    final locations = ref.watch(companyLocationsProvider(companyId));

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Locations',
            meta: locations.valueOrNull == null
                ? null
                : mlCount(locations.value!.length, 'saved point'),
            description:
                'The mine\'s navigation anchors and its saved collection '
                'points — drivers route to these automatically.',
          ),
          _MineAnchorsSection(companyId: companyId),
          const SizedBox(height: 20),
          CompanyLocationsSection(companyId: companyId),
          const SizedBox(height: 60),
        ],
      ),
    );
  }
}

/// The three configurable navigation anchors of the mine.
class _MineAnchorsSection extends ConsumerWidget {
  final String companyId;
  const _MineAnchorsSection({required this.companyId});

  static const _anchors = [
    (
      type: MineLocationType.mainGate,
      icon: Icons.door_sliding_outlined,
      description: 'Entry and exit checkpoint for security clearance.',
    ),
    (
      type: MineLocationType.weighbridge,
      icon: Icons.scale_outlined,
      description: 'Where trucks are weighed (tare and gross).',
    ),
    (
      type: MineLocationType.loadingPoint,
      icon: Icons.inventory_2_outlined,
      description: 'Where trucks are loaded with the commodity.',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final async = ref.watch(mineLocationsProvider(companyId));

    return MlCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const MlIconWell(
                icon: Icons.route_outlined,
                tone: MlTone.transit,
                size: 40,
                radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Mine anchor points',
                      style: context.mlText.titleMedium.copyWith(
                        color: semantic.textStrong,
                        fontWeight: FontWeight.w800,
                      )),
                  Text(
                      'Main Gate, Weighbridge and Loading Point — used to '
                      'auto-generate each trip\'s waypoint sequence.',
                      style: context.mlText.bodyMedium.copyWith(
                        color: semantic.textMuted,
                      )),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 14),
          async.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator())),
            error: (e, _) => MlLoadFailure(
                subject: 'the mine anchor points',
                error: e,
                onRetry: () => ref.invalidate(mineLocationsProvider(companyId)),
            ),
            data: (locations) {
              final byType = {
                for (final l in locations) l.locationType: l,
              };
              return Column(children: [
                for (final a in _anchors)
                  _AnchorRow(
                    companyId: companyId,
                    type: a.type,
                    icon: a.icon,
                    description: a.description,
                    location: byType[a.type],
                  ),
              ]);
            },
          ),
        ],
      ),
    );
  }
}

/// One anchor row: configured state + coordinates + edit action.
class _AnchorRow extends ConsumerWidget {
  final String companyId;
  final MineLocationType type;
  final IconData icon;
  final String description;
  final MineLocation? location;

  const _AnchorRow({
    required this.companyId,
    required this.type,
    required this.icon,
    required this.description,
    required this.location,
  });

  bool get _configured => location?.hasCoordinates ?? false;

  /// What the second line says.
  ///
  /// A configured anchor states its pin and its address. An anchor that has a
  /// NAME and an ADDRESS but no pin used to fall through to the generic
  /// description — so the Weighbridge row read "Where trucks are weighed (tare
  /// and gross)." while the address the mine had typed in was nowhere on the
  /// screen. The badge already says NOT SET; the line should carry the user's
  /// own data when there is any.
  String _detail() {
    final l = location;
    if (_configured) {
      final address =
          l!.address.trim().isNotEmpty ? ' · ${l.address}' : '';
      return '${l.latitude!.toStringAsFixed(6)}, '
          '${l.longitude!.toStringAsFixed(6)}$address';
    }
    final address = l?.address.trim() ?? '';
    return address.isNotEmpty ? address : description;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final done = MlTone.done.colors(brightness);
    final l = location;

    final action = MlButton.outline(
        label: _configured ? 'Edit' : 'Set up',
        icon: _configured
            ? Icons.edit_outlined
            : Icons.add_location_alt_outlined,
        compact: true,
        onPressed: () => _edit(context, ref));

    final title = Text(
      (l?.name.trim().isNotEmpty ?? false) ? l!.name : type.label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: context.mlText.titleSmall.copyWith(
        color: semantic.textStrong,
        fontWeight: FontWeight.w700,
      ),
    );

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _configured ? done.bg : semantic.surfaceSunken,
        borderRadius: BorderRadius.circular(MlTokens.rPill),
      ),
      child: Text(
        _configured ? 'CONFIGURED' : 'NOT SET',
        style: context.mlText.labelSmall.copyWith(
          color: _configured ? done.fg : semantic.textMuted,
          fontWeight: FontWeight.w800,
        ),
      ),
    );

    final detail = Text(
      _detail(),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
          fontFamily: _configured ? MlTokens.fontMono : MlTokens.fontSans,
          fontSize: 12,
          color: semantic.textMuted),
    );

    // THE BUTTON GOES BELOW ON A PHONE.
    //
    // Icon + title + badge + button in one row leaves the title about 85px at
    // 412px, and every anchor on the screen read "Main Gate …" /
    // "Weighbridge …" — the name truncated to the word the row already
    // says, on the screen whose whole job is naming these three points
    // (measured 2026-08-21, first render). Nothing overflowed; an ellipsis is
    // a valid layout.
    //
    // 520 is where the wide arrangement stops fitting the longest real anchor
    // name beside a CONFIGURED badge and an Edit button, not a round number.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: semantic.divider))),
      child: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 520;
        final text = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Flexible(child: title),
              const SizedBox(width: 8),
              badge,
            ]),
            const SizedBox(height: 2),
            detail,
          ],
        );

        if (wide) {
          return Row(children: [
            MlIconWell(
                icon: icon,
                tone: _configured ? MlTone.done : MlTone.neutral,
                size: 38,
                radius: 11),
            const SizedBox(width: 12),
            Expanded(child: text),
            const SizedBox(width: 10),
            action,
          ]);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              MlIconWell(
                  icon: icon,
                  tone: _configured ? MlTone.done : MlTone.neutral,
                  size: 38,
                  radius: 11),
              const SizedBox(width: 12),
              Expanded(child: text),
            ]),
            const SizedBox(height: 10),
            Align(alignment: Alignment.centerRight, child: action),
          ],
        );
      }),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<
        ({String name, String address, LatLng? point})>(
      context: context,
      builder: (_) => _AnchorEditDialog(type: type, existing: location),
    );
    if (result == null) return;
    try {
      await ref.read(mineLocationServiceProvider).upsert(MineLocation(
            id: location?.id ?? '',
            mineCompanyId: companyId,
            locationType: type,
            name: result.name,
            address: result.address,
            latitude: result.point?.latitude ?? location?.latitude,
            longitude: result.point?.longitude ?? location?.longitude,
            mapLink: result.point != null
                ? googleMapsLink(
                    result.point!.latitude, result.point!.longitude)
                : location?.mapLink,
          ));
      ref.invalidateIfMounted(mineLocationsProvider(companyId));
      messenger.showSnackBar(
          SnackBar(content: Text('${type.label} saved.')));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text('Could not save ${type.label}. ${friendlyError(e)}')));
    }
  }
}

/// Name + address entry, point via the shared free OSM location picker.
class _AnchorEditDialog extends StatefulWidget {
  final MineLocationType type;
  final MineLocation? existing;
  const _AnchorEditDialog({required this.type, this.existing});

  @override
  State<_AnchorEditDialog> createState() => _AnchorEditDialogState();
}

class _AnchorEditDialogState extends State<_AnchorEditDialog> {
  late final _name = TextEditingController(
      text: widget.existing?.name.trim().isNotEmpty ?? false
          ? widget.existing!.name
          : widget.type.label);
  late final _address =
      TextEditingController(text: widget.existing?.address ?? '');
  LatLng? _point;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null && e.hasCoordinates) {
      _point = LatLng(e.latitude!, e.longitude!);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final picked = await showLocationPickerDialog(
      context,
      initial: _point == null
          ? widget.existing?.mapLink
          : googleMapsLink(_point!.latitude, _point!.longitude),
    );
    final p = latLngFromMapsLink(picked);
    if (p != null) {
      if (mounted) {
        setState(() {
          _point = p;
          _error = null;
        });
      }
    }
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
      title: Text('${widget.type.label} anchor'),
      content: SizedBox(
        width: 420,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: _name,
              decoration: InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. ${widget.type.label} A')),
          const SizedBox(height: 14),
          TextField(
              controller: _address,
              decoration: const InputDecoration(
                  labelText: 'Address (optional)',
                  hintText: 'Street address or on-site description')),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: MlButton.outline(
                    label: _point == null ? 'Pick on map' : 'Change on map',
                    icon: Icons.map_outlined,
                    onPressed: _pickOnMap)),
          ]),
          const SizedBox(height: 10),
          if (_error != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(_error!,
                  style: context.mlText.bodyMedium.copyWith(
                    color: MlTone.error .colors(Theme.of(context).brightness) .fg,
                  )),
            ),
          if (_point != null)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Point: ${_point!.latitude.toStringAsFixed(6)}, '
                  '${_point!.longitude.toStringAsFixed(6)}',
                  style: context.mlText.code(
                    color: semantic.textMuted,
                    size: 11,
                    weight: FontWeight.w400,
                  )),
            ),
        ]),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) {
              setState(() => _error = 'Give the anchor a name.');
              return;
            }
            if (_point == null) {
              setState(() => _error = 'Pick the point on the map.');
              return;
            }
            Navigator.pop(context, (
              name: _name.text.trim(),
              address: _address.text.trim(),
              point: _point,
            ));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
