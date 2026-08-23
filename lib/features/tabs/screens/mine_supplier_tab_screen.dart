import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/widgets/notification_button_tab.dart';
import 'package:flutter_application_1/features/tabs/widgets/operations_workspace.dart';

class MineSupplierTabScreen extends ConsumerWidget {
  const MineSupplierTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyState = ref.watch(companyProvider);
    final notificationState = ref.watch(notificationProvider);
    final employees = companyState.employees;
    final activeEmployees = employees
        .where((employee) => employee.status == 'active')
        .length;
    final pendingApprovals = employees
        .where((employee) => employee.status == 'pending_company')
        .length;
    final recentEmployees = [...employees]
      ..sort(
        (a, b) =>
            (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt),
      );

    return OperationsWorkspace(
      title: 'Mine/Supplier workspace',
      subtitle: companyState.company == null
          ? 'Production and mineral workflows will appear here once your company profile is loaded.'
          : 'Manage the real operating team behind ${companyState.company!.companyName}.',
      metrics: [
        WorkspaceMetric(
          label: 'Employees',
          value: employees.length.toString(),
          icon: Icons.people_alt_outlined,
        ),
        WorkspaceMetric(
          label: 'Active',
          value: activeEmployees.toString(),
          icon: Icons.check_circle_outline,
        ),
        WorkspaceMetric(
          label: 'Pending',
          value: pendingApprovals.toString(),
          icon: Icons.pending_actions_outlined,
        ),
        WorkspaceMetric(
          label: 'Unread',
          value: notificationState.unreadCount.toString(),
          icon: Icons.notifications_outlined,
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
          onPressed: () => context.go('/operations?tab=minerals'),
        ),
        WorkspaceAction(
          label: 'Communications',
          icon: Icons.forum_outlined,
          onPressed: () => context.go('/communications'),
        ),
      ],
      sectionTitle: 'Recent Team Activity',
      sectionTrailing: const NotificationButtonTab(role: UserRole.mineSupplier),
      items: recentEmployees.take(6).map((employee) {
        return WorkspaceItem(
          title: employee.fullName,
          subtitle:
              '${employee.role?.label ?? 'No role assigned'} • ${_formatStatus(employee.status)}',
          icon: Icons.person_outline,
          trailing: _formatStatus(employee.status),
        );
      }).toList(),
      emptyTitle: 'No operating team yet',
      emptyMessage:
          'Add employees and approve company requests to build out the live mine or supplier workspace.',
      emptyIcon: Icons.domain_outlined,
    );
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
      default:
        return 'Unknown';
    }
  }
}
