import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// The controls a phone user expects to find on a map, in one place.
///
/// ## Why this exists
///
/// Asked for directly (jean, 2026-08-22): *"for the driver side map there needs
/// to be a button to re-center and or re-focus … on the user's current location
/// for incase he swipes on the map to check something. also add more functions
/// and features to the maps which are similar to google map's mobile features"*.
///
/// Before this, the product had five `FlutterMap`s and **one** control between
/// them: a small re-centre FAB on the turn-by-turn screen that appeared only
/// once the camera had already been left behind. The live map, the truck-
/// locations map and the console's map had no zoom buttons, no way back to
/// anything, and no way to ask where a point is — a driver who pinched to look
/// at a junction had to pinch his way back.
///
/// ## The shape
///
/// Google Maps' mobile arrangement, because that is the one every driver
/// already knows: a stack at the trailing edge, zoom joined into a single pill
/// with a hairline between the two halves, everything else a separate disc.
/// Reading down, ending nearest the thumb:
///
///   * **compass** — only while the map is turned away from north, and it
///     turns with the map. Tapping it puts north back up.
///   * **overview** — frames everything worth seeing (the whole route, or
///     every truck reporting).
///   * **zoom in / zoom out** — one pill, because they are one decision.
///   * **my location** — the last one, nearest the thumb, because it is the
///     one that gets pressed most.
///
/// ## The my-location button has three states, and says which
///
/// Following, not following, and nothing to follow. Google's own icons carry
/// this distinction and it is the whole point of the control: a driver who has
/// swiped away needs to see at a glance that the map is no longer tracking him.
///
/// | state | icon | look |
/// |---|---|---|
/// | following | `my_location` | filled, accent |
/// | a fix, not following | `location_searching` | ordinary disc |
/// | no fix | `location_disabled` | disabled |
///
/// ## Touch targets
///
/// 48 logical pixels, the Material minimum, and not a pixel less — this is
/// used one-handed, in a moving truck, by someone wearing gloves. The discs are
/// deliberately larger than the 40px a desktop map would use.
class MlMapControls extends StatefulWidget {
  const MlMapControls({
    super.key,
    required this.controller,
    this.onRecenter,
    this.following = false,
    this.hasFix = false,
    this.onOverview,
    this.overviewTooltip = 'Show everything',
    this.recenterTooltip = 'Centre on my position',
    this.allowRotation = true,
    this.padding = const EdgeInsets.all(12),
  });

  /// The map this drives. Only ever read through [MapController.camera], which
  /// throws before the map's first layout — see [_camera].
  final MapController controller;

  /// Puts the camera back on the user. Null hides the button entirely, which
  /// is right for a map that has no "me" to go back to.
  final VoidCallback? onRecenter;

  /// True while the camera is glued to the user's position.
  final bool following;

  /// True when there is a position to go back to at all.
  final bool hasFix;

  /// Frames everything worth seeing. Null hides the button.
  final VoidCallback? onOverview;

  final String overviewTooltip;
  final String recenterTooltip;

  /// False on maps whose `InteractionOptions` exclude rotation — there the
  /// compass can never be anything but north and drawing one is a lie.
  final bool allowRotation;

  /// Inset from whatever the caller aligns this against.
  ///
  /// **The caller does the aligning**, with a `Positioned` or an `Align` of its
  /// own. This widget deliberately does not wrap itself in an `Align`: inside a
  /// `Positioned` that names only `right`/`bottom` the child is loosely
  /// constrained, and an `Align` there expands to the largest size it is
  /// offered — which under a `Stack` sized by a sibling is unbounded, and
  /// throws. That is the same family of fault as CLAUDE.md §10.4's
  /// `CrossAxisAlignment.stretch` note, and it is cheaper to not build the trap
  /// than to remember it at three call sites.
  final EdgeInsets padding;

  @override
  State<MlMapControls> createState() => _MlMapControlsState();
}

class _MlMapControlsState extends State<MlMapControls> {
  StreamSubscription<MapEvent>? _events;
  double _rotation = 0;

  @override
  void initState() {
    super.initState();
    // The compass has to know which way the map is pointing, and nothing else
    // rebuilds this widget when the user turns it with two fingers.
    _events = widget.controller.mapEventStream.listen((_) {
      final r = _camera?.rotation;
      if (r == null) return;
      // A gesture emits events continuously; only rebuild when the answer
      // actually changes, or this repaints on every frame of a pan.
      if ((r - _rotation).abs() < 0.5) return;
      if (!mounted) return;
      setState(() => _rotation = r);
    });
  }

  @override
  void dispose() {
    _events?.cancel();
    super.dispose();
  }

  /// The camera, or null before the map's first layout.
  ///
  /// `MapController.camera` throws *"You need to have the FlutterMap widget
  /// rendered at least once before using the MapController"*, and these
  /// controls are built in the same frame as the map they sit on — so the
  /// first build genuinely arrives before there is a camera. Same guard the
  /// navigation screen carries around its own rotation read.
  MapCamera? get _camera {
    try {
      return widget.controller.camera;
    } catch (_) {
      return null;
    }
  }

  void _zoomBy(double delta) {
    final c = _camera;
    if (c == null) return;
    // Clamped to the layer's own limits: flutter_map will happily accept a
    // zoom of 30 and then ask a tile server for a tile that does not exist,
    // which reads to a driver as the map going blank.
    final next = (c.zoom + delta).clamp(2.0, 19.0);
    widget.controller.move(c.center, next);
  }

  void _northUp() {
    widget.controller.rotate(0);
    setState(() => _rotation = 0);
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    // Turned away from north by more than half a degree. Below that it is a
    // rounding artefact of a pinch, not a decision the user made.
    final turned = widget.allowRotation && _rotation.abs() > 0.5;

    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (turned) ...[
            _MlMapControlDisc(
              tooltip: 'Point the map north',
              onPressed: _northUp,
              // The needle turns with the map, so it always points at real
              // north rather than at the top of the screen.
              child: Transform.rotate(
                angle: -_rotation * math.pi / 180,
                child: Icon(
                  Icons.navigation_rounded,
                  size: 22,
                  color: MlTone.error.colors(Theme.of(context).brightness).fg,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (widget.onOverview != null) ...[
            _MlMapControlDisc(
              tooltip: widget.overviewTooltip,
              onPressed: widget.onOverview,
              child: Icon(
                Icons.zoom_out_map_rounded,
                size: 22,
                color: semantic.textStrong,
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Zoom is ONE pill with a hairline through it, not two discs: it
          // is a single decision with a direction, and joining them halves
          // the number of separate things on the map.
          _MlMapZoomPill(onIn: () => _zoomBy(1), onOut: () => _zoomBy(-1)),
          if (widget.onRecenter != null) ...[
            const SizedBox(height: 10),
            _MlMapControlDisc(
              key: const ValueKey('map-recenter'),
              tooltip: widget.recenterTooltip,
              onPressed: widget.hasFix ? widget.onRecenter : null,
              filled: widget.following,
              child: Icon(
                !widget.hasFix
                    ? Icons.location_disabled_rounded
                    : widget.following
                    ? Icons.my_location_rounded
                    : Icons.location_searching_rounded,
                size: 22,
                color: !widget.hasFix
                    ? semantic.textFaint
                    : widget.following
                    ? MlTokens.inkOnFill
                    : semantic.textStrong,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One 48px circular control. The size is the Material minimum touch target
/// and is not negotiable here — see the class note on [MlMapControls].
class _MlMapControlDisc extends StatelessWidget {
  const _MlMapControlDisc({
    super.key,
    required this.child,
    required this.tooltip,
    this.onPressed,
    this.filled = false,
  });

  final Widget child;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: filled ? MlTokens.accent : semantic.surfaceCard,
        shape: CircleBorder(
          side: BorderSide(
            color: filled ? MlTokens.accent : semantic.borderCard,
          ),
        ),
        elevation: 0,
        shadowColor: MlTokens.mapControlShadow,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(width: 48, height: 48, child: Center(child: child)),
        ),
      ),
    );
  }
}

/// Zoom in over zoom out, joined, with a hairline between them.
class _MlMapZoomPill extends StatelessWidget {
  const _MlMapZoomPill({required this.onIn, required this.onOut});

  final VoidCallback onIn;
  final VoidCallback onOut;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    Widget half(IconData icon, String tooltip, VoidCallback onTap, Key key) =>
        Tooltip(
          message: tooltip,
          child: InkWell(
            key: key,
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Icon(icon, size: 22, color: semantic.textStrong),
              ),
            ),
          ),
        );

    return Material(
      color: semantic.surfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: MlShape.radiusLargeIncreased,
        side: BorderSide(color: semantic.borderCard),
      ),
      elevation: 0,
      shadowColor: MlTokens.mapControlShadow,
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          half(
            Icons.add_rounded,
            'Zoom in',
            onIn,
            const ValueKey('map-zoom-in'),
          ),
          Divider(height: 1, thickness: 1, color: semantic.divider),
          half(
            Icons.remove_rounded,
            'Zoom out',
            onOut,
            const ValueKey('map-zoom-out'),
          ),
        ],
      ),
    );
  }
}

/// The scale bar, in the app's own type and ink.
///
/// A map with no scale asks the reader to guess whether a gap is 200 m or
/// 20 km, which on a mine haul road is the difference between "just there" and
/// "half an hour". `flutter_map` ships the widget; this fixes its colours to
/// the theme so it is legible on both the light basemap and the darkened one.
Widget mlMapScaleBar(BuildContext context, {Alignment? alignment}) {
  final semantic = MlSemantic.of(context);
  return Scalebar(
    alignment: alignment ?? Alignment.bottomLeft,
    padding: const EdgeInsets.all(12),
    lineColor: semantic.textStrong,
    strokeWidth: 2,
    lineHeight: 6,
    textStyle: context.mlText.labelSmall.copyWith(
      color: semantic.textStrong,
      fontWeight: FontWeight.w700,
    ),
  );
}
