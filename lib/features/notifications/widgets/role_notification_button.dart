import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/routing/notifications_manage_route.dart';
import 'package:go_router/go_router.dart';

class RoleNotificationButton extends StatelessWidget {
  final UserRole role;
  final String? customTitle;

  const RoleNotificationButton({
    super.key,
    required this.role,
    this.customTitle,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the button title based on the role
    String title;
    if (customTitle != null) {
      title = customTitle!;
    } else {
      switch (role) {
        case UserRole.security:
          title = 'Security Notifications';
          break;
        case UserRole.controllerWB:
          title = 'Controller Notifications';
          break;
        case UserRole.admin:
          title = 'Admin Notifications';
          break;
        case UserRole.management:
          title = 'Management Notifications';
          break;
        case UserRole.driver:
          title = 'Driver Notifications';
          break;
        default:
          title = 'Notifications';
          break;
      }
    }

    return FilledButton.tonalIcon(
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
    );
  }
}
