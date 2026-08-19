import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/employee/models/employee_model.dart';
import 'package:flutter_application_1/features/employee/models/employee_status_model.dart';
import 'package:flutter_application_1/features/employee/widgets/employee_status_timeline.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:flutter_application_1/features/notifications/providers/notification_provider.dart';
import 'package:flutter_application_1/features/notifications/services/notification_service.dart';
import 'package:flutter_application_1/features/notifications/widgets/animated_notification_bell.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'realtime_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<NotificationService>(),
  MockSpec<AuthStateNotifier>(),
])

class TestNotificationNotifier extends NotificationNotifier {
  TestNotificationNotifier(super.notificationService, super.authStateNotifier);

  void setTestState(NotificationState nextState) {
    state = nextState;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Realtime-driven widget coverage', () {
    late MockNotificationService mockNotificationService;
    late MockAuthStateNotifier mockAuthStateNotifier;
    late TestNotificationNotifier notifier;

    setUp(() {
      mockNotificationService = MockNotificationService();
      mockAuthStateNotifier = MockAuthStateNotifier();
      when(mockAuthStateNotifier.state).thenReturn(AuthState());
      notifier = TestNotificationNotifier(
        mockNotificationService,
        mockAuthStateNotifier,
      );
    });

    Widget buildNotificationSubject() {
      return ProviderScope(
        overrides: [notificationProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: AnimatedNotificationBell()),
        ),
      );
    }

    testWidgets(
      'AnimatedNotificationBell reacts to unread notification changes',
      (tester) async {
        await tester.pumpWidget(buildNotificationSubject());

        expect(find.text('9+'), findsNothing);

        notifier.setTestState(
          NotificationState(
            notifications: [
              AppNotification(
                id: 'notification-1',
                userId: 'user-1',
                title: 'Vehicle assigned',
                message: 'A vehicle was assigned to you.',
                type: NotificationType.fleetDriverAssigned,
                createdAt: DateTime.parse('2026-03-29T08:00:00.000Z'),
              ),
            ],
            unreadCount: 12,
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('9+'), findsOneWidget);

        notifier.setTestState(NotificationState());
        await tester.pump();

        expect(find.text('9+'), findsNothing);
      },
    );

    testWidgets('EmployeeStatusTimeline renders the approved workflow path', (
      tester,
    ) async {
      final employee = Employee(
        id: 'employee-1',
        userId: 'user-1',
        firstName: 'Taylor',
        lastName: 'Loader',
        whatsappNumber: '+27000000000',
        companyId: 'company-1',
        role: UserRole.driver,
        status: 'active',
        createdAt: DateTime.parse('2026-03-29T08:00:00.000Z'),
      );

      final history = [
        EmployeeStatusHistory(
          id: 'history-1',
          employeeId: employee.id,
          companyId: employee.companyId,
          status: EmployeeApprovalStatus.requestSent,
          timestamp: DateTime.parse('2026-03-29T08:00:00.000Z'),
          actionedByName: 'Taylor Loader',
        ),
        EmployeeStatusHistory(
          id: 'history-2',
          employeeId: employee.id,
          companyId: employee.companyId,
          status: EmployeeApprovalStatus.employeeApproved,
          timestamp: DateTime.parse('2026-03-29T09:00:00.000Z'),
          actionedByName: 'Morgan Manager',
        ),
        EmployeeStatusHistory(
          id: 'history-3',
          employeeId: employee.id,
          companyId: employee.companyId,
          status: EmployeeApprovalStatus.roleAssigned,
          timestamp: DateTime.parse('2026-03-29T09:15:00.000Z'),
          actionedByName: 'Addison Admin',
          assignedRole: UserRole.driver,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: EmployeeStatusTimeline(
                statusHistory: history,
                employee: employee,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Company request submitted'), findsOneWidget);
      expect(find.text('Request approved'), findsOneWidget);
      expect(find.text('Role assigned'), findsOneWidget);
      expect(find.text('App ready for use'), findsOneWidget);
      expect(find.text('Actioned by Morgan Manager'), findsOneWidget);
      expect(find.text('Actioned by Addison Admin'), findsNWidgets(2));
      expect(find.text('Pending'), findsNothing);
    });

    testWidgets('EmployeeStatusTimeline renders the declined workflow path', (
      tester,
    ) async {
      final employee = Employee(
        id: 'employee-2',
        userId: 'user-2',
        firstName: 'Jordan',
        lastName: 'Applicant',
        whatsappNumber: '+27000000001',
        companyId: 'company-1',
        status: 'pending',
        createdAt: DateTime.parse('2026-03-29T08:00:00.000Z'),
      );

      final history = [
        EmployeeStatusHistory(
          id: 'history-4',
          employeeId: employee.id,
          companyId: employee.companyId,
          status: EmployeeApprovalStatus.requestSent,
          timestamp: DateTime.parse('2026-03-29T08:00:00.000Z'),
          actionedByName: 'Jordan Applicant',
        ),
        EmployeeStatusHistory(
          id: 'history-5',
          employeeId: employee.id,
          companyId: employee.companyId,
          status: EmployeeApprovalStatus.requestDeclined,
          timestamp: DateTime.parse('2026-03-29T09:30:00.000Z'),
          actionedByName: 'Morgan Manager',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: EmployeeStatusTimeline(
                statusHistory: history,
                employee: employee,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Company request submitted'), findsOneWidget);
      expect(find.text('Request declined'), findsOneWidget);
      expect(find.text('App ready for use'), findsNothing);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Actioned by Morgan Manager'), findsOneWidget);
    });
  });
}
