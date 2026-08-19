import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:go_router/go_router.dart';

/// Deep-linkable notification management screen.
abstract final class NotificationsManageRoute {
  static const portalPath = '/notifications/manage';
  static const superAdminPath = '/super-admin/notifications/manage';

  /// Legacy alias for portal routes.
  static const path = portalPath;

  static String location({
    required String title,
    UserRole? filterRole,
    bool isFromAdminTab = false,
    bool useSuperAdminShell = false,
  }) {
    return _uri(
      useSuperAdminShell ? superAdminPath : portalPath,
      title: title,
      filterRole: filterRole,
      isFromAdminTab: isFromAdminTab,
    );
  }

  static String _uri(
    String basePath, {
    required String title,
    UserRole? filterRole,
    bool isFromAdminTab = false,
  }) {
    return Uri(
      path: basePath,
      queryParameters: <String, String>{
        'title': title,
        if (filterRole != null) 'role': filterRole.name,
        if (isFromAdminTab) 'fromAdmin': '1',
      },
    ).toString();
  }

  static NotificationsManageRouteArgs parse(GoRouterState state) {
    final q = state.uri.queryParameters;
    final raw = q['title'];
    final title =
        raw != null && raw.trim().isNotEmpty ? raw.trim() : 'Notifications';

    UserRole? filterRole;
    final roleName = q['role'];
    if (roleName != null) {
      for (final v in UserRole.values) {
        if (v.name == roleName) {
          filterRole = v;
          break;
        }
      }
    }

    final fromAdmin =
        q['fromAdmin'] == '1' || q['fromAdmin'] == 'true';

    return NotificationsManageRouteArgs(
      title: title,
      filterRole: filterRole,
      isFromAdminTab: fromAdmin,
    );
  }
}

class NotificationsManageRouteArgs {
  final String title;
  final UserRole? filterRole;
  final bool isFromAdminTab;

  const NotificationsManageRouteArgs({
    required this.title,
    this.filterRole,
    this.isFromAdminTab = false,
  });
}
