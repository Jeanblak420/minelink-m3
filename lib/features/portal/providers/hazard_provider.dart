import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/models/mine_hazard.dart';
import 'package:flutter_application_1/features/portal/services/hazard_service.dart';

final hazardServiceProvider =
    Provider<HazardService>((ref) => HazardService());

/// Active hazards within `radiusMeters` of a point, nearest first.
final nearbyHazardsProvider = FutureProvider.autoDispose.family<
    List<MineHazard>,
    ({double lat, double lng, int radiusMeters})>((ref, q) {
  return ref
      .watch(hazardServiceProvider)
      .nearby(q.lat, q.lng, radiusMeters: q.radiusMeters);
});

/// Every currently-active (non-expired) hazard — the platform-wide layer drawn
/// on the live operations map so viewers see what drivers are routing around.
final activeHazardsProvider = FutureProvider.autoDispose<List<MineHazard>>(
  (ref) => ref.watch(hazardServiceProvider).activeAll(),
);
