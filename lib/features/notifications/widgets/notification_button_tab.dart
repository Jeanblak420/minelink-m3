import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/core/routing/notifications_manage_route.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';

/// A notification button tab that matches the design in the image
/// with a purple bell icon and "Notifications" text
class NotificationButtonTab extends ConsumerWidget {
  final UserRole? role;

  const NotificationButtonTab({super.key, this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get unread count for badge
    final unreadCount = ref.watch(notificationProvider).unreadCount;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        onTap: () {
          context.go(
            NotificationsManageRoute.location(
              title: 'Notifications',
              filterRole: role,
            ),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    Icons.notifications_rounded,
                    size: 48,
                    color: MlTokens.violet700,
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: MlTokens.red600,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount.toString(),
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
              ),
              const SizedBox(height: 8),
              const Text(
                'Notifications',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
