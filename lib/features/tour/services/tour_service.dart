import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/tour/examples/transporter_dashboard_keys.dart';
import 'package:flutter_application_1/features/tour/examples/mine_dashboard_keys.dart';
import 'package:flutter_application_1/features/tour/examples/buyer_dashboard_keys.dart';
import 'package:flutter_application_1/features/tour/examples/driver_app_keys.dart';
import 'package:flutter_application_1/features/tour/examples/generic_dashboard_keys.dart';
import 'package:flutter_application_1/features/tour/examples/fleet_management_keys.dart';
import 'package:flutter_application_1/features/tour/examples/transporter_routes_keys.dart';
import 'package:flutter_application_1/features/tour/examples/buyer_requests_keys.dart';
import 'package:flutter_application_1/features/tour/examples/mine_reconciliations_keys.dart';
import 'package:flutter_application_1/features/tour/examples/buyer_reconciliations_keys.dart';
import 'package:flutter_application_1/features/tour/models/tour_step.dart';

/// Provides coach-mark tour step definitions per org type and role.
///
/// Unlike the old TutorialService, this returns TourStep objects with
/// actual GlobalKeys that target real UI elements in the app.
class TourService {
  const TourService();

  /// Returns the tour steps for a given org type and role combination.
  /// Roles considered: security, controllerWB, supervisorForeman, driver,
  /// admin, management (plus the org-level roles).
  ///
  /// Every targetKey references a TourTarget-wrapped element in the app.
  /// A step whose target is not mounted (a conditional section, or a screen
  /// the user has moved away from) is skipped automatically by the overlay
  /// once its retries are exhausted.
  List<TourStep> getTourForUser(OrgType? orgType, String? role) {
    if (orgType == OrgType.mineSupplier) {
      if (role == 'security') return _mineSecurityTour();
      if (role == 'controllerWB') return _mineLoadControllerTour();
      return _mineSupervisorTour();
    }

    if (orgType == OrgType.buyer) {
      return _buyerAdminTour();
    }

    if (orgType == OrgType.transporter) {
      if (role == 'driver') return _transporterDriverTour();
      return _transporterAdminTour();
    }

    return _genericTour();
  }

  // -- Role-specific tour definitions ------------------------------------

  /// Mine Supervisor/Foreman tour
  List<TourStep> _mineSupervisorTour() {
    return [
      TourStep(
        id: 'mine.dashboard',
        targetKey: MineDashboardTourKeys.dashboard,
        title: 'Dashboard',
        description:
            'Your mine control tower — monitor operations at a glance. '
            'See active trips, stockpile levels, and key metrics.',
        icon: Icons.dashboard_outlined,
      ),
      TourStep(
        id: 'mine.stockpiles',
        targetKey: MineDashboardTourKeys.stockpiles,
        title: 'Stockpile Monitoring',
        description:
            'Watch your stock levels fill in real time. Each stockpile card '
            'shows current tonnage, capacity, and order fulfilment progress.',
        icon: Icons.warehouse_outlined,
      ),
      TourStep(
        id: 'mine.requests',
        targetKey: MineDashboardTourKeys.requests,
        title: 'Action Queue',
        description:
            'Manage check-ins, weighbridge loads, revision requests, and '
            'reconciliation disputes from this central queue.',
        icon: Icons.description_outlined,
      ),
      TourStep(
        id: 'mine.transportation_requests',
        targetKey: BuyerRequestsTourKeys.transportationAction,
        title: 'Transportation Requests',
        description:
            'Request haulage from transporters and raise buyer requests, '
            'then follow their review status on this screen.',
        icon: Icons.local_shipping_outlined,
        navigateTo: '/portal/mine/requests',
      ),
      TourStep(
        id: 'mine.reconciliations',
        targetKey: MineReconciliationsTourKeys.weightReconciliation,
        title: 'Reconciliations',
        description:
            'Your loaded net weight is the authoritative figure. Compare it '
            'against delivered tons, inspect the raw records, and keep the '
            'original next to any edited re-upload.',
        icon: Icons.balance_outlined,
        navigateTo: '/portal/mine/reconciliations',
      ),
    ];
  }

  /// Mine Security tour
  List<TourStep> _mineSecurityTour() {
    return [
      TourStep(
        id: 'security.dashboard',
        targetKey: MineDashboardTourKeys.dashboard,
        title: 'Dashboard',
        description:
            'Your gate control centre. See all trucks on site, pending '
            'check-ins, and ready-for-checkout alerts.',
        icon: Icons.dashboard_outlined,
      ),
      TourStep(
        id: 'security.checkin',
        targetKey: MineDashboardTourKeys.checkin,
        title: 'Truck Check-In',
        description:
            'Record every truck entering the mine. Capture driver details, '
            'truck registration, and expected load information.',
        icon: Icons.login,
      ),
      TourStep(
        id: 'security.checkout',
        targetKey: MineDashboardTourKeys.checkout,
        title: 'Truck Check-Out',
        description:
            'Verify exits and waybills before gate departure. Ensure all '
            'paperwork is complete and signatures captured.',
        icon: Icons.logout,
      ),
    ];
  }

  /// Mine Load Controller (weighbridge) tour
  List<TourStep> _mineLoadControllerTour() {
    return [
      TourStep(
        id: 'wb.dashboard',
        targetKey: MineDashboardTourKeys.dashboard,
        title: 'Dashboard',
        description:
            'Your weighbridge dashboard. View today\'s captures, pending '
            'tare/gross entries, and generated waybills.',
        icon: Icons.dashboard_outlined,
      ),
      TourStep(
        id: 'wb.tare',
        targetKey: MineDashboardTourKeys.tare,
        title: 'Tare Capture',
        description:
            'Weigh empty trucks and capture reference photos. Tare weight '
            'is recorded as the baseline before loading.',
        icon: Icons.monitor_weight_outlined,
      ),
      TourStep(
        id: 'wb.gross',
        targetKey: MineDashboardTourKeys.gross,
        title: 'Gross Capture',
        description:
            'Weigh loaded trucks and add seal numbers. The net weight '
            'is auto-calculated from gross minus tare.',
        icon: Icons.add_box_outlined,
      ),
    ];
  }

  /// Transporter Admin tour
  ///
  /// Dashboard steps come first (their targets are only mounted there),
  /// then the tour navigates to the fleet management and routes screens.
  List<TourStep> _transporterAdminTour() {
    return [
      TourStep(
        id: 'transporter.fleet_status',
        targetKey: TransporterDashboardTourKeys.fleetStatus,
        title: 'Fleet Status',
        description:
            'Your fleet command centre. Monitor active trips, fleet '
            'utilisation, and pending route acceptances at a glance.',
        icon: Icons.dashboard_outlined,
      ),
      TourStep(
        id: 'transporter.available_routes',
        targetKey: TransporterDashboardTourKeys.availableRoutes,
        title: 'Available Routes',
        description:
            'Browse and accept routes from mines. Review route details, '
            'tonnage requirements, and pricing before accepting.',
        icon: Icons.alt_route_outlined,
      ),
      TourStep(
        id: 'transporter.active_trips',
        targetKey: TransporterDashboardTourKeys.activeTrips,
        title: 'Active Trips',
        description:
            'Track active trips across your fleet. See GPS positions, '
            'estimated arrival times, and load status in real time.',
        icon: Icons.local_shipping_outlined,
      ),
      TourStep(
        id: 'transporter.fleet_summary',
        targetKey: FleetManagementTourKeys.statusCards,
        title: 'Fleet Status',
        description:
            'Every vehicle registered to your company, counted the same way '
            'the dashboard reads it — on route, available to allocate, or '
            'out of service.',
        icon: Icons.local_shipping_outlined,
        navigateTo: '/portal/transporter/fleet',
      ),
      TourStep(
        id: 'transporter.fleet_add_vehicle',
        targetKey: FleetManagementTourKeys.addVehicle,
        title: 'Add a Vehicle',
        description:
            'Register a truck here — its truck pack, driver details and '
            'documents all live against the vehicle.',
        icon: Icons.add_circle_outline,
      ),
      TourStep(
        id: 'transporter.fleet_register',
        targetKey: FleetManagementTourKeys.fleetRegister,
        title: 'Fleet Register',
        description:
            'Every active vehicle with its live status. Assign or change '
            'drivers, edit details, or mark a vehicle inactive from its row.',
        icon: Icons.format_list_bulleted_outlined,
      ),
      TourStep(
        id: 'transporter.routes_waiting',
        targetKey: TransporterRoutesTourKeys.waitingRoutes,
        title: 'Routes Waiting on You',
        description:
            'Routes dispatched to you by the MineLink admin appear here '
            'first. Open one to review it and accept the work.',
        icon: Icons.assignment_turned_in_outlined,
        navigateTo: '/portal/transporter/routes',
      ),
      TourStep(
        id: 'transporter.routes_accepted',
        targetKey: TransporterRoutesTourKeys.acceptedRoutes,
        title: 'Accepted Routes',
        description:
            'The routes you have accepted, with their per-route metrics, '
            'trips, and the live stockpile fill at each mine.',
        icon: Icons.alt_route_rounded,
      ),
      TourStep(
        id: 'transporter.routes_active_trips',
        targetKey: TransporterRoutesTourKeys.activeTrips,
        title: 'Active Trips',
        description:
            'Live trips for your accepted routes. Tap Track to follow that '
            'truck on the Truck locations map.',
        icon: Icons.local_shipping_outlined,
      ),
    ];
  }

  /// Transporter Driver tour
  List<TourStep> _transporterDriverTour() {
    return [
      TourStep(
        id: 'driver.dashboard',
        targetKey: DriverAppTourKeys.dashboard,
        title: 'Dashboard',
        description:
            'Your mobile command centre. See your active trip, quick '
            'actions, and notifications all on one screen.',
        icon: Icons.dashboard_outlined,
      ),
      TourStep(
        id: 'driver.trip',
        targetKey: DriverAppTourKeys.tripCard,
        title: 'Trip Card',
        description:
            'Your active trip — all details at a glance. Route, load '
            'information, pickup/drop-off, and status updates.',
        icon: Icons.card_membership_outlined,
      ),
      TourStep(
        id: 'driver.navigation',
        targetKey: DriverAppTourKeys.navigation,
        title: 'Navigation',
        description:
            'Tap Navigate for turn-by-turn directions to your destination. '
            'Get real-time route guidance and hazard alerts.',
        icon: Icons.navigation_rounded,
      ),
    ];
  }

  /// Buyer Admin tour
  ///
  /// Dashboard steps come first (their targets are only mounted there),
  /// then the tour navigates to the requests and reconciliations screens.
  List<TourStep> _buyerAdminTour() {
    return [
      TourStep(
        id: 'buyer.dashboard',
        targetKey: BuyerDashboardTourKeys.dashboard,
        title: 'Dashboard',
        description:
            'Your procurement control tower. See all active orders, '
            'incoming deliveries, and reconciliation status.',
        icon: Icons.dashboard_outlined,
      ),
      TourStep(
        id: 'buyer.orders',
        targetKey: BuyerDashboardTourKeys.orders,
        title: 'Order Tracking',
        description:
            'Watch your orders being fulfilled in real time. Track trucks '
            'from mine to your site with live GPS updates.',
        icon: Icons.shopping_cart_outlined,
      ),
      TourStep(
        id: 'buyer.requests',
        targetKey: BuyerRequestsTourKeys.primaryAction,
        title: 'Product Requests',
        description:
            'Request product deliveries from mines — product type, tonnage, '
            'delivery location and schedule. Your requests and their review '
            'status are tracked on this screen.',
        icon: Icons.inventory_2_outlined,
        navigateTo: '/portal/buyer/requests',
      ),
      TourStep(
        id: 'buyer.requests_tracking',
        targetKey: BuyerRequestsTourKeys.tracking,
        title: 'Delivery Tracking',
        description:
            'Follow every request from raised to delivered — truck positions '
            'update live as loads move from the mine to your site.',
        icon: Icons.local_shipping_outlined,
      ),
      TourStep(
        id: 'buyer.reconciliations',
        targetKey: BuyerReconciliationsTourKeys.tonsOverview,
        title: 'Tons & Reconciliations',
        description:
            'Loaded tonnage by day, week, month and year — filterable by '
            'mine and product — with every reconciliation batch to view or '
            'download.',
        icon: Icons.balance_outlined,
        navigateTo: '/portal/buyer/reconciliations',
      ),
    ];
  }

  /// Generic fallback tour
  List<TourStep> _genericTour() {
    return [
      TourStep(
        id: 'generic_dashboard',
        targetKey: GenericDashboardTourKeys.dashboard,
        title: 'Welcome to MineLink',
        description:
            'Your mine-to-port logistics coordination platform. Let\'s '
            'walk through the key features.',
        icon: Icons.dashboard_outlined,
      ),
      TourStep(
        id: 'generic_navigation',
        targetKey: GenericDashboardTourKeys.navigation,
        title: 'Navigation',
        description:
            'Use the sidebar to move between sections. Your available '
            'features depend on your role and organisation type.',
        icon: Icons.menu,
      ),
    ];
  }
}
