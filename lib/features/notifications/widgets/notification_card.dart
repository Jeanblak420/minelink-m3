import 'package:flutter/material.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:flutter_application_1/features/notifications/services/notification_service.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Type → (icon, tone) mapping, mirroring `ui_kits/notifications/screens.jsx`
/// `NTYPE` and extended for the extra app notification types.
({IconData icon, MlTone tone}) _typeMeta(NotificationType type) {
  switch (type) {
    case NotificationType.employeeRequest:
      return (icon: Icons.person_add_alt_1, tone: MlTone.accent);
    case NotificationType.roleAssigned:
      return (icon: Icons.badge_outlined, tone: MlTone.done);
    case NotificationType.requestDeclined:
      return (icon: Icons.block, tone: MlTone.error);
    case NotificationType.roleConfirmation:
      return (icon: Icons.verified_outlined, tone: MlTone.done);
    case NotificationType.profileUpdate:
      return (icon: Icons.person_outline, tone: MlTone.neutral);
    case NotificationType.userManagement:
      return (icon: Icons.manage_accounts_outlined, tone: MlTone.neutral);
    case NotificationType.securityAlert:
      return (icon: Icons.security, tone: MlTone.error);
    case NotificationType.controllerAction:
      return (icon: Icons.tune, tone: MlTone.accent);
    case NotificationType.adminAction:
      return (icon: Icons.admin_panel_settings_outlined, tone: MlTone.neutral);
    case NotificationType.managementAction:
      return (icon: Icons.manage_accounts_outlined, tone: MlTone.neutral);
    case NotificationType.fleetVehicleAdded:
      return (icon: Icons.local_shipping_outlined, tone: MlTone.transit);
    case NotificationType.fleetDriverAssigned:
      return (icon: Icons.assignment_ind_outlined, tone: MlTone.transit);
    case NotificationType.fleetDriverUnassigned:
      return (icon: Icons.person_remove_outlined, tone: MlTone.warn);
    case NotificationType.fleetVehicleStatusChanged:
      return (icon: Icons.swap_horiz, tone: MlTone.accent);
    case NotificationType.tokenExpiringSoon:
      return (icon: Icons.hourglass_bottom, tone: MlTone.warn);
    case NotificationType.tokenRequestCreated:
      return (icon: Icons.vpn_key_outlined, tone: MlTone.accent);
    case NotificationType.tokenRequestClaimed:
      return (icon: Icons.vpn_key_outlined, tone: MlTone.transit);
    case NotificationType.tokenRequestReleased:
      return (icon: Icons.vpn_key_outlined, tone: MlTone.neutral);
    case NotificationType.tokenRequestHandled:
      return (icon: Icons.vpn_key_outlined, tone: MlTone.done);
    // P8-30: a weight discrepancy between what left the mine and what arrived.
    // MlTone.error is deliberate and matches the recon screens — the server
    // only pushes these for a MATERIAL variance (variance_is_material), which
    // is the same threshold that paints the row red. The icon and the table
    // cell therefore say the same thing about the same load.
    case NotificationType.reconDispute:
      return (icon: Icons.scale_outlined, tone: MlTone.error);
    case NotificationType.general:
      return (icon: Icons.notifications_outlined, tone: MlTone.neutral);
  }
}

/// MineLink notification row (`NotifItem` in the kit): tinted icon well keyed
/// to the notification type, title + optional importance pill, muted message,
/// and a tonal meta line (type · time · actioned-by). Unread rows carry a
/// cyan-well fill, accent border, and a leading accent dot.
class NotificationCard extends ConsumerWidget {
  final AppNotification notification;
  final VoidCallback? onTap;
  final Function(bool)? onReadStatusChanged;
  final bool showActions;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onReadStatusChanged,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final meta = _typeMeta(notification.type);
    final tone = meta.tone.colors(brightness);
    final unread = !notification.isRead;

    final formattedDate = ref
        .read(notificationServiceProvider)
        .formatTimestamp(notification.createdAt);

    final radius = BorderRadius.circular(MlTokens.rLg);

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlIconWell(icon: meta.icon, tone: meta.tone, size: 44, radius: 12),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Text(
                        notification.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: semantic.textStrong,
                          height: 1.25,
                        ),
                      ),
                    ),
                    if (_importanceBadge(notification.importance)
                        case final badge?) ...[
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: badge,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  notification.message,
                  style: TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: 13,
                    color: semantic.textMuted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 7),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: notification.type.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: tone.fg,
                        ),
                      ),
                      TextSpan(text: '  ·  $formattedDate'),
                      TextSpan(
                        text: '  ·  by ${notification.actionedBy ?? 'System'}',
                      ),
                    ],
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: 11.5,
                      color: semantic.textFaint,
                    ),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showActions && onReadStatusChanged != null) ...[
            const SizedBox(width: 4),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                notification.isRead
                    ? Icons.mark_email_unread_outlined
                    : Icons.mark_email_read_outlined,
                size: 20,
                color: notification.isRead ? semantic.textFaint : MlTokens.accent,
              ),
              onPressed: () => onReadStatusChanged!(!notification.isRead),
              tooltip:
                  notification.isRead ? 'Mark as unread' : 'Mark as read',
            ),
          ],
        ],
      ),
    );

    Widget card = DecoratedBox(
      decoration: BoxDecoration(
        color: unread ? MlTone.accent.well(brightness) : semantic.surfaceCard,
        borderRadius: radius,
        border: Border.all(
          color: unread ? semantic.borderAccent : semantic.borderCard,
        ),
      ),
      child: onTap != null
          ? Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: content,
              ),
            )
          : content,
    );

    if (unread) {
      card = Stack(
        children: [
          card,
          Positioned(
            left: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: MlTokens.accent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return card;
  }

  /// Small High/Extreme importance pill; `null` for normal importance.
  Widget? _importanceBadge(NotificationImportance importance) {
    switch (importance) {
      case NotificationImportance.normal:
        return null;
      case NotificationImportance.high:
        return const MlStatusBadge(label: 'High', tone: MlTone.warn);
      case NotificationImportance.extreme:
        return const MlStatusBadge(label: 'Extreme', tone: MlTone.error);
    }
  }
}
