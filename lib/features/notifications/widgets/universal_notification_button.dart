import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/routing/notifications_manage_route.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

class UniversalNotificationButton extends ConsumerWidget {
  final UserRole? role;
  final OrgType? orgType;
  final String? customTitle;
  final bool showBadge;

  const UniversalNotificationButton({
    super.key,
    this.role,
    this.orgType,
    this.customTitle,
    this.showBadge = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Determine the button title based on the role and requirements
    String title = _getButtonTitle();

    // Get unread count if showing badge
    final unreadCount = showBadge
        ? ref.watch(notificationProvider).unreadCount
        : 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        FilledButton.tonalIcon(
          onPressed: () {
            context.go(
              NotificationsManageRoute.location(
                title: title,
                filterRole: role,
              ),
            );
          },
          icon: const Icon(Icons.notifications),
          label: Text(title),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        if (showBadge && unreadCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: MlTokens.red600,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                unreadCount > 9 ? '9+' : unreadCount.toString(),
                style: const TextStyle(
                  color: MlTokens.inkOnFill,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // Determine the button title based on role and requirements (Steps 19-25)
  String _getButtonTitle() {
    if (customTitle != null) {
      return customTitle!;
    }

    // Company Role accessing specific role's tab (Step 20)
    if (role != null && orgType != null) {
      switch (role) {
        case UserRole.security:
          return 'Security Notifications';
        case UserRole.controllerWB:
          return 'Controller Notifications';
        case UserRole.admin:
          return 'Admin Notifications';
        case UserRole.management:
          return 'Management Notifications';
        case UserRole.driver:
          return 'Driver Notifications';
        default:
          // Company Role in general view (Step 21)
          if (orgType == OrgType.mineSupplier) {
            return 'Mine/Supplier Notifications';
          } else if (orgType == OrgType.buyer) {
            return 'Buyer Notifications';
          } else if (orgType == OrgType.transporter) {
            return 'Transporter Notifications';
          }
      }
    }

    // Default label for other roles (Steps 22-25)
    if (role != null) {
      switch (role) {
        case UserRole.management:
          return 'Notifications'; // Management Role (Step 22)
        case UserRole.admin:
          return 'Notifications'; // Admin Role (Step 23)
        case UserRole.controllerWB:
          return 'Notifications'; // Controller Role (Step 24)
        case UserRole.security:
          return 'Notifications'; // Security Role (Step 25)
        default:
          return 'Notifications';
      }
    }

    return 'Notifications';
  }
}
