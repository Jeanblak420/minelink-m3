import 'package:flutter_application_1/features/portal/models/workflow_notification.dart';
import 'package:flutter_application_1/features/portal/providers/workflow_notification_provider.dart';
import 'package:flutter_test/flutter_test.dart';

WorkflowNotification _n(String role, {bool read = false}) => WorkflowNotification(
      id: 'x',
      targetRole: role,
      kind: WorkflowEvent.checkin,
      title: 't',
      body: 'b',
      at: DateTime(2026),
      read: read,
    );

void main() {
  group('visibility', () {
    test('exact role match is visible', () {
      expect(workflowNotificationVisible(_n('security'), 'security'), isTrue);
      expect(workflowNotificationVisible(_n('controller'), 'controller'), isTrue);
    });

    test('a role does not see another role\'s notifications', () {
      expect(workflowNotificationVisible(_n('controller'), 'security'), isFalse);
      expect(workflowNotificationVisible(_n('security'), 'controller'), isFalse);
    });

    test('mine sees everything', () {
      expect(workflowNotificationVisible(_n('security'), 'mine'), isTrue);
      expect(workflowNotificationVisible(_n('controller'), 'mine'), isTrue);
      expect(workflowNotificationVisible(_n('mine'), 'mine'), isTrue);
    });
  });

  group('WorkflowNotificationNotifier', () {
    late WorkflowNotificationNotifier n;
    setUp(() => n = WorkflowNotificationNotifier());

    test('push prepends newest-first, unread, with navigation target', () {
      n.push(
        targetRole: 'controller',
        kind: WorkflowEvent.checkin,
        title: 'Truck checked in',
        body: 'reg in',
        tabLabel: 'Controller',
        reg: 'HV34TGGP',
      );
      n.push(
        targetRole: 'security',
        kind: WorkflowEvent.loadConfirmed,
        title: 'Load complete',
        body: 'ready',
        tabLabel: 'Security',
        reg: 'HV34TGGP',
      );
      expect(n.state.length, 2);
      expect(n.state.first.title, 'Load complete'); // newest first
      expect(n.state.first.read, isFalse);
      expect(n.state.last.tabLabel, 'Controller');
      expect(n.state.last.isActionable, isTrue);
    });

    test('markRead flips a single notification', () {
      n.push(targetRole: 'mine', kind: WorkflowEvent.released, title: 'a', body: 'b');
      final id = n.state.first.id;
      n.markRead(id);
      expect(n.state.first.read, isTrue);
    });

    test('markAllReadFor only clears notifications visible to that role', () {
      n.push(targetRole: 'security', kind: WorkflowEvent.loadConfirmed, title: 's', body: 'b');
      n.push(targetRole: 'controller', kind: WorkflowEvent.checkin, title: 'c', body: 'b');
      n.markAllReadFor('security');
      final security = n.state.firstWhere((x) => x.targetRole == 'security');
      final controller = n.state.firstWhere((x) => x.targetRole == 'controller');
      expect(security.read, isTrue);
      expect(controller.read, isFalse); // security cannot read controller's
    });

    test('mine markAllReadFor clears everything', () {
      n.push(targetRole: 'security', kind: WorkflowEvent.loadConfirmed, title: 's', body: 'b');
      n.push(targetRole: 'controller', kind: WorkflowEvent.checkin, title: 'c', body: 'b');
      n.markAllReadFor('mine');
      expect(n.state.every((x) => x.read), isTrue);
    });
  });
}
