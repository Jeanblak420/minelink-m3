import 'package:flutter/material.dart';

/// GlobalKeys for the mine/supplier reconciliations screen tour targets
/// (`mine_reconciliations_screen.dart`).
///
/// These keys are used to wrap the actual UI elements with TourTarget
/// widgets and are referenced by the mine supervisor tour in
/// `tour_service.dart`.
class MineReconciliationsTourKeys {
  // Weight reconciliation view — loaded vs delivered with variance
  // (the mine's net weight is the authoritative figure; POD links live here)
  static final weightReconciliation = GlobalKey();

  // Side A raw records view
  static final rawRecords = GlobalKey();

  // Export → edit → re-upload panel
  static final uploadsPanel = GlobalKey();
}
