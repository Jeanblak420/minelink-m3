import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/employee/screens/request_declined_screen.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/notifications/widgets/notification_card.dart';
import 'package:flutter_application_1/features/portal/providers/portal_tab_index_provider.dart';
import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';
import 'package:flutter_application_1/core/routing/notifications_inbox_route.dart';
import 'package:flutter_application_1/core/routing/notifications_manage_route.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/super_admin/data/models/platform_role.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:go_router/go_router.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

enum _NotifFilter { all, unread, priority }

/// The bell's inbox.
///
/// **It draws no app bar of its own, and there is no flag for one.** There used
/// to be a `showAppBar` that defaulted to true, which the console turned off;
/// but EVERY route that mounts this screen is a leaf of one of the two
/// `ShellRoute`s, and both shells have already drawn a top bar carrying the
/// section name. So the flag's default was never right for anybody — the
/// portal's four `/notifications` routes all rendered a second bar reading
/// "Notifications" directly beneath a first one reading "Notifications", with
/// the page's own "Recent alerts and updates" heading under both. Three titles
/// in the first 200px. Photographed 2026-08-21.
class NotificationScreen extends ConsumerStatefulWidget {
  const NotificationScreen({super.key});

  @override
  ConsumerState<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends ConsumerState<NotificationScreen> {
  _NotifFilter _filter = _NotifFilter.all;

  // Helper method to get the user's role
  UserRole? _getUserRole() {
    final authState = ref.read(authStateProvider);

    if (authState.userType?.isCompany == true) {
      // Company users are considered admin role
      return UserRole.admin;
    } else if (authState.userType?.isEmployee == true) {
      final employeeState = ref.read(employeeProvider);
      return employeeState.employee?.role;
    }

    return null;
  }

  bool _isPlatformAdmin(PlatformRole? role) =>
      NotificationsInboxRoute.isPlatformAdmin(role);

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);
    final authState = ref.watch(authStateProvider);
    final platformRole = ref.watch(currentPlatformRoleProvider).valueOrNull;
    final inSuperAdminShell = _isPlatformAdmin(platformRole);
    final semantic = MlSemantic.of(context);

    final notifications = notificationState.notifications;
    final unread = notifications.where((n) => !n.isRead).length;
    final priority = notifications
        .where((n) => n.importance != NotificationImportance.normal)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MlPageHeader(
                title: 'Notifications',
                description: 'Recent alerts and updates for you and your '
                    'company.',
                meta: '$unread unread · ${notifications.length} total',
                padding: EdgeInsets.zero,
                actions: [
                  if (notifications.isNotEmpty)
                    MlButton.outline(
                      label: 'Mark all read',
                      icon: Icons.done_all,
                      compact: true,
                      onPressed: () => ref
                          .read(notificationProvider.notifier)
                          .markAllAsRead(),
                    ),
                  if (notifications.isNotEmpty)
                    MlButton.ghost(
                      label: 'Clear all',
                      icon: Icons.clear_all,
                      compact: true,
                      onPressed: () =>
                          _showClearConfirmationDialog(context, ref),
                    ),
                  MlButton.ghost(
                    label: 'View all',
                    icon: Icons.view_list_outlined,
                    compact: true,
                    onPressed: () {
                      context.go(
                        NotificationsManageRoute.location(
                          title: 'All notifications',
                          filterRole: _getUserRole(),
                          useSuperAdminShell: inSuperAdminShell,
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (notifications.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip(_NotifFilter.all, 'All', notifications.length),
                    _filterChip(_NotifFilter.unread, 'Unread', unread),
                    _filterChip(_NotifFilter.priority, 'Priority', priority),
                  ],
                ),
              ],
            ],
          ),
        ),
        Divider(height: 1, color: semantic.divider),
        Expanded(
          child: notificationState.error != null
              ? _buildErrorState(context, ref, notificationState.error!)
              : notificationState.isLoading
              ? Center(
                  child: LoadingAnimationWidget.staggeredDotsWave(
                    color: MlTokens.accent,
                    size: 50,
                  ),
                )
              : notifications.isEmpty
              ? _buildEmptyState()
              : _buildNotificationList(
                  context,
                  ref,
                  _applyFilter(notifications),
                  authState.userType?.isCompany == true,
                  inSuperAdminShell: inSuperAdminShell,
                ),
        ),
      ],
    );
  }

  List<AppNotification> _applyFilter(List<AppNotification> notifications) {
    switch (_filter) {
      case _NotifFilter.all:
        return notifications;
      case _NotifFilter.unread:
        return notifications.where((n) => !n.isRead).toList();
      case _NotifFilter.priority:
        return notifications
            .where((n) => n.importance != NotificationImportance.normal)
            .toList();
    }
  }

  Widget _filterChip(_NotifFilter value, String label, int count) {
    final semantic = MlSemantic.of(context);
    final selected = _filter == value;
    return InkWell(
      borderRadius: BorderRadius.circular(MlTokens.rPill),
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? MlTokens.accent : semantic.surfaceCard,
          borderRadius: BorderRadius.circular(MlTokens.rPill),
          border: Border.all(
            color: selected ? MlTokens.accent : semantic.borderStrong,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: context.mlText.titleSmall.copyWith(
                color: selected ? MlTokens.inkOnAccent : semantic.textBody,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected
                    ? MlTokens.inkOnAccent.withValues(alpha: 0.22)
                    : semantic.surfaceSunken,
                borderRadius: BorderRadius.circular(MlTokens.rPill),
              ),
              child: Text(
                '$count',
                style: context.mlText.code(
                  color: selected ? MlTokens.inkOnAccent : semantic.textMuted,
                  size: 12,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    final userId = ref.read(authStateProvider).user?.id;
    return MlEmptyState(
      icon: Icons.error_outline,
      title: 'Could not load notifications',
      message: error,
      action: userId != null
          ? MlButton.primary(
              label: 'Retry',
              icon: Icons.refresh,
              onPressed: () => ref
                  .read(notificationProvider.notifier)
                  .loadNotifications(userId),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return const MlEmptyState(
      icon: Icons.notifications_none,
      title: 'No notifications',
      message: "You're all caught up.",
    );
  }

  Widget _buildNotificationList(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> notifications,
    bool isCompany, {
    required bool inSuperAdminShell,
  }) {
    if (notifications.isEmpty) {
      return const MlEmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'Nothing here',
        message: 'No notifications match this filter.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return _buildNotificationItem(
          context,
          ref,
          notification,
          isCompany,
          inSuperAdminShell: inSuperAdminShell,
        );
      },
    );
  }

  // Show confirmation dialog before clearing all notifications
  void _showClearConfirmationDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This will remove all notifications from this view. They will still be available in the notification management screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Clear all notifications from the bell icon view
              final notificationState = ref.read(notificationProvider);
              for (final notification in notificationState.notifications) {
                ref
                    .read(notificationProvider.notifier)
                    .deleteNotification(notification.id);
              }
              Navigator.pop(context); // Close dialog
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
    bool isCompany, {
    required bool inSuperAdminShell,
  }) {
    return Dismissible(
      key: Key(notification.id),
      background: Container(
        decoration: BoxDecoration(
          color: MlTokens.red600,
          borderRadius: BorderRadius.circular(MlTokens.rLg),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        child: const Icon(Icons.delete_outline, color: MlTokens.inkOnFill),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        // Show confirmation dialog
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text("Confirm"),
              content: const Text(
                "Are you sure you want to clear this notification?",
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text("Clear"),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        // Remove the notification from the bell icon view
        ref
            .read(notificationProvider.notifier)
            .deleteNotification(notification.id);

        // Show a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification cleared'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // We can't actually undo this since we've deleted it,
                // but we could refresh the list to show it's still in the management view
                ref
                    .read(notificationProvider.notifier)
                    .loadNotifications(notification.userId);
              },
            ),
          ),
        );
      },
      child: NotificationCard(
        notification: notification,
        showActions: false,
        onTap: () {
          // Mark as read
          if (!notification.isRead) {
            ref.read(notificationProvider.notifier).markAsRead(notification.id);
          }

          // Order-flow deep-link: any notification carrying a stockpile_id
          // (new order to prepare / stockpile ready to collect) opens the
          // linked stockpile in the portal Supervisor tab.
          final stockpileId =
              notification.metadata?['stockpile_id'] as String?;
          if (stockpileId != null && !inSuperAdminShell) {
            ref.read(pendingStockpileFocusProvider.notifier).state =
                stockpileId;
            final tabs = ref.read(portalWorkspaceProvider).tabs;
            if (tabs != null) {
              final i = tabs.indexWhere((t) => t.label == 'Supervisor');
              if (i >= 0) {
                ref.read(portalTabIndexProvider.notifier).state = i;
              }
            }
            context.go('/home');
            return;
          }

          // Direct route deep-link: account-setup / profile-completion
          // reminders carry the route to open (works in every shell).
          final navRoute = notification.metadata?['nav_route'] as String?;
          if (navRoute != null && navRoute.startsWith('/')) {
            context.go(navRoute);
            return;
          }

          // Generic portal deep-link: a notification (e.g. a driver's vehicle
          // assignment) can name the portal tab to open, e.g. "My routes".
          final navTab = notification.metadata?['nav_tab'] as String?;
          if (navTab != null && !inSuperAdminShell) {
            final tabs = ref.read(portalWorkspaceProvider).tabs;
            if (tabs != null) {
              final i = tabs.indexWhere((t) => t.label == navTab);
              if (i >= 0) {
                ref.read(portalTabIndexProvider.notifier).state = i;
              }
            }
            context.go('/home');
            return;
          }

          // Handle notification action based on type
          if (notification.type == NotificationType.employeeRequest &&
              isCompany) {
            context.go('/company-employees');
          } else if (notification.type == NotificationType.roleAssigned &&
              !isCompany) {
            // Just acknowledge the notification
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Your role has been assigned. You now have access to all features.',
                ),
                duration: Duration(seconds: 3),
              ),
            );
          } else if (notification.type == NotificationType.requestDeclined &&
              !isCompany) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) =>
                  RequestDeclinedScreen(notification: notification),
            );
          } else if (notification.type == NotificationType.roleConfirmation &&
              isCompany) {
            // Just acknowledge the notification
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Role assignment confirmed.'),
                duration: Duration(seconds: 2),
              ),
            );
          } else if (notification.type == NotificationType.tokenExpiringSoon) {
            if (inSuperAdminShell) {
              context.go('/super-admin/organizations');
            } else if (isCompany) {
              context.go('/profile');
            }
          } else if (notification.type == NotificationType.tokenRequestHandled && isCompany) {
            if (inSuperAdminShell) {
              context.go('/super-admin/token-requests');
            } else {
              context.go('/profile');
            }
          } else if (notification.type == NotificationType.tokenRequestCreated ||
              notification.type == NotificationType.tokenRequestClaimed ||
              notification.type == NotificationType.tokenRequestReleased ||
              (notification.type == NotificationType.tokenRequestHandled && !isCompany)) {
            context.go('/super-admin/token-requests');
          } else if (notification.type == NotificationType.profileUpdate) {
            // Profile-change alerts open the user's profile.
            context.go('/profile');
          } else if (notification.type == NotificationType.fleetVehicleAdded ||
              notification.type == NotificationType.fleetDriverAssigned ||
              notification.type == NotificationType.fleetDriverUnassigned ||
              notification.type ==
                  NotificationType.fleetVehicleStatusChanged) {
            // Fleet alerts open the fleet management screen.
            context.go('/fleet-management');
          }
        },
      ),
    );
  }
}
