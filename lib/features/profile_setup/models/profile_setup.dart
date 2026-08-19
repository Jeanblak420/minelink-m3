// Wire models for the account-setup / profile-completion engine
// (`get_profile_setup` RPC — migration 20260807100000).

/// Per-item completion state, computed server-side. `expiring` still counts as
/// complete for the percentage but is surfaced so the user renews in time.
enum SetupItemStatus {
  complete('complete', 'Complete'),
  expiring('expiring', 'Expiring soon'),
  needsExpiry('needs_expiry', 'Expiry date needed'),
  expired('expired', 'Expired'),
  missing('missing', 'Missing');

  final String wire;
  final String label;
  const SetupItemStatus(this.wire, this.label);

  static SetupItemStatus parse(String? value) =>
      SetupItemStatus.values.firstWhere(
        (s) => s.wire == value,
        orElse: () => SetupItemStatus.missing,
      );

  /// Counts toward completion (matches the SQL: complete or expiring).
  bool get countsComplete =>
      this == SetupItemStatus.complete || this == SetupItemStatus.expiring;

  /// Something the user still has to act on.
  bool get needsAction => !countsComplete;
}

enum SetupItemKind {
  field('field'),
  document('document'),
  signature('signature'),
  photo('photo');

  final String wire;
  const SetupItemKind(this.wire);

  static SetupItemKind parse(String? value) => SetupItemKind.values.firstWhere(
        (k) => k.wire == value,
        orElse: () => SetupItemKind.field,
      );
}

/// Checklist categories, in display order.
enum SetupCategory {
  personal('personal', 'Personal details'),
  identity('identity', 'Identity & signature'),
  medical('medical', 'Medicals'),
  licences('licences', 'Licences & permits'),
  certifications('certifications', 'Certificates'),
  company('company', 'Company details');

  final String wire;
  final String label;
  const SetupCategory(this.wire, this.label);

  static SetupCategory parse(String? value) => SetupCategory.values.firstWhere(
        (c) => c.wire == value,
        orElse: () => SetupCategory.personal,
      );
}

class ProfileSetupItem {
  final String itemKey;
  final String label;
  final String? description;
  final SetupCategory category;
  final SetupItemKind kind;
  final bool isRequired;
  final bool requiresExpiry;
  final bool requiresFile;
  final int sortOrder;
  final SetupItemStatus status;
  final String? source; // field | legacy_url | compliance_doc | signature
  final String? documentId;
  final bool filePresent;
  final DateTime? expiresAt;
  final int? daysToExpiry;

  const ProfileSetupItem({
    required this.itemKey,
    required this.label,
    this.description,
    required this.category,
    required this.kind,
    required this.isRequired,
    required this.requiresExpiry,
    required this.requiresFile,
    required this.sortOrder,
    required this.status,
    this.source,
    this.documentId,
    required this.filePresent,
    this.expiresAt,
    this.daysToExpiry,
  });

  factory ProfileSetupItem.fromJson(Map<String, dynamic> json) {
    return ProfileSetupItem(
      itemKey: (json['item_key'] ?? '').toString(),
      label: (json['label'] ?? '').toString(),
      description: json['description']?.toString(),
      category: SetupCategory.parse(json['category']?.toString()),
      kind: SetupItemKind.parse(json['item_kind']?.toString()),
      isRequired: json['is_required'] == true,
      requiresExpiry: json['requires_expiry'] == true,
      requiresFile: json['requires_file'] == true,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 100,
      status: SetupItemStatus.parse(json['status']?.toString()),
      source: json['source']?.toString(),
      documentId: json['document_id']?.toString(),
      filePresent: json['file_present'] == true,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      daysToExpiry: (json['days_to_expiry'] as num?)?.toInt(),
    );
  }
}

class ProfileSetupSummary {
  final int totalItems;
  final int completeItems;
  final int requiredTotal;
  final int requiredComplete;
  final int completionPercent;
  final List<String> missingRequired;
  final int missingCount;
  final int expiringCount;
  final int expiredCount;

  const ProfileSetupSummary({
    required this.totalItems,
    required this.completeItems,
    required this.requiredTotal,
    required this.requiredComplete,
    required this.completionPercent,
    required this.missingRequired,
    required this.missingCount,
    required this.expiringCount,
    required this.expiredCount,
  });

  factory ProfileSetupSummary.fromJson(Map<String, dynamic> json) {
    return ProfileSetupSummary(
      totalItems: (json['total_items'] as num?)?.toInt() ?? 0,
      completeItems: (json['complete_items'] as num?)?.toInt() ?? 0,
      requiredTotal: (json['required_total'] as num?)?.toInt() ?? 0,
      requiredComplete: (json['required_complete'] as num?)?.toInt() ?? 0,
      completionPercent: (json['completion_percent'] as num?)?.toInt() ?? 100,
      missingRequired: [
        for (final e in (json['missing_required'] as List? ?? const []))
          e.toString(),
      ],
      missingCount: (json['missing_count'] as num?)?.toInt() ?? 0,
      expiringCount: (json['expiring_count'] as num?)?.toInt() ?? 0,
      expiredCount: (json['expired_count'] as num?)?.toInt() ?? 0,
    );
  }

  static const empty = ProfileSetupSummary(
    totalItems: 0,
    completeItems: 0,
    requiredTotal: 0,
    requiredComplete: 0,
    completionPercent: 100,
    missingRequired: [],
    missingCount: 0,
    expiringCount: 0,
    expiredCount: 0,
  );

  /// Anything outstanding, expired, or approaching expiry.
  bool get needsAttention =>
      missingCount > 0 || expiredCount > 0 || expiringCount > 0;

  /// Only the hard blockers (required missing/expired).
  bool get hasOutstandingRequired => missingCount > 0 || expiredCount > 0;
}

class ProfileSetup {
  /// `employee` | `company`; null when the account has neither profile
  /// (e.g. a platform admin) and no setup applies.
  final String? audience;
  final String? subjectId;
  final String? orgType;
  final String? role;
  final String? companyId;
  final bool? isSaCitizen;
  final List<ProfileSetupItem> items;
  final ProfileSetupSummary summary;

  const ProfileSetup({
    this.audience,
    this.subjectId,
    this.orgType,
    this.role,
    this.companyId,
    this.isSaCitizen,
    required this.items,
    required this.summary,
  });

  factory ProfileSetup.fromJson(Map<String, dynamic> json) {
    final items = [
      for (final e in (json['items'] as List? ?? const []))
        ProfileSetupItem.fromJson(Map<String, dynamic>.from(e as Map)),
    ]..sort((a, b) {
        final c = a.category.index.compareTo(b.category.index);
        return c != 0 ? c : a.sortOrder.compareTo(b.sortOrder);
      });
    return ProfileSetup(
      audience: json['audience']?.toString(),
      subjectId: json['subject_id']?.toString(),
      orgType: json['org_type']?.toString(),
      role: json['role']?.toString(),
      companyId: json['company_id']?.toString(),
      isSaCitizen: json['is_sa_citizen'] as bool?,
      items: items,
      summary: json['summary'] is Map
          ? ProfileSetupSummary.fromJson(
              Map<String, dynamic>.from(json['summary'] as Map))
          : ProfileSetupSummary.empty,
    );
  }

  bool get isApplicable => audience != null;
  bool get isEmployee => audience == 'employee';
  bool get isCompany => audience == 'company';

  /// Categories present, in display order.
  List<SetupCategory> get categories {
    final seen = <SetupCategory>{};
    for (final i in items) {
      seen.add(i.category);
    }
    return [
      for (final c in SetupCategory.values)
        if (seen.contains(c)) c,
    ];
  }

  List<ProfileSetupItem> itemsIn(SetupCategory category) =>
      [for (final i in items) if (i.category == category) i];
}
