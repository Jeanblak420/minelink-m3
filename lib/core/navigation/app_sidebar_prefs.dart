import 'package:shared_preferences/shared_preferences.dart';

/// Persists sidebar rail expanded/collapsed state so layout survives restarts.
///
/// ## Collapsed is the default, on every device and every platform
///
/// Ruled by jean, 2026-08-22: *"the sidebar menu nav should always be
/// collapsed by default and each of the parents in it should also be collapsed
/// by default on all devices and platforms please, windows, mobile, where ever
/// and what ever"*.
///
/// Both reads used to answer `?? true`, so a user who had never touched the
/// control got the 280px expanded rail on a laptop, a tablet and a desktop
/// window alike — the widest chrome the product has, before they had asked for
/// any of it. The stored preference is untouched by this; only the answer for
/// somebody who has never expressed one has changed.
///
/// The matching half — every GROUP inside the rail starting closed — is
/// `_MlNavRailState._isOpen` in `ml_nav_rail.dart`.
abstract final class AppSidebarPrefs {
  static const _portalExpanded = 'app.sidebar.portal_expanded';
  static const _superAdminExpanded = 'app.sidebar.super_admin_expanded';

  static Future<bool> readPortalExpanded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_portalExpanded) ?? false;
  }

  static Future<void> writePortalExpanded(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_portalExpanded, value);
  }

  static Future<bool> readSuperAdminExpanded() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_superAdminExpanded) ?? false;
  }

  static Future<void> writeSuperAdminExpanded(bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_superAdminExpanded, value);
  }
}
