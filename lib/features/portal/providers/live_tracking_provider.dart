import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/models/live_trip_position.dart';
import 'package:flutter_application_1/features/portal/services/live_tracking_service.dart';
import 'package:flutter_application_1/features/portal/services/trip_position_reporter.dart';

final liveTrackingServiceProvider =
    Provider<LiveTrackingService>((ref) => LiveTrackingService());

/// Live feed of active trips + latest positions, party-scoped by company id
/// (null = platform-wide, super-admin only). Realtime-refreshed.
final liveTripPositionsProvider = StreamProvider.autoDispose
    .family<List<LiveTripPosition>, String?>((ref, companyId) {
  return ref.watch(liveTrackingServiceProvider).watchLiveTrips(companyId);
});

/// The driver's ping reporter. Deliberately NOT autoDispose: tracking must
/// survive navigating away from the routes screen for the whole trip.
final tripPositionReporterProvider =
    ChangeNotifierProvider<TripPositionReporter>((ref) {
  return TripPositionReporter(ref.watch(liveTrackingServiceProvider));
});
