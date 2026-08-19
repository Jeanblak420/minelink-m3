import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/providers/company_access_provider.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/notifications/widgets/notification_button_tab.dart';
import 'package:flutter_application_1/features/tabs/widgets/operations_workspace.dart';

class AdminTabScreen extends ConsumerWidget {
  const AdminTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(companyAccessProvider);
    final company = access.company;
    final employees = [...access.visibleEmployees]
      ..sort(
        (a, b) =>
            (b.updatedAt ?? b.createdAt).compareTo(a.updatedAt ?? a.createdAt),
      );

    final activeCount = employees
        .where((employee) => employee.status == 'active')
        .length;

    return OperationsWorkspace(
      title: 'Admin Workspace',
      subtitle: company == null
          ? 'Load your company profile to manage employees and account settings.'
          : 'Manage ${company.companyName} users, approvals, and profile data with live records.',
      metrics: [
        WorkspaceMetric(
          label: 'Employees',
          value: employees.length.toString(),
          icon: Icons.people_alt_outlined,
        ),
        WorkspaceMetric(
          label: 'Active',
          value: activeCount.toString(),
          icon: Icons.verified_user_outlined,
        ),
      ],
      actions: [
        WorkspaceAction(
          label: 'Manage Employees',
          icon: Icons.group_add_outlined,
          onPressed: () => context.go('/company-employees'),
          isPrimary: true,
        ),
      ],
      sectionTitle: 'Latest Team Updates',
      sectionTrailing: const NotificationButtonTab(role: UserRole.admin),
      items: employees.take(6).map(_buildEmployeeItem).toList(),
      emptyTitle: 'No employees yet',
      emptyMessage:
          'Start by adding your first company user or approving a pending employee request.',
      emptyIcon: Icons.group_outlined,
    );
  }

  WorkspaceItem _buildEmployeeItem(Employee employee) {
    return WorkspaceItem(
      title: employee.fullName,
      subtitle:
          '${employee.role?.label ?? 'No role assigned'} • ${_formatStatus(employee.status)}',
      icon: employee.role == null ? Icons.person_outline : Icons.badge_outlined,
      trailing: _formatStatus(employee.status),
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
