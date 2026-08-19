import 'package:flutter_application_1/core/utils/logger.dart';

/// Notification schema changes are handled by Supabase migrations.
Future<void> updateNotificationSchema() async {
  final logger = LoggerFactory.getLogger('NotificationSchemaUpdater');
  logger.i(
    'Notification schema updates are migration-managed. No client-side schema '
    'changes were executed.',
  );
}
