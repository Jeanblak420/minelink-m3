import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_dashboard_navigation.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_widgets.dart';
import 'package:go_router/go_router.dart';

class EmployeeDashboardTab extends ConsumerWidget {
  final String roleName;

  const EmployeeDashboardTab({super.key, required this.roleName});

  String _formatStatus(String? status) {
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
      case 'suspended':
        return 'Suspended';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final employeeState = ref.watch(employeeProvider);
    final notificationState = ref.watch(notificationProvider);
    final company = employeeState.company;
    final employee = employeeState.employee;
    final metrics = <({String label, String value, IconData icon, VoidCallback? onTap, String? tooltip})>[
      (
        label: 'Role',
        value: roleName,
        icon: Icons.badge_outlined,
        onTap: () => context.go('/profile'),
        tooltip: 'Open profile — role',
      ),
      (
        label: 'Company',
        value: company?.companyName ?? 'Not linked',
        icon: Icons.business_outlined,
        onTap: company == null ? null : () => context.go('/profile'),
        tooltip: company == null ? null : 'Open profile — company',
      ),
      (
        label: 'Status',
        value: _formatStatus(employee?.status),
        icon: Icons.verified_user_outlined,
        onTap: () => context.go('/profile'),
        tooltip: 'Open profile — account status',
      ),
      (
        label: 'Alerts',
        value: notificationState.unreadCount.toString(),
        icon: Icons.notifications_outlined,
        onTap: () => openPortalRoute(ref, context, '/notifications'),
        tooltip: 'Open notifications',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dashboard',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            company == null
                ? 'Account active. Link to a company to unlock workflows.'
                : 'Signed in as ${employee?.fullName ?? authState.user?.email ?? 'team member'}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 800
                  ? 4
                  : constraints.maxWidth > 400
                      ? 2
                      : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 2.5,
                ),
                itemCount: metrics.length,
                itemBuilder: (context, index) {
                  final m = metrics[index];
                  return PortalStatCard(
                    label: m.label,
                    value: m.value,
                    icon: m.icon,
                    onTap: m.onTap,
                    tooltip: m.tooltip,
                  );
                },
              );
            },
          ),
          const SizedBox(height: 32),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              ActionChip(
                avatar: const Icon(Icons.person_outline, size: 18),
                label: const Text('Update Profile'),
                onPressed: () => context.go('/profile'),
              ),
              ActionChip(
                avatar: const Icon(Icons.notifications_outlined, size: 18),
                label: const Text('View Notifications'),
                onPressed: () => context.go('/notifications'),
              ),
              if (company?.orgType == OrgType.transporter && employee?.role == UserRole.driver)
                ActionChip(
                  avatar: const Icon(Icons.local_shipping_outlined, size: 18),
                  label: const Text('Open Fleet'),
                  onPressed: () => context.go('/fleet-management'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
