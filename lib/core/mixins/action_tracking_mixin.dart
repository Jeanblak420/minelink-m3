import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/services/action_tracking_service.dart';
import 'package:flutter_application_1/features/notifications/models/notification_model.dart';
import 'package:flutter_application_1/features/auth/models/app_user.dart';

/// A mixin that provides action tracking functionality to provider notifiers
mixin ActionTrackingMixin on StateNotifier<dynamic> {
  /// Track a user action and create appropriate notifications
  Future<void> trackUserAction({
    required Ref ref,
    required NotificationType actionType,
    required String actionTitle,
    required String actionDescription,
    required AppUser actionedBy,
    required String companyId,
    String? targetUserId,
    String? targetEntityId,
    Map<String, dynamic>? metadata,
  }) async {
    final actionTrackingService = ref.read(actionTrackingServiceProvider);

    await actionTrackingService.trackAction(
      actionType: actionType,
      actionTitle: actionTitle,
      actionDescription: actionDescription,
      actionedBy: actionedBy,
      companyId: companyId,
      targetUserId: targetUserId,
      targetEntityId: targetEntityId,
      metadata: metadata,
    );
  }
}
