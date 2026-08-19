import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Drilldown for the dashboard "Total Users" registry card
/// (`/super-admin/users`).
///
/// Lists every platform user (employees table), grouped by company, with a
/// debounce-free `SearchBar` for first-name / last-name / email / company
/// lookup. Each row is clickable on both Windows (mouse-click) and mobile
/// (tap) — the same callback handles both — and routes to the existing
/// `/super-admin/organization/<companyId>` screen where the user lives inside
/// the company's roster (avoids creating a duplicate per-user detail view).
class PlatformUsersScreen extends ConsumerStatefulWidget {
  const PlatformUsersScreen({super.key});

  @override
  ConsumerState<PlatformUsersScreen> createState() =>
      _PlatformUsersScreenState();
}

class _PlatformUsersScreenState extends ConsumerState<PlatformUsersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(allPlatformUsersProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Platform users',
                        style: TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontSize: MlTokens.fsH3,
                          fontWeight: FontWeight.w800,
                          color: MlSemantic.of(context).textStrong,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Every employee on the platform, grouped by company. '
                        'Tap a user or company to drill into the organization.',
                        style: TextStyle(
                          fontFamily: MlTokens.fontSans,
                          color: cs.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () =>
                      ref.invalidate(allPlatformUsersProvider),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SearchBar(
              hintText: 'Search by name, email, or company…',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          Expanded(
            child: usersAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => MlEmptyState(
                icon: Icons.error_outline,
                title: 'Could not load users',
                message: friendlyError(e),
                action: MlButton.primary(
                  label: 'Retry',
                  icon: Icons.refresh,
                  onPressed: () => ref.invalidate(allPlatformUsersProvider),
                ),
              ),
              data: (users) => _buildUserList(users),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserList(List<Map<String, dynamic>> users) {
    final filtered = _query.isEmpty
        ? users
        : users.where((u) => _matchesQuery(u, _query)).toList();

    if (filtered.isEmpty) {
      return MlEmptyState(
        icon: Icons.people_alt_outlined,
        title: 'No platform users',
        message: _query.isEmpty
            ? 'No platform users yet.'
            : 'No users match "$_query".',
      );
    }

    // Group by company id (keep an "unassigned" bucket for orphan rows).
    final byCompany = <String, _CompanyBucket>{};
    for (final u in filtered) {
      final cid = (u['company_id'] as String?) ?? '__orphan__';
      final cname = (u['company_name'] as String?)?.trim();
      final bucket = byCompany.putIfAbsent(
        cid,
        () => _CompanyBucket(
          companyId: cid == '__orphan__' ? null : cid,
          companyName: cname == null || cname.isEmpty
              ? 'Unassigned'
              : cname,
          orgType: u['org_type'] as String?,
        ),
      );
      bucket.users.add(u);
    }

    // Stable order: by company name, "Unassigned" last.
    final sortedBuckets = byCompany.values.toList()
      ..sort((a, b) {
        if (a.companyId == null) return 1;
        if (b.companyId == null) return -1;
        return a.companyName.toLowerCase().compareTo(b.companyName.toLowerCase());
      });

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(allPlatformUsersProvider),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: sortedBuckets.length,
        itemBuilder: (context, i) =>
            _CompanyUsersSection(bucket: sortedBuckets[i]),
      ),
    );
  }

  static bool _matchesQuery(Map<String, dynamic> u, String q) {
    final parts = <String?>[
      u['first_name'] as String?,
      u['last_name'] as String?,
      u['company_name'] as String?,
      u['role'] as String?,
      (u['profiles'] is Map)
          ? (u['profiles']['email'] as String?)
          : null,
      (u['profiles'] is Map)
          ? (u['profiles']['display_name'] as String?)
          : null,
    ];
    for (final p in parts) {
      if (p != null && p.toLowerCase().contains(q)) return true;
    }
    return false;
  }
}

class _CompanyBucket {
  final String? companyId;
  final String companyName;
  final String? orgType;
  final List<Map<String, dynamic>> users = [];

  _CompanyBucket({
    required this.companyId,
    required this.companyName,
    required this.orgType,
  });
}

class _CompanyUsersSection extends StatelessWidget {
  final _CompanyBucket bucket;
  const _CompanyUsersSection({required this.bucket});

  @override
  Widget build(BuildContext context) {
    final hasCompany = bucket.companyId != null;
    final orgLabel = _orgTypeLabel(bucket.orgType);
    final subtitle = orgLabel == null
        ? '${bucket.users.length} user${bucket.users.length == 1 ? '' : 's'}'
        : '$orgLabel · ${bucket.users.length} user${bucket.users.length == 1 ? '' : 's'}';

    final semantic = MlSemantic.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rLg),
        border: Border.all(color: semantic.borderCard),
        boxShadow: MlTokens.shadowSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Company header — itself a clickable row.
          InkWell(
            onTap: hasCompany
                ? () => context
                    .go('/super-admin/organization/${bucket.companyId}')
                : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
              child: Row(
                children: [
                  MlIconWell(
                    icon: _orgTypeIcon(bucket.orgType),
                    tone: MlTone.accent,
                    size: 40,
                    radius: 11,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bucket.companyName,
                          style: TextStyle(
                            fontFamily: MlTokens.fontSans,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: semantic.textStrong,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontFamily: MlTokens.fontSans,
                            fontSize: 12,
                            color: semantic.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasCompany)
                    Icon(Icons.chevron_right_rounded,
                        color: semantic.textFaint),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: semantic.divider),
          for (var i = 0; i < bucket.users.length; i++) ...[
            _UserRow(
              user: bucket.users[i],
              companyId: bucket.companyId,
            ),
            if (i < bucket.users.length - 1)
              Divider(height: 1, color: semantic.divider),
          ],
        ],
      ),
    );
  }

  static IconData _orgTypeIcon(String? type) {
    switch (type) {
      case 'mineSupplier':
        return Icons.terrain_rounded;
      case 'buyer':
        return Icons.shopping_bag_outlined;
      case 'transporter':
        return Icons.local_shipping_outlined;
      default:
        return Icons.business_rounded;
    }
  }

  static String? _orgTypeLabel(String? type) {
    switch (type) {
      case 'mineSupplier':
        return 'Mine/Supplier';
      case 'buyer':
        return 'Buyer';
      case 'transporter':
        return 'Transporter';
      case null:
      case '':
        return null;
      default:
        return type;
    }
  }
}

class _UserRow extends StatelessWidget {
  final Map<String, dynamic> user;
  final String? companyId;

  const _UserRow({required this.user, required this.companyId});

  @override
  Widget build(BuildContext context) {
    final first = (user['first_name'] as String?)?.trim() ?? '';
    final last = (user['last_name'] as String?)?.trim() ?? '';
    final fullName = '$first $last'.trim();
    final displayName = fullName.isEmpty ? 'Unnamed user' : fullName;
    final roleRaw = user['role'] as String?;
    final roleLabel = _roleLabel(roleRaw);
    final profile = user['profiles'];
    String? email;
    if (profile is Map) {
      email = (profile['email'] as String?)?.trim();
      if (email != null && email.isEmpty) email = null;
    }

    final semantic = MlSemantic.of(context);
    return InkWell(
      onTap: companyId == null
          ? null
          : () => context.go('/super-admin/organization/$companyId'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: MlTone.accent.well(Theme.of(context).brightness),
              child: Text(
                _initials(first, last),
                style: const TextStyle(
                  fontFamily: MlTokens.fontSans,
                  fontWeight: FontWeight.w700,
                  color: MlTokens.accentHover,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontFamily: MlTokens.fontSans,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: semantic.textStrong,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (roleLabel != null) roleLabel,
                      if (email != null) email,
                    ].join(' · '),
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: 12,
                      color: semantic.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (companyId != null)
              Icon(Icons.chevron_right_rounded, color: semantic.textFaint),
          ],
        ),
      ),
    );
  }

  static String _initials(String first, String last) {
    String pick(String s) => s.isEmpty ? '' : s[0].toUpperCase();
    final ini = '${pick(first)}${pick(last)}';
    return ini.isEmpty ? '?' : ini;
  }

  static String? _roleLabel(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return UserRole.tryParse(raw)?.label ?? raw;
  }
}
