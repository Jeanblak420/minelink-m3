/// Reconciliation dispute model (CLAUDE.md §4 — the dispute layer over the
/// Side B weight variance). Backed by `list_recon_disputes` /
/// `list_recon_dispute_comments` and mutated via the dispute RPCs. Enums carry
/// an explicit `.wire` string + tolerant `parse` so DB string drift never
/// crashes the UI (same pattern as TripStatus).
library;

/// Lifecycle of a dispute: raised (`open`) → `under_review` (admin picked it
/// up) → `resolved` / `rejected` (admin, terminal), or `withdrawn` (raiser,
/// terminal).
enum DisputeStatus {
  open('open', 'Open'),
  underReview('under_review', 'Under review'),
  resolved('resolved', 'Resolved'),
  rejected('rejected', 'Rejected'),
  withdrawn('withdrawn', 'Withdrawn');

  const DisputeStatus(this.wire, this.label);
  final String wire;
  final String label;

  bool get isTerminal =>
      this == resolved || this == rejected || this == withdrawn;
  bool get isActive => !isTerminal;

  static DisputeStatus parse(String? value) {
    for (final s in DisputeStatus.values) {
      if (s.wire == value) return s;
    }
    return DisputeStatus.open;
  }
}

/// What the dispute is about.
enum DisputeCategory {
  weightVariance('weight_variance', 'Weight variance'),
  shortDelivery('short_delivery', 'Short delivery'),
  quality('quality', 'Quality'),
  seal('seal', 'Seal / tamper'),
  damage('damage', 'Damage'),
  other('other', 'Other');

  const DisputeCategory(this.wire, this.label);
  final String wire;
  final String label;

  static DisputeCategory parse(String? value) {
    for (final c in DisputeCategory.values) {
      if (c.wire == value) return c;
    }
    return DisputeCategory.other;
  }
}

class ReconDispute {
  final String id;
  final String tripId;
  final String transactionId;
  final DisputeCategory category;
  final String reason;
  final double? claimedTons;
  final DisputeStatus status;

  final String? reference;
  final String? truckReg;
  final String? sourceName;
  final String? customerName;
  final String? transporterName;
  final double? mineNetTons;
  final double? deliveredTons;
  final double? variance;

  final String? raisedByUserId;
  final String? raisedByName;
  final String? raisedByCompanyId;
  final String? raisedByCompanyName;

  final String? resolution;
  final DateTime? resolvedAt;
  final int commentCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ReconDispute({
    required this.id,
    required this.tripId,
    required this.transactionId,
    required this.category,
    required this.reason,
    required this.status,
    required this.commentCount,
    required this.createdAt,
    required this.updatedAt,
    this.claimedTons,
    this.reference,
    this.truckReg,
    this.sourceName,
    this.customerName,
    this.transporterName,
    this.mineNetTons,
    this.deliveredTons,
    this.variance,
    this.raisedByUserId,
    this.raisedByName,
    this.raisedByCompanyId,
    this.raisedByCompanyName,
    this.resolution,
    this.resolvedAt,
  });

  static double? _d(dynamic v) => (v as num?)?.toDouble();
  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString());

  factory ReconDispute.fromJson(Map<String, dynamic> j) => ReconDispute(
        id: j['id'] as String,
        tripId: j['trip_id'] as String,
        transactionId: j['transaction_id'] as String,
        category: DisputeCategory.parse(_s(j['category'])),
        reason: (j['reason'] ?? '').toString(),
        claimedTons: _d(j['claimed_tons']),
        status: DisputeStatus.parse(_s(j['status'])),
        reference: _s(j['reference']),
        truckReg: _s(j['truck_reg']),
        sourceName: _s(j['source_name']),
        customerName: _s(j['customer_name']),
        transporterName: _s(j['transporter_name']),
        mineNetTons: _d(j['mine_net_tons']),
        deliveredTons: _d(j['delivered_tons']),
        variance: _d(j['variance']),
        raisedByUserId: _s(j['raised_by_user_id']),
        raisedByName: _s(j['raised_by_name']),
        raisedByCompanyId: _s(j['raised_by_company_id']),
        raisedByCompanyName: _s(j['raised_by_company_name']),
        resolution: _s(j['resolution']),
        resolvedAt: _dt(j['resolved_at']),
        commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: DateTime.parse(j['updated_at'] as String),
      );
}

class ReconDisputeComment {
  final String id;
  final String? authorUserId;
  final String? authorName;
  final String? authorCompanyId;
  final String? authorCompanyName;
  final bool authorIsAdmin;
  final String body;
  final DateTime createdAt;

  const ReconDisputeComment({
    required this.id,
    required this.authorIsAdmin,
    required this.body,
    required this.createdAt,
    this.authorUserId,
    this.authorName,
    this.authorCompanyId,
    this.authorCompanyName,
  });

  factory ReconDisputeComment.fromJson(Map<String, dynamic> j) =>
      ReconDisputeComment(
        id: j['id'] as String,
        authorUserId: ReconDispute._s(j['author_user_id']),
        authorName: ReconDispute._s(j['author_name']),
        authorCompanyId: ReconDispute._s(j['author_company_id']),
        authorCompanyName: ReconDispute._s(j['author_company_name']),
        authorIsAdmin: (j['author_is_admin'] as bool?) ?? false,
        body: (j['body'] ?? '').toString(),
        createdAt: DateTime.parse(j['created_at'] as String),
      );
}
