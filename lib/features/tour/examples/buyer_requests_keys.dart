import 'package:flutter/material.dart';

/// GlobalKeys for the shared Requests screen tour targets.
///
/// `buyer_requests_screen.dart` is shared by buyers and — with `isMine` —
/// mines/suppliers, served at both `/portal/buyer/requests` and
/// `/portal/mine/requests`. The same keys therefore serve the buyer admin
/// tour and the mine supervisor tour in `tour_service.dart`.
class BuyerRequestsTourKeys {
  // "Request transportation" tonal action — opens the route request form
  static final transportationAction = GlobalKey();

  // Org-specific primary action: "Request products" (buyer) or
  // "Request buyers" (mine) — opens the product/buyer request dialog
  static final primaryAction = GlobalKey();

  // Available routes marketplace section
  static final availableRoutes = GlobalKey();

  // The grouped request list (needs action / pending review / active / closed)
  static final requestsList = GlobalKey();

  // Request tracking view (delivery tracking)
  static final tracking = GlobalKey();
}
