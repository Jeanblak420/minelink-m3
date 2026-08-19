import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/employee/screens/waiting_for_role_screen.dart';
import 'package:flutter_application_1/features/profile/screens/profile_screen.dart';
import 'package:flutter_application_1/features/portal/portal_navigation.dart';

/// The single tab shown when we cannot resolve a workspace yet — either the
/// company row has not loaded, or the session is in a state that carries no
/// operational surface at all. Never an empty list: an empty sidebar reads as
/// a broken app rather than as a pending one.
const _waitingTab = PortalTabItem(
  'Account',
  Icons.hourglass_empty_rounded,
  WaitingForRoleScreen(),
);

const _profileTab = PortalTabItem(
  'Profile',
  Icons.person_outline_rounded,
  ProfileScreen(),
);

/// Builds the sidebar tab list for the current session.
///
/// Every branch guards its own inputs. The company row is loaded
/// asynchronously alongside the profile, so any of these can legitimately be
/// null for a frame or two on cold start — and on a slow connection, for
/// considerably longer than that.
List<PortalTabItem> resolvePortalTabs({
  required AuthState authState,
  required CompanyState companyState,
  required EmployeeState employeeState,
  required bool isEmployeeWithoutRole,
  required Widget employeeDashboard,
}) {
  if (authState.userType?.isCompany == true) {
    final company = companyState.company;
    if (company == null) return const [_waitingTab];
    return PortalNavigation.companyTabs(company.orgType);
  }

  // An employee whose role has not been assigned yet has no operational
  // surface at all. They previously received `companyTabs(...)` — the
  // COMPLETE company-owner tab set, including Admin, Management, Load
  // Controller, Security and Reconciliations — which was a privilege
  // escalation by omission. They wait, and nothing else.
  //
  // The router enforces the same rule; this is the UX half of it.
  if (isEmployeeWithoutRole) {
    return const [_waitingTab];
  }

  final company = employeeState.company;
  final employee = employeeState.employee;
  if (company == null || employee == null) {
    return const [_waitingTab];
  }

  final tabs = PortalNavigation.employeeTabs(
    company.orgType,
    employee.role,
    employeeDashboard,
  );
  // employeeTabs returns an empty list for an unrecognised role. Falling
  // through to an empty sidebar leaves the user staring at blank chrome with
  // no way to sign out, so give them their own record at minimum.
  if (tabs.isEmpty) {
    return const [_waitingTab, _profileTab];
  }
  return tabs;
}
