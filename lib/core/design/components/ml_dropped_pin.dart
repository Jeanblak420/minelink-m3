import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_application_1/core/design/components/ml_buttons.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/utils/geo_format.dart';

/// Press and hold anywhere on a map to drop a pin, exactly as Google Maps does.
///
/// Asked for directly (jean, 2026-08-22): *"include more mobile tap and hold
/// controlls and features"*, alongside the map request. Long-press is the one
/// gesture a phone has that a mouse does not, and before this the product used
/// it nowhere: every `MapOptions` in the tree left `onLongPress` null, so
/// holding a finger on a map did nothing at all.
///
/// ## What it may say, and what it may not
///
/// Only facts already on the device: the coordinate, how far away it is, and
/// which way. **It does not name the place.** Reverse geocoding would mean a
/// sixth network stage with its own rate limit, and — worse — a name is
/// exactly the kind of answer that is confidently wrong: `place_index` exists
/// in this product because the free OSM geocoders *cannot* answer South
/// African addresses, and the same ladder resolved "Iron Hills Mine,
/// Mpumalanga" to a courier depot 460 km from the gate (CLAUDE.md §4). A
/// coordinate cannot be wrong.
///
/// ## What it can do
///
/// Copy the coordinate — the thing a driver on the radio actually needs — and
/// open the point in whatever maps app the device has, which is the escape
/// hatch to everything this app deliberately does not reimplement.
class MlDroppedPinSheet extends StatelessWidget {
  const MlDroppedPinSheet({
    super.key,
    required this.point,
    this.from,
    this.title = 'Dropped pin',
  });

  /// Where the finger landed.
  final LatLng point;

  /// The user's own position, when known — used for "12.4 km NE of you".
  final LatLng? from;

  final String title;

  /// The universal link form, the one CLAUDE.md §4 settled on. The `?q=`
  /// shape is deliberate: the original spec's `https://google.com{lat},{lng}`
  /// is malformed and opens nothing.
  String get _mapsUrl =>
      'https://www.google.com/maps?q=${point.latitude},${point.longitude}';

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final relative = mlRelativePositionText(from, point);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The drag handle. A sheet with no handle reads as a screen that
            // arrived rather than one that can be dismissed.
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: semantic.borderStrong,
                  borderRadius: MlShape.pill,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.place_rounded,
                  size: 26,
                  color: MlTone.error.colors(Theme.of(context).brightness).fg,
                ),
                const SizedBox(width: 10),
                // Flexible, not Expanded-by-default: a long title must be able
                // to ellipsise, and a Row hands a non-flex child unbounded
                // width so `overflow` would never engage (CLAUDE.md §10.4).
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.mlText.titleMedium.copyWith(
                      color: semantic.textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Mono, because it is a code to be read out or typed in, and the
            // digits have to line up. CLAUDE.md §5.
            SelectableText(
              mlLatLngText(point),
              style: context.mlText.code(color: semantic.textStrong, size: 15),
            ),
            if (relative != null) ...[
              const SizedBox(height: 6),
              Text(
                relative,
                style: context.mlText.bodyMedium.copyWith(
                  color: semantic.textMuted,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                MlButton.tonal(
                  label: 'Copy coordinates',
                  icon: Icons.copy_rounded,
                  compact: true,
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: mlLatLngText(point)),
                    );
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coordinates copied.')),
                    );
                  },
                ),
                MlButton.outline(
                  label: 'Open in maps',
                  icon: Icons.open_in_new_rounded,
                  compact: true,
                  onPressed: () => launchUrl(
                    Uri.parse(_mapsUrl),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows [MlDroppedPinSheet] as a modal bottom sheet.
///
/// One entry point so every map opens the same sheet the same way — the maps
/// in this product had drifted into four different ways of showing a detail
/// before the component layer was introduced, and this is a new surface that
/// would have drifted the same way.
Future<void> showMlDroppedPin(
  BuildContext context, {
  required LatLng point,
  LatLng? from,
  String title = 'Dropped pin',
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: false,
    backgroundColor: MlSemantic.of(context).surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: MlShape.radiusTopExtraLarge,
    ),
    builder: (_) => MlDroppedPinSheet(point: point, from: from, title: title),
  );
}
