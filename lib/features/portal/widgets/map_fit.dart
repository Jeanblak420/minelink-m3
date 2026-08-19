import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Helpers for building a [CameraFit] that can never hand flutter_map an
/// Infinity/NaN camera zoom.
///
/// flutter_map derives the fit zoom by dividing the viewport by the projected
/// *span* of the coordinates ([FitCoordinates._getCoordinatesZoom]). When every
/// coordinate is identical — a parked truck re-sending the same GPS fix, or a
/// single sample — that span is zero, the division yields Infinity, and if
/// `maxZoom` is left null the Infinity is passed through unclamped and reaches
/// tile rendering, crashing with "Unsupported operation: Infinity or NaN
/// toInt". Passing a *finite* `maxZoom` makes flutter_map clamp that away
/// (Dart's `num.clamp` even orders NaN/Infinity to the upper bound), so the
/// map settles at a sensible zoom instead of exploding.
///
/// The previous guard capped zoom only when `points.length == 1`, which missed
/// the far more common case of several coincident samples. The cap here keys
/// off the coordinate *span*, not the count.

/// A tight zoom for a degenerate cluster (all points effectively coincident) —
/// close enough to read the street the truck is parked on, not maxed out.
const double _degenerateMaxZoom = 13;

/// An always-finite ceiling for genuinely spread-out points. It only bites when
/// the fit would otherwise exceed it (i.e. a near-degenerate span), so normal
/// multi-point fits are unaffected.
const double _spreadMaxZoom = 16;

/// Roughly 0.0005° ≈ 55 m. Below this the projected span is small enough that
/// the derived fit zoom blows past any sane level, so we treat the cluster as
/// degenerate and pin the zoom.
const double _degenerateSpanDegrees = 0.0005;

/// The finite upper zoom bound to use for [coordinates]. Returns a value for
/// every input (including empty/single/all-identical) so callers can pass it
/// straight to [CameraFit.coordinates] `maxZoom` and never emit an unclamped
/// Infinity. Exposed for testing.
double? safeCoordinatesMaxZoom(List<LatLng> coordinates) {
  if (coordinates.isEmpty) return _degenerateMaxZoom;

  var minLat = coordinates.first.latitude;
  var maxLat = minLat;
  var minLng = coordinates.first.longitude;
  var maxLng = minLng;
  for (final c in coordinates) {
    minLat = math.min(minLat, c.latitude);
    maxLat = math.max(maxLat, c.latitude);
    minLng = math.min(minLng, c.longitude);
    maxLng = math.max(maxLng, c.longitude);
  }

  final span = math.max(maxLat - minLat, maxLng - minLng);
  return span < _degenerateSpanDegrees ? _degenerateMaxZoom : _spreadMaxZoom;
}

/// Builds a [CameraFit] over [coordinates] with a guaranteed-finite `maxZoom`,
/// so a cluster of identical GPS samples can't crash tile rendering.
CameraFit safeCoordinatesFit(
  List<LatLng> coordinates, {
  EdgeInsets padding = const EdgeInsets.all(28),
}) {
  return CameraFit.coordinates(
    coordinates: coordinates,
    padding: padding,
    maxZoom: safeCoordinatesMaxZoom(coordinates),
  );
}
