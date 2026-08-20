import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/models/workflow_notification.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/providers/workflow_notification_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_dashboard_navigation.dart';

/// Portal app-bar bell for in-app workflow alerts (check-in, load confirmed,
/// stockpile updated, etc.). Role-targeted, with an unread badge; tapping an
/// actionable alert navigates to the relevant tab and preselects the truck.
class WorkflowNotificationBell extends ConsumerWidget {
  const WorkflowNotificationBell({super.key});

  static const _readAll = '__read_all__';

  IconData _icon(WorkflowEvent kind) {
    switch (kind) {
      case WorkflowEvent.checkin:
        return Icons.how_to_reg_outlined;
      case WorkflowEvent.loadConfirmed:
        return Icons.scale_outlined;
      case WorkflowEvent.stockpileUpdated:
        return Icons.layers_outlined;
      case WorkflowEvent.released:
        return Icons.local_shipping_outlined;
      case WorkflowEvent.stockpileAllocated:
        return Icons.add_business_outlined;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(visibleWorkflowNotificationsProvider);
    final unread = ref.watch(unreadWorkflowCountProvider);
    final roleKey = ref.watch(portalRoleKeyProvider);

    return PopupMenuButton<String>(
      tooltip: 'Workflow alerts',
      position: PopupMenuPosition.under,
      icon: Badge(
        label: Text('$unread'),
        isLabelVisible: unread > 0,
        child: const Icon(Icons.notifications_active_outlined),
      ),
      itemBuilder: (context) {
        if (items.isEmpty) {
          return const [
            PopupMenuItem<String>(
              enabled: false,
              child: SizedBox(
                width: 300,
                child: Text('No workflow alerts yet.'),
              ),
            ),
          ];
        }
        return [
          for (final n in items.take(12))
            PopupMenuItem<String>(
              value: n.id,
              child: _NotifTile(n: n, icon: _icon(n.kind)),
            ),
          const PopupMenuDivider(),
          const PopupMenuItem<String>(
            value: _readAll,
            child: Text('Mark all as read'),
          ),
        ];
      },
      onSelected: (value) {
        final notifier = ref.read(workflowNotificationProvider.notifier);
        if (value == _readAll) {
          notifier.markAllReadFor(roleKey);
          return;
        }
        WorkflowNotification? n;
        for (final x in items) {
          if (x.id == value) {
            n = x;
            break;
          }
        }
        if (n == null) return;
        notifier.markRead(n.id);
        if (n.isActionable) {
          if (n.reg != null) {
            ref.read(pendingSelectionProvider.notifier).state =
                (tab: n.tabLabel!, reg: n.reg!);
          }
          openPortalTabByLabel(ref, context, n.tabLabel!);
        }
      },
    );
  }
}

class _NotifTile extends StatelessWidget {
  final WorkflowNotification n;
  final IconData icon;
  const _NotifTile({required this.n, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 320,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: PortalColors.accent.withValues(alpha: 0.12),
              borderRadius: MlShape.radiusMedium,
            ),
            child: Icon(icon, size: 18, color: PortalColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.read ? FontWeight.w600 : FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  n.body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
                if (n.isActionable) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.open_in_new_rounded,
                          size: 12, color: PortalColors.accent),
                      const SizedBox(width: 4),
                      Text('Open ${n.tabLabel}',
                          style: context.mlText.labelSmall.copyWith(
                            color: PortalColors.accent,
                            fontWeight: FontWeight.w700,
                          )),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (!n.read)
            Container(
              margin: const EdgeInsets.only(left: 6, top: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: PortalColors.accent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
