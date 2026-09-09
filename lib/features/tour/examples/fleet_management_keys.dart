import 'package:flutter/material.dart';

/// GlobalKeys for the transporter fleet management screen tour targets.
///
/// These keys are used to wrap the actual UI elements in
/// `fleet_management_screen.dart` with TourTarget widgets and are referenced
/// by the transporter admin tour in `tour_service.dart`.
class FleetManagementTourKeys {
  // Fleet summary stat cards (total / on route / available / inactive)
  static final statusCards = GlobalKey();

  // "Add vehicle" primary action in the page header
  static final addVehicle = GlobalKey();

  // The active fleet register table
  static final fleetRegister = GlobalKey();
}
