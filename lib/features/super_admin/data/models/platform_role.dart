/// Platform-level role system (above organization roles).
///
/// The child super-admin concept has been flattened away (CLAUDE.md §4 — both
/// super-admins are equal, full-rights). [fromString] stays tolerant: the
/// legacy `superGlobalSerialAdminMainChild` wire string, if it ever appears in
/// stored data, resolves to the single full-rights main role.
enum PlatformRole {
  superGlobalSerialAdminMain,
  normalUser;

  static PlatformRole fromString(String? value) {
    switch (value) {
      case 'superGlobalSerialAdminMain':
      // Legacy child role flattens onto the single full-rights main role
      // (tolerant parse — any lingering DB row still resolves to full rights).
      case 'superGlobalSerialAdminMainChild':
        return PlatformRole.superGlobalSerialAdminMain;
      default:
        return PlatformRole.normalUser;
    }
  }

  String get displayName {
    switch (this) {
      case PlatformRole.superGlobalSerialAdminMain:
        return 'Super Global Admin (Main)';
      case PlatformRole.normalUser:
        return 'Normal User';
    }
  }

  bool get isSuperAdmin => this == PlatformRole.superGlobalSerialAdminMain;
}
