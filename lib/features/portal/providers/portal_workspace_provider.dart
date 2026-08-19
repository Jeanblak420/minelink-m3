import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/home/widgets/employee_dashboard_tab.dart';
import 'package:flutter_application_1/features/portal/portal_navigation.dart';
import 'package:flutter_application_1/features/portal/portal_tabs_resolver.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';

enum PortalWorkspacePhase {
  preparingWorkspace,
  loadingCompanyAccess,
  loadingEmployeeAccess,
  connectingToCompany,
  finalizingAccess,
  preparingNavigation,
  selectingCompany,

  /// A platform admin on a `/portal/*` path. They have no employee row and no
  /// company — by design — so every employee-shaped gate below reads them as a
  /// broken employee and the shell rendered **"Error loading workspace ·
  /// Exception: Employee not found"** with a Retry that could never succeed.
  ///
  /// Reproduced 2026-08-17 by signing in as a platform admin while the sign-in
  /// route still carried `?from=/portal/buyer` (a stale return path from the
  /// previous session on that browser). The router deliberately lets platform
  /// admins onto `/portal/*` — "company-mirror observer mode" — so redirecting
  /// them away would remove a real capability; the fault is that the workspace
  /// had no idea what an observer was.
  platformAdminObserver,

  ready,
}

enum PortalRetryAction { none, companyProfile, employeeProfile }

class PortalWorkspaceModel {
  final PortalWorkspacePhase phase;
  final String title;
  final String message;
  final PortalRetryAction retryAction;
  final List<PortalTabItem>? tabs;
  final bool isEmployeeWithoutRole;
  final bool isMineSupplier;
  final String workspaceName;
  final String operatorName;
  final String roleLabel;

  /// Uploaded profile image for the signed-in operator (company logo for
  /// company users, profile photo for employees). Null when none is set, in
  /// which case the sidebar user card falls back to initials.
  final String? avatarUrl;

  const PortalWorkspaceModel({
    required this.phase,
    this.title = '',
    this.message = '',
    this.retryAction = PortalRetryAction.none,
    this.tabs,
    this.isEmployeeWithoutRole = false,
    this.isMineSupplier = false,
    this.workspaceName = '',
    this.operatorName = '',
    this.roleLabel = '',
    this.avatarUrl,
  });

  bool get showPortalChrome => phase == PortalWorkspacePhase.ready;
}

bool portalNeedsManagedSync(
  AuthState authState,
  EmployeeState employeeState,
  CompanyState companyState,
) {
  if (authState.userType?.isEmployee != true || employeeState.employee == null) {
    return false;
  }

  final employee = employeeState.employee!;
  final canManage = employee.companyId != null &&
      employee.status == 'active' &&
      (employee.role == UserRole.admin || employee.role == UserRole.management);

  if (canManage) {
    return companyState.company?.id != employee.companyId || !companyState.canManageEmployees;
  }

  return companyState.company != null ||
      companyState.canManageEmployees ||
      companyState.employees.isNotEmpty;
}

String portalOwnerName(dynamic company) {
  final value = [company.ceoFirstName, company.ceoLastName]
      .whereType<String>()
      .where((part) => part.trim().isNotEmpty)
      .join(' ');
  return value.isEmpty ? company.companyName : value;
}

String portalFormatEmployeeStatus(String? status) {
  switch (status) {
    case 'pending_company':
      return 'Pending company approval';
    case 'pending_role':
      return 'Pending role assignment';
    case 'active':
      return 'Active';
    case 'rejected':
      return 'Request declined';
    case 'inactive':
      return 'Inactive';
    default:
      return 'Unknown';
  }
}

final portalWorkspaceProvider = Provider<PortalWorkspaceModel>((ref) {
  final authState = ref.watch(authStateProvider);
  final companyState = ref.watch(companyProvider);
  final employeeState = ref.watch(employeeProvider);

  if (authState.user == null || authState.isLoading || authState.userType == null) {
    return const PortalWorkspaceModel(
      phase: PortalWorkspacePhase.preparingWorkspace,
      title: 'Preparing workspace',
      message: 'Securing session...',
    );
  }

  // A platform admin has no employee row and no company. Answer that before
  // the employee/company gates below, which would otherwise report the absence
  // as a failure to load something that was never going to be there.
  if (ref.watch(currentPlatformRoleProvider).valueOrNull?.isSuperAdmin ==
      true) {
    return const PortalWorkspaceModel(
      phase: PortalWorkspacePhase.platformAdminObserver,
      title: 'Platform admin',
      message: 'You are signed in as a MineLink platform admin, so you have no '
          'company workspace of your own. Open the console to see every '
          'company, request and load.',
    );
  }

  if (authState.userType?.isCompany == true && companyState.company == null) {
    return PortalWorkspaceModel(
      phase: PortalWorkspacePhase.loadingCompanyAccess,
      title: companyState.error == null ? 'Loading company access' : 'Error loading workspace',
      message: companyState.error ?? 'Fetching company details...',
      retryAction: companyState.error != null ? PortalRetryAction.companyProfile : PortalRetryAction.none,
    );
  }

  if (authState.userType?.isEmployee == true) {
    if (employeeState.employee == null) {
      return PortalWorkspaceModel(
        phase: PortalWorkspacePhase.loadingEmployeeAccess,
        title: employeeState.error == null ? 'Loading employee access' : 'Error loading workspace',
        message: employeeState.error ?? 'Preparing profile...',
        retryAction: employeeState.error != null ? PortalRetryAction.employeeProfile : PortalRetryAction.none,
      );
    }

    if (employeeState.employee!.companyId != null &&
        employeeState.company == null &&
        employeeState.error == null) {
      return const PortalWorkspaceModel(
        phase: PortalWorkspacePhase.connectingToCompany,
        title: 'Connecting to company',
        message: 'Loading company details...',
      );
    }
  }

  if (portalNeedsManagedSync(authState, employeeState, companyState)) {
    final emp = employeeState.employee;
    if (emp != null) {
      final canManage = emp.companyId != null &&
          emp.status == 'active' &&
          (emp.role == UserRole.admin || emp.role == UserRole.management);
      if (canManage && companyState.company?.id != emp.companyId) {
        return const PortalWorkspaceModel(
          phase: PortalWorkspacePhase.finalizingAccess,
          title: 'Finalizing access',
          message: 'Loading team workspace...',
        );
      }
    }
  }

  // A user taken off a company resolves here, exactly as any never-linked user
  // does. `remove_company_employee` nulls `company_id`, so `isLinkedToCompany`
  // is false and this branch catches them before any tab set is built.
  //
  // This check used to be followed by a `PortalWorkspacePhase.dismissed`
  // branch, removed with the dismissal feature (client ruling, 2026-08-11).
  // Removing it cannot open a fall-through: the branch was already unreachable
  // for a removed user (this check precedes it and `remove_company_employee`
  // unlinks them), and after `20260811180000` dropped the three dismissal RPCs
  // nothing in the database can set `is_dismissed = true` or
  // `status = 'dismissed'` at all — verified 0 writers of either, 0 rows.
  // Guarded by `test/portal_workspace_removed_employee_test.dart`.
  if (authState.userType?.isEmployee == true &&
      employeeState.employee != null &&
      !employeeState.isLinkedToCompany) {
    return const PortalWorkspaceModel(phase: PortalWorkspacePhase.selectingCompany);
  }

  final isEmployeeWithoutRole = authState.userType?.isEmployee == true &&
      employeeState.employee != null &&
      employeeState.employee!.companyId != null &&
      employeeState.employee!.role == null;

  final roleLabel = employeeState.employee?.role?.label;
  final dashboard = roleLabel != null
      ? EmployeeDashboardTab(roleName: roleLabel)
      : const SizedBox.shrink();

  final tabs = resolvePortalTabs(
    authState: authState,
    companyState: companyState,
    employeeState: employeeState,
    isEmployeeWithoutRole: isEmployeeWithoutRole,
    employeeDashboard: dashboard,
  );

  if (tabs.isEmpty) {
    return const PortalWorkspaceModel(
      phase: PortalWorkspacePhase.preparingNavigation,
      title: 'Preparing navigation',
      message: 'Matching access level...',
    );
  }

  final workspaceName = authState.userType?.isCompany == true
      ? companyState.company!.companyName
      : employeeState.company?.companyName ?? '';

  final operatorName = authState.userType?.isCompany == true
      ? portalOwnerName(companyState.company!)
      : employeeState.employee?.fullName ?? authState.user?.email ?? 'Team member';

  final role = authState.userType?.isCompany == true
      ? companyState.company!.orgType.label
      : employeeState.employee?.role?.label ??
            portalFormatEmployeeStatus(employeeState.employee?.status);

  final avatarUrl = authState.userType?.isCompany == true
      ? companyState.company!.logoUrl
      : employeeState.employee?.profilePhotoUrl;

  final isMineSupplier = authState.userType?.isCompany == true
      ? companyState.company!.orgType == OrgType.mineSupplier
      : employeeState.company?.orgType == OrgType.mineSupplier;

  return PortalWorkspaceModel(
    phase: PortalWorkspacePhase.ready,
    tabs: tabs,
    isEmployeeWithoutRole: isEmployeeWithoutRole,
    isMineSupplier: isMineSupplier,
    workspaceName: workspaceName,
    operatorName: operatorName,
    roleLabel: role,
    avatarUrl: avatarUrl,
  );
});
