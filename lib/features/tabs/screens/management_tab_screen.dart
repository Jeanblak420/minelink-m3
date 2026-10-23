import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/providers/company_access_provider.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/widgets/notification_button_tab.dart';
import 'package:flutter_application_1/features/tabs/widgets/operations_workspace.dart';

class ManagementTabScreen extends ConsumerWidget {
  const ManagementTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(companyAccessProvider);
    final notificationState = ref.watch(notificationProvider);
    final company = access.company;
    final employees = [...access.visibleEmployees]
      ..sort((a, b) => _priority(a).compareTo(_priority(b)));

    final leadershipCount = employees
        .where(
          (employee) =>
              employee.role == UserRole.admin ||
              employee.role == UserRole.management,
        )
        .length;
    final pendingCount = employees
        .where(
          (employee) =>
              employee.status == 'pending_company' ||
              employee.status == 'pending_role',
        )
        .length;

    return OperationsWorkspace(
      title: 'Management Workspace',
      subtitle: company == null
          ? 'Your management overview will appear once the company profile has loaded.'
          : 'Track leadership, approvals, and operational readiness for ${company.companyName}.',
      metrics: [
        WorkspaceMetric(
          label: 'Team',
          value: employees.length.toString(),
          icon: Icons.people_alt_outlined,
        ),
        WorkspaceMetric(
          label: 'Leadership',
          value: leadershipCount.toString(),
          icon: Icons.manage_accounts_outlined,
        ),
        WorkspaceMetric(
          label: 'Pending',
          value: pendingCount.toString(),
          icon: Icons.pending_actions_outlined,
        ),
        WorkspaceMetric(
          label: 'Unread',
          value: notificationState.unreadCount.toString(),
          icon: Icons.notifications_active_outlined,
        ),
      ],
      actions: [
        WorkspaceAction(
          label: 'Manage Employees',
          icon: Icons.groups_outlined,
          onPressed: () => context.go('/company-employees'),
          isPrimary: true,
        ),
        WorkspaceAction(
          label: 'Company Profile',
          icon: Icons.business_outlined,
          onPressed: () => context.go('/profile'),
        ),
        WorkspaceAction(
          label: 'Operations Hub',
          icon: Icons.factory_outlined,
          onPressed: () => context.go('/operations'),
        ),
        WorkspaceAction(
          label: 'Communications',
          icon: Icons.forum_outlined,
          onPressed: () => context.go('/communications'),
        ),
        if (company?.orgType == OrgType.transporter)
          WorkspaceAction(
            label: 'Fleet',
            icon: Icons.local_shipping_outlined,
            onPressed: () => context.go('/fleet-management'),
          ),
      ],
      sectionTitle: 'Operational Queue',
      sectionTrailing: const NotificationButtonTab(role: UserRole.management),
      items: employees.take(6).map(_buildEmployeeItem).toList(),
      emptyTitle: 'No management activity yet',
      emptyMessage:
          'Approvals, new employees, and role changes will appear here once the team starts using the platform.',
      emptyIcon: Icons.manage_search_outlined,
    );
  }

  WorkspaceItem _buildEmployeeItem(Employee employee) {
    return WorkspaceItem(
      title: employee.fullName,
      subtitle:
          '${employee.role?.label ?? 'No role assigned'} • ${_formatStatus(employee.status)}',
      icon: employee.status == 'pending_company'
          ? Icons.pending_actions_outlined
          : Icons.person_outline,
      trailing: _formatStatus(employee.status),
    );
  }

  int _priority(Employee employee) {
    if (employee.status == 'pending_company') {
      return 0;
    }
    if (employee.status == 'pending_role') {
      return 1;
    }
    return 2;
  }

  String _formatStatus(String? status) {
    switch (status) {
      case 'pending_company':
        return 'Pending company';
      case 'pending_role':
        return 'Pending role';
      case 'active':
        return 'Active';
      case 'rejected':
        return 'Declined';
      case 'inactive':
        return 'Inactive';
      case 'suspended':
        return 'Suspended';
      default:
        return 'Unknown';
    }
  }
}
