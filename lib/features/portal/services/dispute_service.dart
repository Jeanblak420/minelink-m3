import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/portal/models/recon_dispute.dart';

/// Reconciliation disputes data access (CLAUDE.md §6 — all DB access via a
/// service). Every method calls a SECURITY DEFINER RPC that self-authorizes
/// (trip party or platform admin); the Dart layer is UX only.
class DisputeService {
  final SupabaseClient _client = SupabaseConfig.client;

  /// Disputes for [companyId] (a party company), newest first. Pass null as a
  /// platform admin to get every dispute.
  Future<List<ReconDispute>> listDisputes(String? companyId) async {
    final rows = await _client.rpc(
      'list_recon_disputes',
      params: {'p_company_id': companyId},
    );
    return (rows as List)
        .map((e) => ReconDispute.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ReconDisputeComment>> listComments(String disputeId) async {
    final rows = await _client.rpc(
      'list_recon_dispute_comments',
      params: {'p_dispute_id': disputeId},
    );
    return (rows as List)
        .map((e) => ReconDisputeComment.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Raise a dispute on a trip's reconciliation. Returns the new dispute id.
  Future<String> raise({
    required String tripId,
    required DisputeCategory category,
    required String reason,
    double? claimedTons,
  }) async {
    final res = await _client.rpc('raise_recon_dispute', params: {
      'p_trip_id': tripId,
      'p_category': category.wire,
      'p_reason': reason,
      'p_claimed_tons': claimedTons,
    });
    return (Map<String, dynamic>.from(res as Map)['id']).toString();
  }

  Future<void> addComment(String disputeId, String body) async {
    await _client.rpc('add_recon_dispute_comment', params: {
      'p_dispute_id': disputeId,
      'p_body': body,
    });
  }

  /// Advance a dispute's status. `under_review` / `resolved` / `rejected` are
  /// admin-only (server-enforced); `withdrawn` is the raiser's own action.
  /// `resolved` / `rejected` require a [resolution] note.
  Future<void> setStatus(
    String disputeId,
    DisputeStatus status, {
    String? resolution,
  }) async {
    await _client.rpc('set_recon_dispute_status', params: {
      'p_dispute_id': disputeId,
      'p_status': status.wire,
      'p_resolution': resolution,
    });
  }
}

final disputeServiceProvider = Provider<DisputeService>((ref) => DisputeService());

/// Disputes visible to a company (or all, keyed with null for a platform
/// admin). Invalidate after any mutation to refresh.
final reconDisputesProvider =
    FutureProvider.family.autoDispose<List<ReconDispute>, String?>(
  (ref, companyId) => ref.read(disputeServiceProvider).listDisputes(companyId),
);

/// The comment thread for one dispute (oldest first).
final disputeCommentsProvider =
    FutureProvider.family.autoDispose<List<ReconDisputeComment>, String>(
  (ref, disputeId) => ref.read(disputeServiceProvider).listComments(disputeId),
);
