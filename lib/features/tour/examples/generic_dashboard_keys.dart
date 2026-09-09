import 'package:flutter/material.dart';

/// GlobalKeys for generic tour targets.
///
/// These keys are used for the fallback tour when no specific role/org tour
/// is defined. They target common UI elements like the dashboard and navigation.
class GenericDashboardTourKeys {
  static final dashboard = GlobalKey();
  static final navigation = GlobalKey();
}
