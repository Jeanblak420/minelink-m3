import 'package:flutter/material.dart';

/// GlobalKeys for transporter dashboard tour targets.
///
/// These keys should be used to wrap the actual UI elements in the
/// transporter dashboard screen with TourTarget widgets.
class TransporterDashboardTourKeys {
  // Dashboard KPI cards
  static final fleetStatus = GlobalKey();
  static final availableRoutes = GlobalKey();
  static final activeTrips = GlobalKey();
  static final earnings = GlobalKey();
  
  // Navigation
  static final sidebar = GlobalKey();
  static final fleetNav = GlobalKey();
  static final routesNav = GlobalKey();
  static final tripsNav = GlobalKey();
  
  // Actions
  static final acceptRoute = GlobalKey();
  static final viewTrip = GlobalKey();
}
