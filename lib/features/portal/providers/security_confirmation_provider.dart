import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/models/trip_waypoint.dart';
import 'package:flutter_application_1/features/portal/services/security_confirmation_service.dart';

final securityConfirmationServiceProvider =
    Provider<SecurityConfirmationService>(
        (ref) => SecurityConfirmationService());

/// Both gate-confirmation rows (arrival + exit) for a trip — empty until the
/// first party confirms a gate event. Purely additive bookkeeping: consumers
/// must keep working when this errors or stays empty.
final tripSecurityConfirmationsProvider = FutureProvider.autoDispose
    .family<List<SecurityConfirmation>, String>((ref, tripId) {
  return ref.watch(securityConfirmationServiceProvider).forTrip(tripId);
});

/// The mine security gate queue: confirmations on the mine's trips still
/// waiting for security's sign-off (driver-initiated or not yet started).
final minePendingConfirmationsProvider = FutureProvider.autoDispose
    .family<List<SecurityConfirmation>, String>((ref, mineCompanyId) {
  return ref
      .watch(securityConfirmationServiceProvider)
      .pendingForMine(mineCompanyId);
});
