/// One device's daily check-in (`public.device_checkins`, migration
/// `20261024140000`), as `list_device_checkins` returns it to the platform
/// admin. Read-only: devices write their own rows through
/// `record_device_checkin`.
class DeviceCheckinRow {
  final String deviceId;
  final String? userLabel;
  final String platform;
  final String? appVersion;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;
  final int checkins;

  const DeviceCheckinRow({
    required this.deviceId,
    this.userLabel,
    required this.platform,
    this.appVersion,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.checkins,
  });

  factory DeviceCheckinRow.fromJson(Map<String, dynamic> json) =>
      DeviceCheckinRow(
        deviceId: json['device_id'] as String,
        userLabel: json['user_label'] as String?,
        platform: json['platform'] as String? ?? '',
        appVersion: json['app_version'] as String?,
        firstSeenAt: DateTime.parse(json['first_seen_at'] as String),
        lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
        checkins: (json['checkins'] as num?)?.toInt() ?? 0,
      );
}
