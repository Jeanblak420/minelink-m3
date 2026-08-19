import 'package:shared_preferences/shared_preferences.dart';

/// Persists sidebar rail expanded/collapsed state so layout survives restarts.
abstract final class AppSidebarPrefs {
  static const _portalExpanded = 'app.sidebar.portal_expanded';
  static const _superAdminExpanded = 'app.sidebar.super_admin_expanded';

  static Future<bool> readPortalExpanded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_portalExpanded) ?? true;
  }

  static Future<void> writePortalExpanded(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_portalExpanded, value);
  }

  static Future<bool> readSuperAdminExpanded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_superAdminExpanded) ?? true;
  }

  static Future<void> writeSuperAdminExpanded(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_superAdminExpanded, value);
  }
}
