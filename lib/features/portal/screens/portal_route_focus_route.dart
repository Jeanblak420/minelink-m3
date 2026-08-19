import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/providers/portal_tab_index_provider.dart';

/// Carries a `:routeId` deep link into [pendingRouteFocusProvider], then
/// renders the screen that knows what to do with it.
///
/// `/portal/transporter/accept-route/:routeId` and
/// `/portal/transporter/allocate-fleet/:routeId` previously built
/// `TransporterPortalDashboardScreen` and `FleetManagementScreen` and **threw
/// the id away**. That was documented rather than accidental — acceptance
/// happens in a bottom sheet on the dashboard, not on a per-route screen, so
/// there was nothing to route *to*. The consequence was still a broken link: a
/// notification about one dispatched route dropped the transporter onto a list
/// of every route, with no indication which one they had been sent to see.
///
/// Same shape as [PortalTripWaybillRoute], which carries a `:id` into the
/// waybill modal — a wrapper that performs the deep link's intent and then
/// gets out of the way. It lives here rather than in `app_router.dart` because
/// the router holds no widget classes (S7-1, guard `no-widgets-in-router`).
class PortalRouteFocusRoute extends ConsumerStatefulWidget {
  const PortalRouteFocusRoute({
    super.key,
    required this.routeId,
    required this.child,
  });

  final String routeId;
  final Widget child;

  @override
  ConsumerState<PortalRouteFocusRoute> createState() =>
      PortalRouteFocusRouteState();
}

class PortalRouteFocusRouteState extends ConsumerState<PortalRouteFocusRoute> {
  @override
  void initState() {
    super.initState();
    // Post-frame: setting provider state during build is not allowed, and the
    // consuming screen has to be listening before it changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.routeId.isEmpty) return;
      ref.read(pendingRouteFocusProvider.notifier).state = widget.routeId;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
