import 'package:flutter/material.dart';

/// GlobalKeys for the buyer reconciliations screen tour targets
/// (`buyer_reconciliations_screen.dart`).
///
/// These keys are used to wrap the actual UI elements with TourTarget
/// widgets and are referenced by the buyer admin tour in
/// `tour_service.dart`.
class BuyerReconciliationsTourKeys {
  // Tonnage stat cards (total records / pending / disputed / loaded)
  static final summaryCards = GlobalKey();

  // Source and product filter dropdowns
  static final filters = GlobalKey();

  // "Loaded (mine net)" hero tile with the D/W/M/Y/T breakdown
  static final tonsOverview = GlobalKey();

  // Reconciliation batches section (the per-load recon cards)
  static final batches = GlobalKey();
}
