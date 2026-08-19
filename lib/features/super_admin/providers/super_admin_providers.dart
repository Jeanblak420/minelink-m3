import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import '../data/models/models.dart';
import '../data/models/company_monthly_ops_stats.dart';
import '../data/models/insights_period.dart';
import '../data/repositories/super_admin_repository.dart';

/// Provider for the SuperAdminRepository
final superAdminRepositoryProvider = Provider<SuperAdminRepository>((ref) {
  return SuperAdminRepository(Supabase.instance.client);
});

/// Provider for dashboard stats
final dashboardStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getDashboardStats();
});

/// Provider for all organizations
final organizationsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getAllOrganizations();
});

/// Company pairs implied by accepted business — feeds the chat-link
/// recommendations panel and annotates "why" on connected cards.
final businessPairsProvider = FutureProvider<List<BusinessPair>>((ref) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getBusinessPairs();
});

/// Provider for organizations grouped by type
final organizationsGroupedProvider = FutureProvider<Map<String, List<Map<String, dynamic>>>>((ref) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getOrganizationsGroupedByType();
});

/// Stream provider for real-time organizations
final organizationsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.watchOrganizations();
});

/// Provider for a single organization
final organizationDetailProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, orgId) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getOrganizationById(orgId);
});

/// Provider for company users grouped by role
final companyUsersGroupedProvider = FutureProvider.family<Map<String, List<Map<String, dynamic>>>, String>((ref, companyId) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getUsersGroupedByRole(companyId);
});

/// Every platform user (employee row + merged company + merged profile fields).
/// Powers the dashboard "Total users" deep-link at `/super-admin/users`.
final allPlatformUsersProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getAllPlatformUsers();
});

/// Provider for organization tokens
final organizationTokensProvider = FutureProvider.family<List<SerialToken>, String>((ref, orgId) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getOrganizationTokens(orgId);
});

/// Provider for organization seats
final organizationSeatsProvider = FutureProvider.family<List<OrganizationSeat>, String>((ref, orgId) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getOrganizationSeats(orgId);
});

/// Provider for open token requests (pending + in progress)
final openTokenRequestsProvider = FutureProvider<List<TokenRequest>>((ref) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getOpenTokenRequests();
});

/// Crash report rows for the console screen (Task 4), filtered SERVER-SIDE
/// by the family key. Fix round 1: filtering used to happen client-side over
/// an already-capped page, which is wrong once this table has grown past
/// [SuperAdminRepository.getCrashReports]'s row cap — a client-side "Fatal
/// only" filter over the 500 newest rows can miss an older fatal report that
/// server-side filtering (cap applied AFTER the `eq`) would still find.
final crashReportsProvider = FutureProvider.family<List<CrashReportRow>,
    ({bool fatalOnly, String? platform, String? appVersion})>(
  (ref, f) async {
    final repo = ref.watch(superAdminRepositoryProvider);
    return repo.getCrashReports(
      fatalOnly: f.fatalOnly,
      platform: f.platform,
      appVersion: f.appVersion,
    );
  },
);

/// Distinct platform / app_version values across ALL crash reports, for the
/// console screen's facet chips — deliberately NOT keyed by the current
/// filter selection, so the chip list itself never shrinks just because a
/// filter is applied.
final crashReportFacetsProvider =
    FutureProvider<({Set<String> platforms, Set<String> appVersions})>(
        (ref) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getCrashReportFacets();
});

/// Account deactivation review queue for the console screen (Task 10).
/// Deliberately fetches EVERY status (the RPC's own default `p_status`
/// argument is `'pending'`, which this provider does not use) — the screen's
/// default view is everything except the terminal states, and filtering
/// that down from one full fetch is simpler and just as correct as trying to
/// express it in the RPC's single-status signature.
final accountDeactivationRequestsProvider =
    FutureProvider.autoDispose<List<AccountDeactivationRow>>((ref) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getAccountDeactivationRequests();
});

/// Provider for audit logs
final auditLogsProvider = FutureProvider.family<List<AuditLog>, Map<String, dynamic>?>((ref, filters) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getAuditLogs(
    actorUserId: filters?['actorUserId'] as String?,
    organizationId: filters?['organizationId'] as String?,
    organizationType: filters?['organizationType'] as String?,
    actionType: filters?['actionType'] as String?,
    actionTypes: (filters?['actionTypes'] as List?)?.cast<String>(),
    startDate: filters?['startDate'] as DateTime?,
    endDate: filters?['endDate'] as DateTime?,
  );
});

/// Token-related audit log slice for one organization type tab (token history screen).
///
/// Loads the **500 most recent** matching rows per tab. There is no pagination or cursor UI yet;
/// add it later by threading [SuperAdminRepository.getAuditLogs] `limit` / `offset` (or a cursor)
/// through this provider family and the token history screen.
final tokenHistoryAuditLogsProvider =
    FutureProvider.family<List<AuditLog>, String>((ref, organizationType) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getAuditLogs(
    organizationType: organizationType,
    actionTypes: AuditActionTypes.tokenHistoryActions,
    limit: 500,
    offset: 0,
  );
});

/// Stream provider for real-time audit logs
final auditLogsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.watchAuditLogs();
});

/// Provider for platform admin settings
final platformAdminSettingsProvider = FutureProvider<PlatformAdminSettings?>((ref) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getPlatformAdminSettings();
});

/// Provider for the current user's platform role.
///
/// Must watch [authStateProvider] so a new login (or account switch) does not reuse
/// a cached `normalUser` from the previous session.
final currentPlatformRoleProvider = FutureProvider<PlatformRole>((ref) async {
  final userId = ref.watch(authStateProvider.select((s) => s.user?.id));
  if (userId == null) return PlatformRole.normalUser;

  final client = Supabase.instance.client;

  // Prefer security-definer RPC (same source as RLS helpers).
  try {
    final rpcRole = await client.rpc('current_platform_role');
    if (rpcRole is String && rpcRole.isNotEmpty) {
      return PlatformRole.fromString(rpcRole);
    }
  } catch (_) {
    // Fall back to direct profile read when RPC is unavailable.
  }

  final response = await client
      .from('profiles')
      .select('platform_role')
      .eq('id', userId)
      .maybeSingle();

  if (response == null) return PlatformRole.normalUser;
  return PlatformRole.fromString(response['platform_role'] as String?);
});

/// CSV / file exports from the super-admin area (audit logs, token history, insights export).
///
/// Every super global admin has full rights, so any super admin may export.
final superAdminCanExportDownloadsProvider = Provider<bool>((ref) {
  final role = ref.watch(currentPlatformRoleProvider).valueOrNull;
  return role?.isSuperAdmin ?? false;
});

/// Single RPC round-trip per org type (companies + aggregate). Prefer watching this for layer 1–2.
final monthlyInsightsBundleProvider =
    FutureProvider.family<MonthlyInsightsBundle, String>((ref, orgType) async {
  final repo = ref.watch(superAdminRepositoryProvider);
  return repo.getMonthlyInsightsBundle(orgType);
});

/// The same bundle over an explicit window — what the leaderboard's period
/// control reads.
///
/// Keyed by (orgType, period) rather than by a pair of dates so the key stays
/// stable across rebuilds; the window is computed from the period at fetch
/// time. Every column on the board therefore comes back scoped by the same SQL
/// the overview uses, instead of being re-derived client-side where it could
/// drift from that screen.
final periodInsightsBundleProvider = FutureProvider.family
    .autoDispose<MonthlyInsightsBundle, (String, InsightsPeriod)>((ref, key) {
  final (orgType, period) = key;
  final window = period.window();
  return ref.watch(superAdminRepositoryProvider).getMonthlyInsightsBundle(
        orgType,
        rangeStart: window.start,
        rangeEnd: window.end,
      );
});

/// Monthly operational stats per company for an org type (mineSupplier | buyer | transporter).
final companyMonthlyOpsStatsProvider =
    FutureProvider.family<List<CompanyMonthlyOpsStats>, String>((ref, orgType) async {
  final bundle = await ref.watch(monthlyInsightsBundleProvider(orgType).future);
  return bundle.companies;
});

/// Aggregated totals for all companies of an org type (current month).
final orgTypeAggregateStatsProvider =
    FutureProvider.family<OrgTypeAggregateStats, String>((ref, orgType) async {
  final bundle = await ref.watch(monthlyInsightsBundleProvider(orgType).future);
  return bundle.aggregate;
});

