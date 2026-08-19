import 'package:flutter_application_1/features/super_admin/data/models/platform_role.dart';
import 'package:flutter_application_1/features/super_admin/data/models/organization_status.dart';

/// Platform-level permission checks
class PlatformPermissions {
  /// Check if user is a super admin (both super-admins are equal, full-rights)
  static bool isAnySuperAdmin(PlatformRole role) {
    return role.isSuperAdmin;
  }

  /// Check if a company can use operational features
  static bool canUseCompanyFeatures({
    required OrganizationStatus orgStatus,
    DateTime? tokenExpiresAt,
  }) {
    if (!orgStatus.isActive) return false;
    if (tokenExpiresAt == null) return false;
    return tokenExpiresAt.isAfter(DateTime.now());
  }

  /// Calculate days remaining on a token
  static int daysRemaining(DateTime? expiresAt) {
    if (expiresAt == null) return 0;
    final remaining = expiresAt.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// Check if token is expiring soon (within 7 days)
  static bool isExpiringSoon(DateTime? expiresAt) {
    if (expiresAt == null) return false;
    final remaining = daysRemaining(expiresAt);
    return remaining <= 7 && remaining > 0;
  }
}
