import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/widgets/notification_button_tab.dart';
import 'package:flutter_application_1/features/tabs/widgets/operations_workspace.dart';

class BuyerTabScreen extends ConsumerWidget {
  const BuyerTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyState = ref.watch(companyProvider);
    final notificationState = ref.watch(notificationProvider);
    final employees = [...companyState.employees]
      ..sort(
        (a, b) =>
            (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt),
      );

    final activeCount = employees
        .where((employee) => employee.status == 'active')
        .length;
    final adminCount = employees
        .where(
          (employee) =>
              employee.role == UserRole.admin ||
              employee.role == UserRole.management,
        )
        .length;

    return OperationsWorkspace(
      title: 'Buyer Workspace',
      subtitle: companyState.company == null
          ? 'Buyer workflows will appear after your company profile has loaded.'
          : 'Monitor live company, employee, and notification activity for ${companyState.company!.companyName}.',
      metrics: [
        WorkspaceMetric(
          label: 'Employees',
          value: employees.length.toString(),
          icon: Icons.people_alt_outlined,
        ),
        WorkspaceMetric(
          label: 'Active',
          value: activeCount.toString(),
          icon: Icons.check_circle_outline,
        ),
        WorkspaceMetric(
          label: 'Admins & Mgmt',
          value: adminCount.toString(),
          icon: Icons.manage_accounts_outlined,
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
          icon: Icons.receipt_long_outlined,
          onPressed: () => context.go('/operations?tab=transactions'),
        ),
        WorkspaceAction(
          label: 'Communications',
          icon: Icons.forum_outlined,
          onPressed: () => context.go('/communications'),
        ),
      ],
      sectionTitle: 'Buyer Team Activity',
      sectionTrailing: const NotificationButtonTab(role: UserRole.buyer),
      items: employees.take(6).map((employee) {
        return WorkspaceItem(
          title: employee.fullName,
          subtitle:
              '${employee.role?.label ?? 'No role assigned'} • ${_formatStatus(employee.status)}',
          icon: Icons.person_outline,
          trailing: _formatStatus(employee.status),
        );
      }).toList(),
      emptyTitle: 'No buyer team members yet',
      emptyMessage:
          'Add your first admin or management user to begin operating this buyer workspace with live records.',
      emptyIcon: Icons.shopping_cart_outlined,
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
      case 'suspended':
        return 'Suspended';
      default:
        return 'Unknown';
    }
  }
}
