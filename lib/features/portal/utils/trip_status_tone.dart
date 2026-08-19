import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';

/// Status tone for a trip lifecycle stage — the `MlTone` semantics from
/// CLAUDE.md §5: transit = blue (moving), atMine = amber (at the mine floor),
/// done = green (a milestone reached), warn = orange (departure), error = red
/// (cancelled).
///
/// Extracted from `app_router.dart` with the screens that used it (P4-01), so
/// the trips list, the trip detail and anything added later cannot drift into
/// colouring the same status differently.
MlTone tripStatusTone(TripStatus status) => switch (status) {
      TripStatus.scheduled => MlTone.neutral,
      TripStatus.enRouteToLoad || TripStatus.enRouteToOffload => MlTone.transit,
      TripStatus.arrivedAtMine || TripStatus.loading => MlTone.atMine,
      TripStatus.loaded ||
      TripStatus.offloaded ||
      TripStatus.completed =>
        MlTone.done,
      TripStatus.leftMine => MlTone.warn,
      TripStatus.cancelled => MlTone.error,
    };
