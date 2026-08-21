import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:flutter_application_1/features/notifications/widgets/notification_card.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/company/providers/company_provider.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

/// The persistent notification history.
///
/// **No app bar of its own, and no flag for one** — see [NotificationScreen],
/// which lost the same `showAppBar` for the same reason. Both routes that
/// mount this screen are leaves of a `ShellRoute` whose top bar already carries
/// [title]; the screen's own bar repeated it directly underneath.
class NotificationManagementScreen extends ConsumerStatefulWidget {
  final String title;
  final UserRole? filterRole;
  final bool isFromAdminTab;

  const NotificationManagementScreen({
    super.key,
    required this.title,
    this.filterRole,
    this.isFromAdminTab = false,
  });

  @override
  ConsumerState<NotificationManagementScreen> createState() =>
      _NotificationManagementScreenState();
}

class _NotificationManagementScreenState
    extends ConsumerState<NotificationManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Load notifications for the management screen
    Future.microtask(() {
      final authState = ref.read(authStateProvider);
      if (authState.user != null) {
        ref
            .read(notificationProvider.notifier)
            .loadNotificationsForManagementScreen(
              authState.user!.id,
              widget.filterRole,
              _getOrgType(),
            );
      }
    });
  }

  OrgType? _getOrgType() {
    final authState = ref.read(authStateProvider);
    if (authState.userType?.isCompany == true) {
      final companyState = ref.read(companyProvider);
      return companyState.company?.orgType;
    } else if (authState.userType?.isEmployee == true) {
      final employeeState = ref.read(employeeProvider);
      return employeeState.company?.orgType;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final notificationState = ref.watch(notificationProvider);
    final authState = ref.watch(authStateProvider);

    final semantic = MlSemantic.of(context);
    final rows = notificationState.managementNotifications;

    return ColoredBox(
      color: semantic.surfaceApp,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
            child: MlPageHeader(
              title: widget.title,
              description: 'Every notification kept for your role — a '
                  'persistent record, unlike the bell, which can be cleared.',
              meta: mlCount(rows.length, 'notification'),
              padding: EdgeInsets.zero,
              actions: [
                if (widget.isFromAdminTab)
                  MlButton.ghost(
                    label: 'About',
                    icon: Icons.info_outline,
                    compact: true,
                    onPressed: () => _showInfoDialog(context),
                  ),
              ],
            ),
          ),
          // Info banner explaining the distinction from bell icon (Step 5)
          if (widget.isFromAdminTab) _buildInfoBanner(context),
          // Main content
          Expanded(
            child: notificationState.isLoading
                ? Center(
                    child: LoadingAnimationWidget.staggeredDotsWave(
                      color: MlTokens.accent,
                      size: 50,
                    ),
                  )
                : rows.isEmpty
                ? _buildEmptyState()
                : _buildNotificationList(
                    context,
                    ref,
                    rows,
                    authState.userType?.isCompany == true,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tone = MlTone.transit.colors(brightness);
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      decoration: BoxDecoration(
        color: tone.bg,
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        border: Border.all(color: tone.fg.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: tone.fg, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This management screen shows all your notifications history. Unlike the bell icon, notifications here cannot be deleted and provide a persistent record.',
              style: context.mlText.bodyMedium.copyWith(color: tone.fg),
            ),
          ),
        ],
      ),
    );
  }

  // Dialog explaining the difference between management screen and bell icon
  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About Notification Management'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'This notification management screen is different from the bell icon in the top-right corner:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                '• Bell Icon: Shows recent notifications that can be cleared',
              ),
              Text(
                '• Management Screen: Shows all notifications with persistent history',
              ),
              SizedBox(height: 12),
              Text('On this screen:'),
              Text('• You can mark notifications as read/unread'),
              Text('• You cannot delete notifications'),
              Text('• You see only notifications relevant to your role'),
              Text('• All timestamps are South African time (UTC+02:00), '
                  'whatever your device is set to'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const MlEmptyState(
      icon: Icons.notifications_off_outlined,
      title: 'No notifications yet',
      message: 'When you receive notifications, they will appear here.',
    );
  }

  Widget _buildNotificationList(
    BuildContext context,
    WidgetRef ref,
    List<AppNotification> notifications,
    bool isCompany,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.all(24.0),
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final notification = notifications[index];
        return NotificationCard(
          notification: notification,
          showActions: true,
          onReadStatusChanged: (isRead) {
            ref
                .read(notificationProvider.notifier)
                .toggleReadStatus(notification.id, isRead);
          },
          onTap: () => _handleTap(context, ref, notification),
        );
      },
    );
  }

  void _handleTap(
    BuildContext context,
    WidgetRef ref,
    AppNotification notification,
  ) {
    // Mark as read if not already read
    if (!notification.isRead) {
      ref.read(notificationProvider.notifier).markAsRead(notification.id);
    }

    // The only deep links this screen ever carried were the three dismissal
    // types, removed with the feature (client ruling, 2026-08-11). Tapping a
    // notification here now marks it read, which is all it did for every other
    // type already.
  }
}
