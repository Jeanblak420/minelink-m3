import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/providers/company_access_provider.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/widgets/notification_button_tab.dart';
import 'package:flutter_application_1/features/tabs/widgets/operations_workspace.dart';

class ControllerTabScreen extends ConsumerWidget {
  const ControllerTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(companyAccessProvider);
    final notificationState = ref.watch(notificationProvider);
    final company = access.company;
    final employees = access.visibleEmployees;
    final canManageEmployees = access.canManageEmployees;
    final controllers = employees
        .where((employee) => employee.role == UserRole.controllerWB)
        .toList();
    final pendingRoleAssignments = canManageEmployees
        ? employees
              .where((employee) => employee.status == 'pending_role')
              .toList()
        : const <Employee>[];

    return OperationsWorkspace(
      title: 'Controller / Weighbridge Workspace',
      subtitle: company == null
          ? 'Weighbridge records will surface here after the company profile loads.'
          : 'Track weighbridge access and controller readiness for ${company.companyName}.',
      metrics: [
        WorkspaceMetric(
          label: 'Controllers',
          value: controllers.length.toString(),
          icon: Icons.scale_outlined,
        ),
        WorkspaceMetric(
          label: 'Pending roles',
          value: pendingRoleAssignments.length.toString(),
          icon: Icons.assignment_late_outlined,
        ),
        WorkspaceMetric(
          label: 'Active team',
          value: controllers
              .where((employee) => employee.status == 'active')
              .length
              .toString(),
          icon: Icons.check_circle_outline,
        ),
        WorkspaceMetric(
          label: 'Unread',
          value: notificationState.unreadCount.toString(),
          icon: Icons.notifications_outlined,
        ),
      ],
      actions: [
        WorkspaceAction(
          label: 'Weighbridge Console',
          icon: Icons.scale_outlined,
          onPressed: () => context.go('/operations?tab=weighbridge'),
          isPrimary: true,
        ),
        if (canManageEmployees)
          WorkspaceAction(
            label: 'Manage Employees',
            icon: Icons.groups_outlined,
            onPressed: () => context.go('/company-employees'),
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
      sectionTitle: 'Readiness Queue',
      sectionTrailing: const NotificationButtonTab(role: UserRole.controllerWB),
      items: [
        ...pendingRoleAssignments.take(3).map(_buildPendingRoleItem),
        ...controllers.take(4).map(_buildControllerItem),
      ],
      emptyTitle: 'No controller activity yet',
      emptyMessage:
          'Role assignments and future weighbridge records will appear here once the operation starts recording them.',
      emptyIcon: Icons.scale_outlined,
    );
  }

  WorkspaceItem _buildPendingRoleItem(Employee employee) {
    return WorkspaceItem(
      title: employee.fullName,
      subtitle: 'Accepted into the company and waiting for role assignment.',
      icon: Icons.assignment_ind_outlined,
      trailing: 'Pending role',
    );
  }

  WorkspaceItem _buildControllerItem(Employee employee) {
    return WorkspaceItem(
      title: employee.fullName,
      subtitle: employee.status == 'active'
          ? 'Ready for weighbridge operations'
          : 'Controller account is not active yet',
      icon: Icons.scale_outlined,
      trailing: employee.status == 'active' ? 'Active' : 'Inactive',
    );
  }
}
