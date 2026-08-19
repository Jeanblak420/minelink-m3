import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/tutorial/models/tutorial_step.dart';

/// Provides the guided-tour step definitions per org type and role.
///
/// Pure (no DB access) — showcase/demo data lives in [ShowcaseService].
/// Constructed via `tutorialServiceProvider`, never as a singleton.
class TutorialService {
  const TutorialService();

  /// Returns the tutorial steps for a given org type and role combination.
  /// Roles considered: security, controllerWB, supervisorForeman, driver,
  /// admin, management (plus the org-level roles). Unknown combinations get
  /// a generic walkthrough.
  List<TutorialStep> getTutorialForUser(OrgType? orgType, UserRole? role) {
    if (orgType == OrgType.mineSupplier) {
      if (role == UserRole.security) return _mineSecurityTutorial();
      if (role == UserRole.controllerWB) return _mineLoadControllerTutorial();
      // supervisorForeman, admin, management, org owner default
      return _mineSupervisorTutorial();
    }

    if (orgType == OrgType.buyer) {
      return _buyerAdminTutorial();
    }

    if (orgType == OrgType.transporter) {
      if (role == UserRole.driver) return _transporterDriverTutorial();
      return _transporterAdminTutorial();
    }

    // Fallback: generic walkthrough
    return _genericTutorial();
  }

  // -- Role-specific tutorial definitions ------------------------------------

  /// 1. Mine Supervisor/Foreman (and mine admin/management/owner) — 7 steps
  List<TutorialStep> _mineSupervisorTutorial() {
    return const [
      TutorialStep(
        title: 'Dashboard',
        description:
            'Your mine control tower — monitor operations at a glance. '
            'See active trips, stockpile levels, and key metrics.',
        icon: Icons.dashboard_outlined,
        targetWidgetKey: 'mine_dashboard',
      ),
      TutorialStep(
        title: 'Stockpile Monitoring',
        description:
            'Watch your stock levels fill in real time. Each stockpile card '
            'shows current tonnage, capacity, and order fulfilment progress.',
        icon: Icons.warehouse_outlined,
        targetWidgetKey: 'mine_stockpiles',
      ),
      TutorialStep(
        title: 'Transportation Requests',
        description:
            'Request haulage from transporters here. Define a route, '
            'specify product, tonnage, and pickup/drop-off locations.',
        icon: Icons.description_outlined,
        targetWidgetKey: 'mine_requests',
        hasAction: true,
        actionLabel: 'Open Requests',
        actionRoute: '/portal/mine/requests',
      ),
      TutorialStep(
        title: 'Weighbridge Oversight',
        description:
            'Review load captures from your weighbridge. Tare and gross '
            'weights auto-populate from weighbridge controllers.',
        icon: Icons.scale_outlined,
        targetWidgetKey: 'mine_weighbridge',
      ),
      TutorialStep(
        title: 'Road Integration',
        description:
            'Request custom mine-road mapping for navigation. Upload DXF '
            'files and our navigation pipeline processes them for your site.',
        icon: Icons.route_outlined,
        targetWidgetKey: 'mine_road',
      ),
      TutorialStep(
        title: 'Employee Management',
        description:
            'Manage your site crew and security team. Add, edit, and assign '
            'roles to your mine personnel.',
        icon: Icons.people_outline,
        targetWidgetKey: 'mine_employees',
      ),
      TutorialStep(
        title: 'Reconciliations',
        description:
            'Verify delivered vs loaded tons every day. Catch discrepancies '
            'early and maintain trust with your buyers.',
        icon: Icons.balance_outlined,
        targetWidgetKey: 'mine_reconciliations',
      ),
    ];
  }

  /// 2. Mine Security — 4 steps
  List<TutorialStep> _mineSecurityTutorial() {
    return const [
      TutorialStep(
        title: 'Dashboard',
        description:
            'Your gate control centre. See all trucks on site, pending '
            'check-ins, and ready-for-checkout alerts.',
        icon: Icons.dashboard_outlined,
        targetWidgetKey: 'security_dashboard',
      ),
      TutorialStep(
        title: 'Truck Check-In',
        description:
            'Record every truck entering the mine. Capture driver details, '
            'truck registration, and expected load information.',
        icon: Icons.login,
        targetWidgetKey: 'security_checkin',
      ),
      TutorialStep(
        title: 'Truck Check-Out',
        description:
            'Verify exits and waybills before gate departure. Ensure all '
            'paperwork is complete and signatures captured.',
        icon: Icons.logout,
        targetWidgetKey: 'security_checkout',
      ),
      TutorialStep(
        title: 'Alerts & Notifications',
        description:
            'Respond to ready-for-checkout notifications. Security gets '
            'alerts when weighbridge controllers finish load captures.',
        icon: Icons.notifications_outlined,
        targetWidgetKey: 'security_alerts',
      ),
    ];
  }

  /// 3. Mine Load Controller (weighbridge) — 5 steps
  List<TutorialStep> _mineLoadControllerTutorial() {
    return const [
      TutorialStep(
        title: 'Dashboard',
        description:
            'Your weighbridge dashboard. View today\'s captures, pending '
            'tare/gross entries, and generated waybills.',
        icon: Icons.dashboard_outlined,
        targetWidgetKey: 'wb_dashboard',
      ),
      TutorialStep(
        title: 'Tare Capture',
        description:
            'Weigh empty trucks and capture reference photos. Tare weight '
            'is recorded as the baseline before loading.',
        icon: Icons.monitor_weight_outlined,
        targetWidgetKey: 'wb_tare',
      ),
      TutorialStep(
        title: 'Gross Capture',
        description:
            'Weigh loaded trucks and add seal numbers. The net weight '
            'is auto-calculated from gross minus tare.',
        icon: Icons.add_box_outlined,
        targetWidgetKey: 'wb_gross',
      ),
      TutorialStep(
        title: 'Waybill Generation',
        description:
            'Waybills auto-generate from your captures. Review and confirm '
            'before the truck departs the weighbridge.',
        icon: Icons.receipt_long_outlined,
        targetWidgetKey: 'wb_waybill',
      ),
      TutorialStep(
        title: 'Trip Records',
        description:
            'Review today\'s completed loads. Filter by truck, driver, or '
            'product to audit your weighbridge operations.',
        icon: Icons.local_shipping_outlined,
        targetWidgetKey: 'wb_trips',
      ),
    ];
  }

  /// 4. Transporter Admin — 6 steps
  List<TutorialStep> _transporterAdminTutorial() {
    return const [
      TutorialStep(
        title: 'Dashboard',
        description:
            'Your fleet command centre. Monitor active trips, fleet '
            'utilisation, and pending route acceptances.',
        icon: Icons.dashboard_outlined,
        targetWidgetKey: 'transporter_dashboard',
      ),
      TutorialStep(
        title: 'Fleet Management',
        description:
            'Add and manage trucks and trailers. Track registration, '
            'capacity, and vehicle status for your entire fleet.',
        icon: Icons.directions_bus_outlined,
        targetWidgetKey: 'transporter_fleet',
      ),
      TutorialStep(
        title: 'Driver Assignment',
        description:
            'Assign drivers to trucks and routes. Each driver gets their '
            'own portal with trip cards and navigation.',
        icon: Icons.person_outline,
        targetWidgetKey: 'transporter_drivers',
      ),
      TutorialStep(
        title: 'Available Routes',
        description:
            'Browse and accept routes from mines. Review route details, '
            'tonnage requirements, and pricing before accepting.',
        icon: Icons.alt_route_outlined,
        targetWidgetKey: 'transporter_routes',
      ),
      TutorialStep(
        title: 'Trip Monitoring',
        description:
            'Track active trips across your fleet. See GPS positions, '
            'estimated arrival times, and load status in real time.',
        icon: Icons.local_shipping_outlined,
        targetWidgetKey: 'transporter_trips',
      ),
      TutorialStep(
        title: 'Maintenance',
        description:
            'Service schedules and maintenance records. Keep your fleet '
            'roadworthy with proactive maintenance tracking.',
        icon: Icons.construction_outlined,
        targetWidgetKey: 'transporter_maintenance',
      ),
    ];
  }

  /// 5. Transporter Driver — 5 steps
  List<TutorialStep> _transporterDriverTutorial() {
    return const [
      TutorialStep(
        title: 'Dashboard',
        description:
            'Your mobile command centre. See your active trip, quick '
            'actions, and notifications all on one screen.',
        icon: Icons.dashboard_outlined,
        targetWidgetKey: 'driver_dashboard',
      ),
      TutorialStep(
        title: 'Trip Card',
        description:
            'Your active trip — all details at a glance. Route, load '
            'information, pickup/drop-off, and status updates.',
        icon: Icons.card_membership_outlined,
        targetWidgetKey: 'driver_trip',
      ),
      TutorialStep(
        title: 'Navigation',
        description:
            'Turn-by-turn with voice coaching and hazard alerts. '
            'Mine-specific roads are mapped for accurate routing.',
        icon: Icons.navigation_outlined,
        targetWidgetKey: 'driver_navigation',
      ),
      TutorialStep(
        title: 'Arrival Check-In',
        description:
            'Security confirmation at mine gates. Your arrival is '
            'recorded when you reach the mine.',
        icon: Icons.flag_outlined,
        targetWidgetKey: 'driver_arrival',
      ),
      TutorialStep(
        title: 'Signature Capture',
        description:
            'Sign for loads and waybills digitally. No paper — your '
            'signature is captured and attached to the waybill.',
        icon: Icons.draw_outlined,
        targetWidgetKey: 'driver_signature',
      ),
    ];
  }

  /// 6. Buyer Admin — 5 steps
  List<TutorialStep> _buyerAdminTutorial() {
    return const [
      TutorialStep(
        title: 'Dashboard',
        description:
            'Your procurement control tower. See all active orders, '
            'incoming deliveries, and reconciliation status.',
        icon: Icons.dashboard_outlined,
        targetWidgetKey: 'buyer_dashboard',
      ),
      TutorialStep(
        title: 'Product Requests',
        description:
            'Request product deliveries from mines. Specify product type, '
            'tonnage, delivery location, and preferred schedule.',
        icon: Icons.inventory_2_outlined,
        targetWidgetKey: 'buyer_requests',
        hasAction: true,
        actionLabel: 'Open Requests',
        actionRoute: '/portal/buyer/requests',
      ),
      TutorialStep(
        title: 'Order Tracking',
        description:
            'Watch your orders being fulfilled in real time. Track trucks '
            'from mine to your site with live GPS updates.',
        icon: Icons.shopping_cart_outlined,
        targetWidgetKey: 'buyer_orders',
      ),
      TutorialStep(
        title: 'Stockpile Monitoring',
        description:
            'Check how much of your order is ready at the mine. Stockpile '
            'cards show real-time fill levels against your allocations.',
        icon: Icons.warehouse_outlined,
        targetWidgetKey: 'buyer_stockpiles',
      ),
      TutorialStep(
        title: 'Reconciliations',
        description:
            'Verify received tons against loaded tons. Daily reconciliation '
            'reports ensure you only pay for what you receive.',
        icon: Icons.balance_outlined,
        targetWidgetKey: 'buyer_reconciliations',
      ),
    ];
  }

  /// Generic fallback tutorial
  List<TutorialStep> _genericTutorial() {
    return const [
      TutorialStep(
        title: 'Welcome to MineLink',
        description:
            'Your mine-to-port logistics coordination platform. Let\'s '
            'walk through the key features.',
        icon: Icons.dashboard_outlined,
      ),
      TutorialStep(
        title: 'Navigation',
        description:
            'Use the sidebar to move between sections. Your available '
            'features depend on your role and organisation type.',
        icon: Icons.menu,
      ),
      TutorialStep(
        title: 'Get Started',
        description:
            'Explore your dashboard and start managing your mining '
            'logistics operations from one central platform.',
        icon: Icons.rocket_launch_outlined,
      ),
    ];
  }
}
