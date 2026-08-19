import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/employee/providers/employee_provider.dart';
import 'package:flutter_application_1/features/portal/models/workflow_notification.dart';

/// Role key of the current portal user for notification targeting:
/// 'security', 'controller', or 'mine' (owner / admin / management / other,
/// which sees everything).
final portalRoleKeyProvider = Provider<String>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.userType?.isCompany == true) return 'mine';
  switch (ref.watch(employeeProvider).employee?.role) {
    case UserRole.security:
      return 'security';
    case UserRole.controllerWB:
      return 'controller';
    default:
      return 'mine';
  }
});

/// A pending truck selection to apply after navigating to [tab] (set when a
/// notification is tapped; consumed and cleared by the target screen).
typedef PendingSelection = ({String tab, String reg});

final pendingSelectionProvider = StateProvider<PendingSelection?>((ref) => null);

/// Whether [roleKey] should see [n]: exact role match, or the mine sees all.
bool workflowNotificationVisible(WorkflowNotification n, String roleKey) =>
    roleKey == 'mine' || n.targetRole == roleKey;

class WorkflowNotificationNotifier
    extends StateNotifier<List<WorkflowNotification>> {
  WorkflowNotificationNotifier() : super(const []);

  int _seq = 0;

  void push({
    required String targetRole,
    required WorkflowEvent kind,
    required String title,
    required String body,
    String? tabLabel,
    String? reg,
    DateTime? at,
  }) {
    state = [
      WorkflowNotification(
        id: 'wn${_seq++}',
        targetRole: targetRole,
        kind: kind,
        title: title,
        body: body,
        tabLabel: tabLabel,
        reg: reg,
        at: at ?? DateTime.now(),
      ),
      ...state,
    ];
  }

  void markRead(String id) {
    state = [
      for (final n in state) if (n.id == id) n.copyWith(read: true) else n,
    ];
  }

  void markAllReadFor(String roleKey) {
    state = [
      for (final n in state)
        if (!n.read && workflowNotificationVisible(n, roleKey))
          n.copyWith(read: true)
        else
          n,
    ];
  }
}

final workflowNotificationProvider = StateNotifierProvider<
    WorkflowNotificationNotifier, List<WorkflowNotification>>(
  (ref) => WorkflowNotificationNotifier(),
);

/// Notifications visible to the current user (newest first).
final visibleWorkflowNotificationsProvider =
    Provider<List<WorkflowNotification>>((ref) {
  final roleKey = ref.watch(portalRoleKeyProvider);
  final all = ref.watch(workflowNotificationProvider);
  return all.where((n) => workflowNotificationVisible(n, roleKey)).toList();
});

final unreadWorkflowCountProvider = Provider<int>((ref) {
  return ref
      .watch(visibleWorkflowNotificationsProvider)
      .where((n) => !n.read)
      .length;
});
