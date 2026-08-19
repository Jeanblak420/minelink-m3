import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:flutter_application_1/features/notifications/services/notification_service.dart';

class NotificationState {
  final List<AppNotification> notifications;
  final List<AppNotification> managementNotifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  NotificationState({
    this.notifications = const [],
    this.managementNotifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    List<AppNotification>? managementNotifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      managementNotifications:
          managementNotifications ?? this.managementNotifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class NotificationNotifier extends StateNotifier<NotificationState> {
  final NotificationService _notificationService;
  final AuthStateNotifier _authStateNotifier;
  final Logger _logger = LoggerFactory.getLogger('NotificationNotifier');
  late final void Function() _removeAuthListener;

  RealtimeChannel? _notificationChannel;
  UserRole? _managementRoleFilter;
  OrgType? _managementOrgTypeFilter;
  bool _shouldRefreshManagementView = false;
  String? _lastSyncedNotificationUserId;

  NotificationNotifier(this._notificationService, this._authStateNotifier)
    : super(NotificationState()) {
    _removeAuthListener = _authStateNotifier.addListener((authState) {
      unawaited(_handleAuthStateChanged(authState));
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _removeAuthListener();
    _notificationChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _handleAuthStateChanged(AuthState authState) async {
    final user = authState.user;

    if (user == null) {
      _lastSyncedNotificationUserId = null;
      await _notificationChannel?.unsubscribe();
      _notificationChannel = null;
      _managementRoleFilter = null;
      _managementOrgTypeFilter = null;
      _shouldRefreshManagementView = false;
      state = NotificationState();
      return;
    }

    if (state.isLoading && _lastSyncedNotificationUserId == user.id) {
      return;
    }

    final isSameUser = _lastSyncedNotificationUserId == user.id;
    if (isSameUser && _notificationChannel != null && !state.isLoading) {
      return;
    }

    _lastSyncedNotificationUserId = user.id;
    await loadNotifications(user.id);
    _setupRealtime(user.id);
  }

  void _setupRealtime(String userId) {
    _notificationChannel?.unsubscribe();

    _notificationChannel =
        SupabaseConfig.client.channel('notifications-$userId')
          ..onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (_) async => _handleRealtimeRefresh(userId),
          )
          ..subscribe();
  }

  Future<void> _handleRealtimeRefresh(String userId) async {
    await loadNotifications(userId);

    if (_shouldRefreshManagementView) {
      await loadNotificationsForManagementScreen(
        userId,
        _managementRoleFilter,
        _managementOrgTypeFilter,
      );
    }
  }

  Future<void> loadNotifications(String userId) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final notifications = await _notificationService.getNotificationsForUser(
        userId,
      );
      final unreadCount = notifications.where((n) => !n.isRead).length;

      state = state.copyWith(
        notifications: notifications,
        unreadCount: unreadCount,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadNotificationsForManagementScreen(
    String userId,
    UserRole? role,
    OrgType? orgType,
  ) async {
    try {
      _managementRoleFilter = role;
      _managementOrgTypeFilter = orgType;
      _shouldRefreshManagementView = true;
      state = state.copyWith(isLoading: true, error: null);
      final notifications = await _notificationService
          .getNotificationsForManagementScreen(userId, role, orgType);

      state = state.copyWith(
        managementNotifications: notifications,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> toggleReadStatus(String notificationId, bool isRead) async {
    try {
      await _notificationService.markNotificationReadStatus(
        notificationId,
        isRead,
      );

      final updatedNotifications = state.notifications.map((notification) {
        return notification.id == notificationId
            ? notification.copyWith(isRead: isRead)
            : notification;
      }).toList();

      final updatedManagementNotifications = state.managementNotifications.map((
        notification,
      ) {
        return notification.id == notificationId
            ? notification.copyWith(isRead: isRead)
            : notification;
      }).toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        managementNotifications: updatedManagementNotifications,
        unreadCount: updatedNotifications.where((n) => !n.isRead).length,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> markAsRead(String notificationId) async {
    await toggleReadStatus(notificationId, true);
  }

  Future<void> markAllAsRead() async {
    try {
      final user = _authStateNotifier.state.user;
      if (user == null) return;

      await _notificationService.markAllNotificationsAsRead(user.id);

      state = state.copyWith(
        notifications: state.notifications
            .map((notification) => notification.copyWith(isRead: true))
            .toList(),
        managementNotifications: state.managementNotifications
            .map((notification) => notification.copyWith(isRead: true))
            .toList(),
        unreadCount: 0,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      final updatedNotifications = state.notifications
          .where((notification) => notification.id != notificationId)
          .toList();

      state = state.copyWith(
        notifications: updatedNotifications,
        unreadCount: updatedNotifications.where((n) => !n.isRead).length,
      );

      await _notificationService.markNotificationAsRead(notificationId);
    } catch (e) {
      _logger.e('Error deleting notification from bell view', e);
      state = state.copyWith(error: e.toString());
    }
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, NotificationState>((ref) {
      return NotificationNotifier(
        ref.watch(notificationServiceProvider),
        ref.watch(authStateProvider.notifier),
      );
    });
