import 'package:flutter/material.dart';

/// GlobalKeys for mine dashboard tour targets.
///
/// These keys should be used to wrap the actual UI elements in the
/// mine dashboard screen with TourTarget widgets.
class MineDashboardTourKeys {
  // Dashboard KPI cards
  static final dashboard = GlobalKey();
  static final stockpiles = GlobalKey();
  static final requests = GlobalKey();
  static final operations = GlobalKey();
  static final reconciliations = GlobalKey();
  
  // Security-specific
  static final checkin = GlobalKey();
  static final checkout = GlobalKey();
  
  // Weighbridge-specific
  static final tare = GlobalKey();
  static final gross = GlobalKey();
}