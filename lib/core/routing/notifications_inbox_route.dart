import 'package:flutter_application_1/features/super_admin/data/models/platform_role.dart';

/// Inbox list for the current session (portal vs platform admin shell).
abstract final class NotificationsInboxRoute {
  static const portalPath = '/notifications';
  static const superAdminPath = '/super-admin/notifications';

  static bool isPlatformAdmin(PlatformRole? role) {
    return role == PlatformRole.superGlobalSerialAdminMain;
  }

  static String forPlatformRole(PlatformRole? role) {
    return isPlatformAdmin(role) ? superAdminPath : portalPath;
  }
}
