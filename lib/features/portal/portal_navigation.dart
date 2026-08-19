import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_loads_value_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_requests_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_routes_mines_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/buyer_waybills_screen.dart';
import 'package:flutter_application_1/features/portal/screens/compliance_screen.dart';
import 'package:flutter_application_1/features/portal/screens/driver_routes_screen.dart';
import 'package:flutter_application_1/features/portal/screens/earnings_screen.dart';
import 'package:flutter_application_1/features/portal/screens/fuel_costs_screen.dart';
import 'package:flutter_application_1/features/portal/screens/live_trip_map_screen.dart';
import 'package:flutter_application_1/features/portal/screens/load_controller_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_production_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_quality_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_buyers_detail_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/mine_supplier_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/security_checkin_screen.dart';
import 'package:flutter_application_1/features/portal/screens/supervisor_view_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_maintenance_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_portal_dashboard_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_reconciliations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_request_tracking_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_routes_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_truck_locations_screen.dart';
import 'package:flutter_application_1/features/portal/screens/trucks_on_route_screen.dart';
import 'package:flutter_application_1/features/portal/screens/transporter_truck_positions_screen.dart';
import 'package:flutter_application_1/features/profile/screens/profile_screen.dart';
import 'package:flutter_application_1/features/tabs/screens/admin_tab_screen.dart';
import 'package:flutter_application_1/features/tabs/screens/buyer_tab_screen.dart';
import 'package:flutter_application_1/features/tabs/screens/driver_tab_screen.dart';
import 'package:flutter_application_1/features/tabs/screens/management_tab_screen.dart';
import 'package:flutter_application_1/features/tabs/screens/mine_supplier_tab_screen.dart';
import 'package:flutter_application_1/features/tabs/screens/transporter_tab_screen.dart';

class PortalTabItem {
  final String label;
  final IconData icon;
  final Widget screen;

  const PortalTabItem(this.label, this.icon, this.screen);
}

List<PortalTabItem> _transporterPortalTabs({required bool includeManagement}) {
  return [
    const PortalTabItem(
      'Overview',
      Icons.dashboard_outlined,
      TransporterPortalDashboardScreen(),
    ),
    const PortalTabItem(
      'Earnings',
      Icons.payments_outlined,
      EarningsScreen(),
    ),
    const PortalTabItem(
      'Fleet / routes',
      Icons.route_outlined,
      TransporterRoutesScreen(),
    ),
    const PortalTabItem(
      'Trucks On Route',
      Icons.local_shipping_outlined,
      TrucksOnRouteScreen(),
    ),
    const PortalTabItem(
      'Reconciliations',
      Icons.balance_outlined,
      TransporterReconciliationsScreen(),
    ),
    const PortalTabItem(
      'Tracking',
      Icons.track_changes_outlined,
      TransporterRequestTrackingScreen(),
    ),
    const PortalTabItem(
      'Live map',
      Icons.gps_fixed_rounded,
      LiveTripMapScreen(),
    ),
    const PortalTabItem(
      'Truck locations',
      Icons.map_outlined,
      TransporterTruckLocationsScreen(),
    ),
    const PortalTabItem(
      'Truck positions',
      Icons.place_outlined,
      TransporterTruckPositionsScreen(),
    ),
    const PortalTabItem(
      'Maintenance',
      Icons.build_circle_outlined,
      TransporterMaintenanceScreen(),
    ),
    const PortalTabItem(
      'Fuel & costs',
      Icons.local_gas_station_outlined,
      FuelCostsScreen(),
    ),
    const PortalTabItem(
      'Compliance',
      Icons.verified_user_outlined,
      ComplianceScreen(),
    ),
    const PortalTabItem('Driver', Icons.local_shipping_outlined, DriverTabScreen()),
    const PortalTabItem('Admin', Icons.admin_panel_settings_outlined, AdminTabScreen()),
    if (includeManagement)
      const PortalTabItem('Management', Icons.manage_accounts_outlined, ManagementTabScreen()),
    const PortalTabItem('Workspace', Icons.widgets_outlined, TransporterTabScreen()),
  ];
}

List<PortalTabItem> _buyerPortalTabs({required bool includeManagement}) {
  return [
    const PortalTabItem(
      'Dashboard',
      Icons.dashboard_outlined,
      BuyerPortalDashboardScreen(),
    ),
    const PortalTabItem(
      'Routes & Mines',
      Icons.alt_route_outlined,
      BuyerRoutesMinesScreen(),
    ),
    const PortalTabItem(
      'Requests',
      Icons.assignment_outlined,
      BuyerRequestsScreen(),
    ),
    const PortalTabItem(
      'Waybills',
      Icons.description_outlined,
      BuyerWaybillsScreen(),
    ),
    const PortalTabItem(
      'Loads & value',
      Icons.payments_outlined,
      BuyerLoadsValueScreen(),
    ),
    const PortalTabItem(
      'Reconciliations',
      Icons.balance_outlined,
      BuyerReconciliationsScreen(),
    ),
    const PortalTabItem(
      'Compliance',
      Icons.verified_user_outlined,
      ComplianceScreen(),
    ),
    const PortalTabItem(
      'Live map',
      Icons.gps_fixed_rounded,
      LiveTripMapScreen(),
    ),
    const PortalTabItem(
      'Truck locations',
      Icons.map_outlined,
      BuyerTruckLocationsScreen(),
    ),
    const PortalTabItem('Admin', Icons.admin_panel_settings_outlined, AdminTabScreen()),
    if (includeManagement)
      const PortalTabItem('Management', Icons.manage_accounts_outlined, ManagementTabScreen()),
    const PortalTabItem('Workspace', Icons.shopping_bag_outlined, BuyerTabScreen()),
  ];
}

/// Central navigation rules for the portal shell (DRY).
abstract final class PortalNavigation {
  /// Sidebar index on `/home` for buyer portal tabs (matches [_buyerPortalTabs] order).
  static int buyerHomeTabIndexForLabel(String label, {required bool includeManagementTab}) {
    final tabs = _buyerPortalTabs(includeManagement: includeManagementTab);
    final i = tabs.indexWhere((t) => t.label == label);
    return i >= 0 ? i : 0;
  }

  static List<PortalTabItem> companyTabs(OrgType orgType) {
    switch (orgType) {
      case OrgType.mineSupplier:
        return [
          const PortalTabItem(
            'Overview',
            Icons.dashboard_outlined,
            MineSupplierPortalDashboardScreen(),
          ),
          const PortalTabItem('Supervisor', Icons.supervisor_account_outlined, SupervisorViewScreen()),
          const PortalTabItem('Production', Icons.terrain_outlined, MineProductionScreen()),
          const PortalTabItem('Quality', Icons.science_outlined, MineQualityScreen()),
          const PortalTabItem('Buyers', Icons.handshake_outlined, MineSupplierBuyersDetailScreen()),
          const PortalTabItem('Requests', Icons.assignment_outlined, BuyerRequestsScreen(isMine: true)),
          const PortalTabItem('Reconciliations', Icons.balance_outlined, MineReconciliationsScreen()),
          const PortalTabItem('Compliance', Icons.verified_user_outlined, ComplianceScreen()),
          const PortalTabItem('Live map', Icons.gps_fixed_rounded, LiveTripMapScreen()),
          const PortalTabItem('Truck locations', Icons.map_outlined, MineSupplierTruckLocationsScreen()),
          const PortalTabItem('Security', Icons.security_rounded, SecurityCheckinScreen()),
          const PortalTabItem('Controller', Icons.tune_rounded, LoadControllerScreen()),
          const PortalTabItem('Admin', Icons.admin_panel_settings_outlined, AdminTabScreen()),
          const PortalTabItem('Management', Icons.manage_accounts_outlined, ManagementTabScreen()),
          const PortalTabItem('Mine/Supplier', Icons.account_tree_outlined, MineSupplierTabScreen()),
        ];
      case OrgType.buyer:
        return _buyerPortalTabs(includeManagement: true);
      case OrgType.transporter:
        return _transporterPortalTabs(includeManagement: true);
    }
  }

  static List<PortalTabItem> employeeTabs(
    OrgType orgType,
    UserRole? role,
    Widget dashboardScreen,
  ) {
    if (role == null) return const [];

    switch (orgType) {
      case OrgType.buyer:
        if (role == UserRole.admin || role == UserRole.management) {
          return [
            ..._buyerPortalTabs(
              includeManagement: role == UserRole.management,
            ),
            const PortalTabItem('Profile', Icons.person_outline_rounded, ProfileScreen()),
          ];
        }
        break;
      case OrgType.transporter:
        if (role == UserRole.driver) {
          // A driver only needs their own routes + read-only map/position views
          // and their own record — not fleet management, route acceptance, or
          // reconciliation (those belong to the transporter admin/management).
          return [
            PortalTabItem('Dashboard', Icons.dashboard_customize_outlined, dashboardScreen),
            const PortalTabItem('My routes', Icons.alt_route_outlined, DriverRoutesScreen()),
            ..._transporterPortalTabs(includeManagement: false).where((t) =>
                t.label == 'Live map' ||
                t.label == 'Truck locations' ||
                t.label == 'Truck positions' ||
                t.label == 'Driver'),
            const PortalTabItem('Profile', Icons.person_outline_rounded, ProfileScreen()),
          ];
        }
        if (role == UserRole.admin || role == UserRole.management) {
          return [
            PortalTabItem('Dashboard', Icons.dashboard_customize_outlined, dashboardScreen),
            ..._transporterPortalTabs(
              includeManagement: role == UserRole.management,
            ),
            const PortalTabItem('Profile', Icons.person_outline_rounded, ProfileScreen()),
          ];
        }
        break;
      case OrgType.mineSupplier:
        return _mineSupplierEmployeeTabs(role, dashboardScreen);
    }

    final tabs = <PortalTabItem>[
      PortalTabItem('Dashboard', Icons.dashboard_customize_outlined, dashboardScreen),
      const PortalTabItem('Profile', Icons.person_outline_rounded, ProfileScreen()),
    ];
    return tabs;
  }

  static List<PortalTabItem> _mineSupplierEmployeeTabs(
    UserRole role,
    Widget dashboardScreen,
  ) {
    const profile =
        PortalTabItem('Profile', Icons.person_outline_rounded, ProfileScreen());

    // Security guards and load controllers get ONLY their one operational
    // screen (the same one the org sees on its Security / Controller tab) plus
    // their personal profile — nothing else.
    if (role == UserRole.security) {
      return const [
        PortalTabItem('Security', Icons.security_rounded, SecurityCheckinScreen()),
        profile,
      ];
    }
    if (role == UserRole.controllerWB) {
      return const [
        PortalTabItem('Controller', Icons.tune_rounded, LoadControllerScreen()),
        profile,
      ];
    }
    // The Supervisor/Foreman maintains stockpiles (§4) and records the pit's
    // production — give them the Supervisor + Production screens (and their
    // dashboard + profile), nothing else.
    if (role == UserRole.supervisorForeman) {
      return [
        PortalTabItem(
            'Dashboard', Icons.dashboard_customize_outlined, dashboardScreen),
        const PortalTabItem(
            'Supervisor', Icons.supervisor_account_outlined, SupervisorViewScreen()),
        const PortalTabItem(
            'Production', Icons.terrain_outlined, MineProductionScreen()),
        profile,
      ];
    }

    final tabs = <PortalTabItem>[
      PortalTabItem('Dashboard', Icons.dashboard_customize_outlined, dashboardScreen),
    ];

    switch (role) {
      case UserRole.admin:
      case UserRole.management:
        tabs.add(const PortalTabItem(
          'Overview',
          Icons.dashboard_outlined,
          MineSupplierPortalDashboardScreen(),
        ));
        tabs.addAll(const [
          PortalTabItem('Supervisor', Icons.supervisor_account_outlined, SupervisorViewScreen()),
          PortalTabItem('Production', Icons.terrain_outlined, MineProductionScreen()),
          PortalTabItem('Quality', Icons.science_outlined, MineQualityScreen()),
          PortalTabItem('Buyers', Icons.handshake_outlined, MineSupplierBuyersDetailScreen()),
          PortalTabItem('Requests', Icons.assignment_outlined, BuyerRequestsScreen(isMine: true)),
          PortalTabItem('Reconciliations', Icons.balance_outlined, MineReconciliationsScreen()),
          PortalTabItem('Compliance', Icons.verified_user_outlined, ComplianceScreen()),
          PortalTabItem('Live map', Icons.gps_fixed_rounded, LiveTripMapScreen()),
          PortalTabItem('Truck locations', Icons.map_outlined, MineSupplierTruckLocationsScreen()),
          PortalTabItem('Security', Icons.security_rounded, SecurityCheckinScreen()),
          PortalTabItem('Controller', Icons.tune_rounded, LoadControllerScreen()),
          PortalTabItem('Admin', Icons.admin_panel_settings_outlined, AdminTabScreen()),
        ]);
        if (role == UserRole.management) {
          tabs.add(const PortalTabItem('Management', Icons.manage_accounts_outlined, ManagementTabScreen()));
        }
        break;
      default:
        break;
    }

    tabs.add(const PortalTabItem('Profile', Icons.person_outline_rounded, ProfileScreen()));
    return tabs;
  }
}
