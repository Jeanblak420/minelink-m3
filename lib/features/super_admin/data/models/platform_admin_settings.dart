/// Platform admin settings for the (single, full-rights) super global admin.
///
/// The former "child super admin" delegation model has been removed; both
/// super admins are now equal. Only the primary owner identity + timestamps
/// remain here.
class PlatformAdminSettings {
  final String id;
  final String mainSuperAdminEmail;
  final String? mainSuperAdminUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PlatformAdminSettings({
    required this.id,
    required this.mainSuperAdminEmail,
    this.mainSuperAdminUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PlatformAdminSettings.fromJson(Map<String, dynamic> json) {
    return PlatformAdminSettings(
      id: json['id'] as String,
      mainSuperAdminEmail: json['main_super_admin_email'] as String,
      mainSuperAdminUserId: json['main_super_admin_user_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
