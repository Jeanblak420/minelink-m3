/// One row from `public.crash_reports` — an uncaught or handled error
/// shipped off-device by `SupabaseReportingSink` (Task 3, S9-1 seam).
///
/// Read-only by design: `crash_reports` has a SELECT policy gated to
/// `public.is_platform_admin()` and NO update/delete policy at all (see
/// migration `20260819140000_crash_reports.sql`) — the only way a row
/// leaves the table is `prune_telemetry_job()`, which is
/// `SECURITY DEFINER`. This model therefore has no `toJson` and the screen
/// built on it offers no mutation.
class CrashReportRow {
  final String id;
  final String? userId;
  final DateTime at;
  final String? platform;
  final String? appVersion;
  final String error;
  final String? stack;
  final bool fatal;
  final DateTime createdAt;

  const CrashReportRow({
    required this.id,
    this.userId,
    required this.at,
    this.platform,
    this.appVersion,
    required this.error,
    this.stack,
    required this.fatal,
    required this.createdAt,
  });

  factory CrashReportRow.fromJson(Map<String, dynamic> json) {
    return CrashReportRow(
      id: json['id'] as String,
      userId: json['user_id'] as String?,
      at: DateTime.parse(json['at'] as String),
      platform: json['platform'] as String?,
      appVersion: json['app_version'] as String?,
      error: json['error'] as String? ?? '',
      stack: json['stack'] as String?,
      fatal: json['fatal'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// First line of [error] — the collapsed row shows only this; the full
  /// text (up to 4 kB per the table's CHECK constraint) belongs in the
  /// expanded detail alongside [stack].
  String get errorFirstLine {
    final idx = error.indexOf('\n');
    return idx == -1 ? error : error.substring(0, idx);
  }
}
