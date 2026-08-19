import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected sidebar tab index for `/home` (shell).
final portalTabIndexProvider = StateProvider<int>((ref) => 0);

/// Stockpile id a notification asked to open. When set, the portal switches to
/// the Supervisor tab (done by the notification handler) and the Supervisor
/// screen briefly highlights the matching stockpile, then clears this.
final pendingStockpileFocusProvider = StateProvider<String?>((ref) => null);

/// Route id a deep link asked to open, from
/// `/portal/transporter/accept-route/:routeId` or `…/allocate-fleet/:routeId`.
///
/// Those two routes used to accept the `:routeId` segment and **drop it** —
/// the comment in `app_router.dart` said as much — so a notification link to
/// one specific dispatched route landed the transporter on a list of all of
/// them, with nothing indicating which one they had been sent to look at. The
/// transporter dashboard now consumes this and opens that route's detail sheet
/// directly, the same way `pendingStockpileFocusProvider` above focuses a
/// stockpile from a dispatch notification.
final pendingRouteFocusProvider = StateProvider<String?>((ref) => null);
