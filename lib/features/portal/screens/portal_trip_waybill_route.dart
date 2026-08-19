import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/widgets/waybill_modal.dart';

/// Opens the waybill for [tripId]; completes when it is dismissed.
typedef WaybillOpener = Future<void> Function(
    BuildContext context, WidgetRef ref, String tripId);

// Extracted from `app_router.dart` (P4-01…P4-07). It was declared inside
// the router itself, which is why it had no screen file and no test.
/// Route wrapper for `/portal/{org}/trips/:id/waybill` and
/// `/portal/driver/trip/:id/waybill` (phase-2 T6): pops the EXISTING
/// [showWaybillModal] (server-authoritative `get_trip_waybill` →
/// trip_waybill_builder → waybill_pdf) over the trip context once mounted —
/// no new waybill renderer.
class PortalTripWaybillRoute extends ConsumerStatefulWidget {
  const PortalTripWaybillRoute({
    super.key,
    required this.tripId,
    required this.child,
    this.openWaybill,
  });

  final String tripId;
  final Widget child;

  /// How the document is opened. Defaults to [showWaybillModal].
  ///
  /// Seamed because what this class decides is *when* to open and close, and
  /// that is untestable through the real one: `buildTripWaybill` assigns
  /// `SupabaseConfig.client` in a field initializer, so it throws on
  /// construction with no session. Injecting the opener keeps the test on this
  /// widget's own lifecycle rather than on the modal's internals.
  @visibleForTesting
  final WaybillOpener? openWaybill;

  @override
  ConsumerState<PortalTripWaybillRoute> createState() =>
      PortalTripWaybillRouteState();
}

class PortalTripWaybillRouteState
    extends ConsumerState<PortalTripWaybillRoute> {
  /// The trip whose waybill is currently on screen, or null when none is.
  ///
  /// Was a plain `bool _opened`, set once in [initState] and never revisited.
  /// These routes differ only in a path parameter, so GoRouter reuses this
  /// element rather than rebuilding it: navigating from one trip's waybill to
  /// another ran [didUpdateWidget], not [initState], and the guard therefore
  /// suppressed the new document while the previous one stayed on the barrier.
  /// The URL said one trip and the paper on screen was another's — on the
  /// document that governs a delivery.
  String? _showing;

  @override
  void initState() {
    super.initState();
    _scheduleSync();
  }

  @override
  void didUpdateWidget(covariant PortalTripWaybillRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tripId != widget.tripId) _scheduleSync();
  }

  /// Always after the current frame, never during it.
  ///
  /// Pushing or popping a route inside `didUpdateWidget` marks the Overlay
  /// dirty while the framework is still building — "setState() or
  /// markNeedsBuild() called during build", thrown from GoRouter's own
  /// Builder. `initState` used a post-frame callback for exactly this reason;
  /// `didUpdateWidget` needs it just as much.
  ///
  /// Safe to schedule more than once: [_sync] is idempotent, so a burst of
  /// rebuilds before the frame lands costs nothing.
  void _scheduleSync() =>
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());

  /// Brings what is on screen into line with [PortalTripWaybillRoute.tripId].
  void _sync() {
    if (!mounted || widget.tripId.isEmpty) return;
    if (_showing == widget.tripId) return;

    if (_showing != null) {
      // Close the previous trip's copy first. `showWaybillModal` goes through
      // `showDialog`, which pushes onto the ROOT navigator — popping the
      // shell's inner one would leave the document up and take the page
      // instead (the fault behind the console's blank-screen dialogs).
      Navigator.of(context, rootNavigator: true).pop();
      _showing = null;
    }

    final id = widget.tripId;
    _showing = id;
    // Captured, so a late dismissal of the OUTGOING modal cannot clear the
    // incoming one's marker: its future completes after the exit transition,
    // by which time `_showing` already names the new trip.
    final open = widget.openWaybill ??
        (c, r, t) => showWaybillModal(c, r, tripId: t);
    open(context, ref, id).whenComplete(() {
      if (mounted && _showing == id) _showing = null;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
