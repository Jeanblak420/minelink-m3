import 'package:flutter/material.dart';

/// GlobalKeys for buyer dashboard tour targets.
///
/// These keys should be used to wrap the actual UI elements in the
/// buyer dashboard screen with TourTarget widgets.
class BuyerDashboardTourKeys {
  // Dashboard KPI cards
  static final dashboard = GlobalKey();
  static final requests = GlobalKey();
  static final orders = GlobalKey();
  static final reconciliations = GlobalKey();
}