import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/providers/company_access_provider.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/widgets/notification_button_tab.dart';
import 'package:flutter_application_1/features/tabs/widgets/operations_workspace.dart';

class SecurityTabScreen extends ConsumerWidget {
  const SecurityTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(companyAccessProvider);
    final notificationState = ref.watch(notificationProvider);
    final company = access.company;
    final employees = access.visibleEmployees;
    final canManageEmployees = access.canManageEmployees;
    final securityEmployees = employees
        .where((employee) => employee.role == UserRole.security)
        .toList();
    final pendingApprovals = canManageEmployees
        ? employees
              .where((employee) => employee.status == 'pending_company')
              .toList()
        : const <Employee>[];

    return OperationsWorkspace(
      title: 'Security Workspace',
      subtitle: company == null
          ? 'Security operations will appear after the company profile loads.'
          : 'Review security operations and live access updates for ${company.companyName}.',
      metrics: [
        WorkspaceMetric(
          label: 'Security team',
          value: securityEmployees.length.toString(),
          icon: Icons.security_outlined,
        ),
        WorkspaceMetric(
          label: 'Pending approvals',
          value: pendingApprovals.length.toString(),
          icon: Icons.pending_actions_outlined,
        ),
        WorkspaceMetric(
          label: 'Active team',
          value: securityEmployees
              .where((employee) => employee.status == 'active')
              .length
              .toString(),
          icon: Icons.verified_user_outlined,
        ),
        WorkspaceMetric(
          label: 'Unread',
          value: notificationState.unreadCount.toString(),
          icon: Icons.notifications_outlined,
        ),
      ],
      actions: [
        if (canManageEmployees)
          WorkspaceAction(
            label: 'Review Employees',
            icon: Icons.group_outlined,
            onPressed: () => context.go('/company-employees'),
            isPrimary: true,
          ),
        if (!canManageEmployees)
          WorkspaceAction(
            label: 'Security Console',
            icon: Icons.shield_outlined,
            onPressed: () => context.go('/operations?tab=security'),
            isPrimary: true,
          ),
        WorkspaceAction(
          label: 'Open Notifications',
          icon: Icons.notifications_outlined,
          onPressed: () => context.go('/notifications'),
        ),
        WorkspaceAction(
          label: 'Communications',
          icon: Icons.forum_outlined,
          onPressed: () => context.go('/communications'),
        ),
        if (!canManageEmployees)
          WorkspaceAction(
            label: 'My Profile',
            icon: Icons.person_outline,
            onPressed: () => context.go('/profile'),
          ),
      ],
      sectionTitle: 'Security Team and Approvals',
      sectionTrailing: const NotificationButtonTab(role: UserRole.security),
      items: [
        ...pendingApprovals.take(3).map(_buildPendingItem),
        ...securityEmployees.take(4).map(_buildSecurityItem),
      ],
      emptyTitle: 'No security records yet',
      emptyMessage:
          'Security staff and employee approvals will appear here as soon as they are created.',
      emptyIcon: Icons.security,
    );
  }

  WorkspaceItem _buildPendingItem(Employee employee) {
    return WorkspaceItem(
      title: employee.fullName,
      subtitle: 'Requested access to the company and is waiting for approval.',
      icon: Icons.pending_actions_outlined,
      trailing: 'Pending',
    );
  }

  WorkspaceItem _buildSecurityItem(Employee employee) {
    return WorkspaceItem(
      title: employee.fullName,
      subtitle: employee.role?.label ?? 'No role assigned',
      icon: Icons.shield_outlined,
      trailing: employee.status == 'active' ? 'Active' : 'Inactive',
    );
  }
}
