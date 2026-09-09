import 'package:flutter/material.dart';

/// GlobalKeys for the transporter routes screen tour targets.
///
/// These keys are used to wrap the actual UI elements in
/// `transporter_routes_screen.dart` with TourTarget widgets and are
/// referenced by the transporter admin tour in `tour_service.dart`.
class TransporterRoutesTourKeys {
  // Routes dispatched to this company, waiting on acceptance.
  // Only rendered when there is at least one waiting route — a tour step
  // targeting this key is skipped automatically when the section is absent.
  static final waitingRoutes = GlobalKey();

  // Routes this company has accepted
  static final acceptedRoutes = GlobalKey();

  // Live active trips list
  static final activeTrips = GlobalKey();
}
