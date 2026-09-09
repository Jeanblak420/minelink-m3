import 'package:flutter/material.dart';

/// GlobalKeys for the request transportation form tour targets
/// (`request_transportation_screen.dart`).
///
/// NOTE: this screen is PUSHED onto the navigator (a `MaterialPageRoute`,
/// not a go_router route), so the role tours cannot `navigateTo` it — a
/// step that tried would find no target and be skipped. These keys are
/// groundwork for a contextual tour started while the form is open.
class MineRequestsTourKeys {
  // The whole request form
  static final form = GlobalKey();

  // "Route" section — loading point, offloading point, commodity, tonnage
  static final routeSection = GlobalKey();

  // The commodity field (product selection)
  static final productField = GlobalKey();

  // "Request period" section — request type and start/end dates
  static final periodSection = GlobalKey();

  // The submit button
  static final submitButton = GlobalKey();
}
