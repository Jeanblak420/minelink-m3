import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/super_admin/data/models/organization_status.dart';
import 'package:flutter_application_1/features/super_admin/data/models/organization_seat.dart';
import 'package:flutter_application_1/features/super_admin/data/models/serial_token.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_link_builder.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_name_link.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/features/super_admin/widgets/token_generator_dialog.dart';
import 'package:flutter_application_1/features/super_admin/widgets/token_access_details.dart';
import 'package:flutter_application_1/features/super_admin/utils/audit_log_csv_exporter.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

String _nz(String? v) => (v != null && v.trim().isNotEmpty) ? v.trim() : '—';

class _UserDetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _UserDetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final v = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: context.mlText.bodyMedium.copyWith(
              color: v,
            )),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _EmployeeThumb extends StatelessWidget {
  final String? imageUrl;
  final String fallbackLetter;
  final Color? highlight;
  final Color? fg;

  const _EmployeeThumb({
    required this.imageUrl,
    required this.fallbackLetter,
    this.highlight,
    this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight ?? Theme.of(context).colorScheme.primaryContainer;
    final dim = 52.0;
    final letterStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: fg ?? Theme.of(context).colorScheme.onPrimaryContainer,
    );
    final url = imageUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: MlShape.radiusExtraLarge,
        child: CachedNetworkImage(
          imageUrl: url,
          width: dim,
          height: dim,
          fit: BoxFit.cover,
          placeholder: (_, __) => Container(
            width: dim,
            height: dim,
            color: bg,
            alignment: Alignment.center,
            child: Text(fallbackLetter, style: letterStyle),
          ),
          errorWidget: (_, __, ___) => Container(
            width: dim,
            height: dim,
            color: bg,
            alignment: Alignment.center,
            child: Text(fallbackLetter, style: letterStyle),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 26,
      backgroundColor: bg,
      child: Text(
        fallbackLetter,
        style: letterStyle,
      ),
    );
  }
}

class OrganizationDetailScreen extends ConsumerStatefulWidget {
  final String organizationId;
  const OrganizationDetailScreen({super.key, required this.organizationId});

  @override
  ConsumerState<OrganizationDetailScreen> createState() => _OrganizationDetailScreenState();
}

Widget _orgDetailBackButton(BuildContext context) {
  return IconButton(
    icon: const Icon(Icons.arrow_back_rounded),
    tooltip: 'Back to organizations',
    onPressed: () => context.go('/super-admin/organizations'),
  );
}

List<Widget> _orgDetailAppBarActions(BuildContext context) {
  return [
    IconButton(
      icon: const Icon(Icons.dashboard_outlined),
      tooltip: 'Super admin home',
      onPressed: () => context.go('/super-admin'),
    ),
  ];
}

class _OrganizationDetailScreenState extends ConsumerState<OrganizationDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const List<Tab> _orgDetailTabs = [
    Tab(text: 'Overview'),
    Tab(text: 'Users'),
    Tab(text: 'Tokens'),
    Tab(text: 'Seats'),
  ];

  Widget _orgDetailChrome(String title, {required bool showTabs}) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
            child: Row(
              children: [
                _orgDetailBackButton(context),
                Expanded(
                  child: Text(
                    title,
                    style: context.mlText.titleMedium.copyWith(
                      color: MlSemantic.of(context).textStrong,
                      fontWeight: FontWeight.w800,
                    ),
                    // TWO lines. This is the page's own title and it is a
                    // company NAME: between a back arrow and the actions it
                    // had 308px on a phone, so the screen a platform admin
                    // opens to act on one company was headed
                    // "Consolidated Mineral Offtake & Logi…".
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ..._orgDetailAppBarActions(context),
              ],
            ),
          ),
          if (showTabs) ...[
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: _orgDetailTabs,
            ),
            const Divider(height: 1),
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orgAsync = ref.watch(organizationDetailProvider(widget.organizationId));

    return orgAsync.when(
      loading: () => Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _orgDetailChrome('Organization', showTabs: false),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _orgDetailChrome('Organization', showTabs: false),
            Expanded(
              child: MlEmptyState(
                icon: Icons.error_outline,
                title: 'Could not load organization',
                message: friendlyError(e),
              ),
            ),
          ],
        ),
      ),
      data: (org) {
        if (org == null) {
          return Scaffold(
            backgroundColor: Colors.transparent,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _orgDetailChrome('Organization', showTabs: false),
                const Expanded(
                  child: MlEmptyState(
                    icon: Icons.domain_disabled_outlined,
                    title: 'Organization not found',
                    message: 'This organization could not be located.',
                  ),
                ),
              ],
            ),
          );
        }

        final name = org['company_name'] as String? ?? 'Unknown';
        final status = OrganizationStatus.fromString(org['status'] as String?);
        final orgType = org['org_type'] as String? ?? '';
        final seatLimit = org['seat_limit'] as int? ?? 0;
        final seatsUsed = org['seats_used'] as int? ?? 0;

        return Scaffold(
          backgroundColor: Colors.transparent,
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showTokenDialog(context, ref, widget.organizationId, name, seatLimit),
            icon: const Icon(Icons.vpn_key_rounded),
            label: const Text('Generate Token'),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _orgDetailChrome(name, showTabs: true),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(
                      organizationId: widget.organizationId,
                      org: org,
                      status: status,
                      orgType: orgType,
                      seatLimit: seatLimit,
                      seatsUsed: seatsUsed,
                    ),
                    _UsersTab(companyId: widget.organizationId),
                    _TokensTab(organizationId: widget.organizationId, orgName: name),
                    _SeatsTab(organizationId: widget.organizationId),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTokenDialog(BuildContext context, WidgetRef ref, String orgId, String orgName, int currentSeats) {
    showDialog(
      context: context,
      builder: (_) => TokenGeneratorDialog(
        organizationId: orgId,
        organizationName: orgName,
        currentSeatLimit: currentSeats,
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  final String organizationId;
  final Map<String, dynamic> org;
  final OrganizationStatus status;
  final String orgType;
  final int seatLimit;
  final int seatsUsed;

  const _OverviewTab({
    required this.organizationId,
    required this.org,
    required this.status,
    required this.orgType,
    required this.seatLimit,
    required this.seatsUsed,
  });

  static String _ownerName(Map<String, dynamic> org) {
    final raw = org['owner_profile'];
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final dn = m['display_name'] as String?;
      if (dn != null && dn.trim().isNotEmpty) return dn.trim();
      final em = m['email'] as String?;
      if (em != null && em.contains('@')) {
        return em.split('@').first;
      }
    }
    final ceo =
        '${org['ceo_first_name'] ?? ''} ${org['ceo_last_name'] ?? ''}'.trim();
    if (ceo.isNotEmpty) return ceo;
    return '—';
  }

  static String _ownerEmail(Map<String, dynamic> org) {
    final raw = org['owner_profile'];
    if (raw is Map) {
      final m = Map<String, dynamic>.from(raw);
      final em = m['email'] as String?;
      if (em != null && em.trim().isNotEmpty) return em.trim();
    }
    return '—';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokensAsync = ref.watch(organizationTokensProvider(organizationId));

    return tokensAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load tokens',
        message: friendlyError(e),
      ),
      data: (tokens) {
        final active = pickActiveSerialToken(tokens);
        final expirationIso = active?.expiresAt ??
            parseOrgTimestamp(org['token_expires_at']);
        final whatsapp = org['whatsapp_number'] as String?;
        final ownerContact =
            (whatsapp != null && whatsapp.trim().isNotEmpty)
                ? whatsapp.trim()
                : 'Not provided';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Builder(
                builder: (context) {
                  final tone = (status.isActive ? MlTone.done : MlTone.error)
                      .colors(Theme.of(context).brightness);
                  return Container(
                    decoration: BoxDecoration(
                      color: tone.bg,
                      borderRadius: BorderRadius.circular(MlTokens.rLg),
                      border: Border.all(color: tone.fg.withValues(alpha: 0.25)),
                    ),
                    // A Row, NOT a `ListTile`.
                    //
                    // A `ListTile` paints its background and its ink splashes
                    // on the nearest `Material` ancestor, so putting one inside
                    // a `Container` that has a colour makes the framework throw
                    //
                    //     ListTile background color or ink splashes may be
                    //     invisible.
                    //
                    // on EVERY BUILD, in debug — which is every frame a
                    // developer or a widget test sees. Nothing in this app
                    // reported it, because `shoot()` forwarded anything that
                    // was not one of four layout phrases to
                    // `tester.takeException()` and wrote the golden anyway.
                    // Second time that has happened; the harness catches
                    // everything now.
                    //
                    // The banner is not interactive — no tap, no splash — so
                    // the tile brought machinery it never used and an assertion
                    // it could not satisfy.
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Icon(
                        status.isActive
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded,
                        color: tone.fg,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                      Text('Status: ${status.displayName}',
                          style: TextStyle(
                            fontFamily: MlTokens.fontSans,
                            fontWeight: FontWeight.w700,
                            color: tone.fg,
                          )),
                      const SizedBox(height: 3),
                      // SAY WHAT THE NUMBER IS.
                      //
                      // The countdown was the bare subtitle, so a suspended
                      // company rendered
                      //
                      //     Status: Suspended
                      //     308d 9h 9m 29s
                      //
                      // — a figure sitting directly under a status line, in the
                      // position a subtitle takes to EXPLAIN the line above it,
                      // and explaining nothing: how long a token has left is
                      // unrelated to why an account was suspended. Naming it
                      // costs three words and removes the reading entirely.
                      if (expirationIso != null)
                        Row(
                          children: [
                            Text(
                              'Token expires in ',
                              style: context.mlText.bodyMedium.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                            Flexible(
                              child: TokenExpiryLiveCountdown(
                                expiresAt: expirationIso,
                                compact: true,
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          status.isActive
                              ? 'No token expiry on file'
                              : 'See access token section below',
                          style: context.mlText.bodyMedium.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                          ],
                        ),
                      ),
                      ],
                      ),
                    ),
                  );
                }),
              const SizedBox(height: 20),
              Text(
                'Company',
                style: context.mlText.titleMedium.copyWith(
                  color: MlSemantic.of(context).textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _InfoRow(
                  label: 'Company Name',
                  value: org['company_name'] as String? ?? '—'),
              _InfoRow(
                  label: 'Organization Type',
                  // `OrgType.labelFor`, not a private switch. This screen
                  // carried its own, returning "Mine / Supplier" — a second
                  // spelling of a word the rest of the console writes
                  // "Mine/Supplier", on the same admin's screens.
                  value: OrgType.labelFor(orgType)),
              _InfoRow(label: 'WhatsApp', value: ownerContact),
              _InfoRow(
                label: 'CEO',
                value:
                    '${org['ceo_first_name'] ?? ''} ${org['ceo_last_name'] ?? ''}'
                        .trim()
                        .isEmpty
                        ? '—'
                        : '${org['ceo_first_name'] ?? ''} ${org['ceo_last_name'] ?? ''}'
                            .trim(),
              ),
              const Divider(height: 32),
              Text(
                'Account owner (login)',
                style: context.mlText.titleMedium.copyWith(
                  color: MlSemantic.of(context).textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _InfoRow(label: 'Owner name', value: _ownerName(org)),
              _InfoRow(label: 'Owner email', value: _ownerEmail(org)),
              _InfoRow(label: 'Owner contact No.', value: ownerContact),
              const Divider(height: 32),
              Text(
                'Seats',
                style: context.mlText.titleMedium.copyWith(
                  color: MlSemantic.of(context).textStrong,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _InfoRow(label: 'Seat Limit', value: '$seatLimit'),
              _InfoRow(label: 'Seats Used', value: '$seatsUsed'),
              _InfoRow(
                  label: 'Seats Available',
                  value: '${seatLimit - seatsUsed}'),
              const Divider(height: 32),
              TokenAccessDetailsSection(
                activeToken: active,
                companyFallback: org,
              ),
              const Divider(height: 32),
              _ChatConnectionsSection(orgId: organizationId),
            ],
          ),
        );
      },
    );
  }
}

/// Super-admin chat-linking for a single company, shown on its profile.
/// Lists this company's current chat links (each clickable + revocable) and a
/// pre-locked [CompanyLinkBuilder] to connect it to another company. Chat links
/// are manual-only (see chat_connections_screen.dart).
class _ChatConnectionsSection extends ConsumerWidget {
  final String orgId;
  const _ChatConnectionsSection({required this.orgId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final companies = ref.watch(organizationsProvider).valueOrNull ?? const [];
    final connections =
        ref.watch(orgConnectionsProvider).valueOrNull ?? const [];

    String nameOf(String id) {
      final c = companies.firstWhere((e) => e['id'] == id,
          orElse: () => const {'company_name': 'Company'});
      final n = (c['company_name'] as String?)?.trim();
      return (n != null && n.isNotEmpty) ? n : 'Company';
    }

    String? typeOf(String id) {
      final c = companies.firstWhere((e) => e['id'] == id,
          orElse: () => const <String, dynamic>{});
      return c['org_type'] as String?;
    }

    final mine = connections
        .where((c) =>
            !c.isRevoked &&
            (c.companyLowId == orgId || c.companyHighId == orgId))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chat connections',
          style: context.mlText.titleMedium.copyWith(
            color: semantic.textStrong,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text('Companies this organization can message in MineLink Messenger.',
            style: context.mlText.bodyMedium.copyWith(color: semantic.textFaint)),
        const SizedBox(height: 12),
        if (mine.isEmpty)
          Text('No chat links yet.',
              style: context.mlText.bodyMedium.copyWith(
                color: semantic.textFaint,
              ))
        else
          for (final c in mine)
            Builder(builder: (context) {
              final otherId =
                  c.companyLowId == orgId ? c.companyHighId : c.companyLowId;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                              child: CompanyNameLink(
                                  companyId: otherId, name: nameOf(otherId))),
                          const SizedBox(width: 8),
                          Text('· ${companyOrgTypeLabel(typeOf(otherId))}',
                              style: context.mlText.bodySmall.copyWith(
                                color: semantic.textFaint,
                              )),
                        ],
                      ),
                    ),
                    MlButton.danger(
                      label: 'Revoke',
                      icon: Icons.link_off_rounded,
                      compact: true,
                      onPressed: () async {
                        await ref
                            .read(messagingServiceProvider)
                            .revokeConnection(c.id);
                        ref.invalidateIfMounted(orgConnectionsProvider);
                      },
                    ),
                  ],
                ),
              );
            }),
        const SizedBox(height: 16),
        Text('Link a company for chat',
            style: context.mlText.titleSmall.copyWith(
              color: semantic.textStrong,
              fontWeight: FontWeight.w700,
            )),
        const SizedBox(height: 8),
        Builder(builder: (context) {
          final linkedIds = {
            for (final c in mine)
              c.companyLowId == orgId ? c.companyHighId : c.companyLowId,
          };
          final hasLinkable = companies
              .any((c) => c['id'] != orgId && !linkedIds.contains(c['id']));
          if (!hasLinkable) {
            return Text(
                companies.length < 2
                    ? 'Add another company to create a link.'
                    : 'All other companies are already linked.',
                style: context.mlText.bodyMedium.copyWith(
                  color: semantic.textFaint,
                ));
          }
          return CompanyLinkBuilder(
            companies: companies,
            lockedLeftCompanyId: orgId,
            excludeIds: linkedIds,
            onLinked: () => ref.invalidate(orgConnectionsProvider),
          );
        }),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _UsersTab extends ConsumerWidget {
  final String companyId;
  const _UsersTab({required this.companyId});

  static const _availableRoles = [
    'management', 'admin', 'controllerWB', 'security', 'driver',
  ];

  static String? _profileEmail(Map<String, dynamic> userRow) {
    final p = userRow['profiles'];
    if (p is Map) {
      final m = Map<String, dynamic>.from(p);
      final e = m['email'] as String?;
      if (e != null && e.trim().isNotEmpty) {
        return e.trim();
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(companyUsersGroupedProvider(companyId));

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load users',
        message: friendlyError(e),
      ),
      data: (grouped) {
        if (grouped.isEmpty) {
          return const MlEmptyState(
            icon: Icons.people_outline,
            title: 'No users',
            message: 'No users in this organization yet.',
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: grouped.entries.map((entry) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${_roleLabel(entry.key)} (${entry.value.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                ...entry.value.map((u) {
                  final isSuspended = (u['status'] as String?) == 'suspended';
                  final userId = u['user_id'] as String?;
                  final employeeId = u['id'] as String? ?? '';
                  final fn = (u['first_name'] as String?)?.trim() ?? '';
                  final ln = (u['last_name'] as String?)?.trim() ?? '';
                  final name = '$fn $ln'.trim();
                  final photo = u['profile_photo_url'] as String?;
                  final wa = (u['whatsapp_number'] as String?)?.trim();
                  final idNo = (u['id_number'] as String?)?.trim();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: MlShape.radiusMedium,
                      side: BorderSide(
                        color: isSuspended
                            ? MlTokens.red600.withValues(alpha: 0.4)
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _EmployeeThumb(
                                imageUrl: photo,
                                fallbackLetter: name.isNotEmpty ? name[0] : '?',
                                highlight: isSuspended ? MlTokens.red600.withValues(alpha: 0.12) : null,
                                fg: isSuspended ? MlTokens.red600 : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name.isEmpty ? 'Unknown' : name,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                          ),
                                        ),
                                        if (isSuspended)
                                          Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: MlTokens.red600.withValues(alpha: 0.1),
                                              borderRadius: MlShape.radiusSmall,
                                            ),
                                            child: const Text(
                                              'Suspended',
                                              style: TextStyle(fontSize: 10, color: MlTokens.red600, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Role: ${UserRole.labelFor(u['role'] as String?, fallback: 'unassigned')}',
                                      style: context.mlText.bodyMedium.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    if (_UsersTab._profileEmail(u) case final em?) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        em,
                                        style: context.mlText.bodyMedium.copyWith(
                                          color: Theme.of(context).colorScheme.primary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded),
                                tooltip: 'User actions',
                                onSelected: (action) => _handleUserAction(context, ref, action, u, employeeId, userId, name),
                                itemBuilder: (_) => [
                                  if (!isSuspended)
                                    const PopupMenuItem(value: 'suspend', child: Row(children: [Icon(Icons.block_rounded, size: 18, color: MlTokens.red600), SizedBox(width: 8), Text('Suspend User')])),
                                  if (isSuspended)
                                    const PopupMenuItem(value: 'reactivate', child: Row(children: [Icon(Icons.check_circle_outline_rounded, size: 18, color: MlTokens.green600), SizedBox(width: 8), Text('Reactivate User')])),
                                  const PopupMenuItem(value: 'remove_seat', child: Row(children: [Icon(Icons.event_seat_rounded, size: 18, color: MlTokens.orange500), SizedBox(width: 8), Text('Remove from Seat')])),
                                  const PopupMenuItem(value: 'change_role', child: Row(children: [Icon(Icons.manage_accounts_rounded, size: 18), SizedBox(width: 8), Text('Change Role')])),
                                ],
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          _UserDetailLine(label: 'First name', value: fn.isEmpty ? '—' : fn),
                          _UserDetailLine(label: 'Last name', value: ln.isEmpty ? '—' : ln),
                          _UserDetailLine(label: 'Contact No.', value: _nz(wa)),
                          _UserDetailLine(label: 'WhatsApp No.', value: _nz(wa)),
                          _UserDetailLine(label: 'ID number', value: _nz(idNo)),
                        ],
                      ),
                    ),
                  );
                }),
                const Divider(),
              ],
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _handleUserAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    Map<String, dynamic> user,
    String employeeId,
    String? userId,
    String name,
  ) async {
    final repo = ref.read(superAdminRepositoryProvider);

    switch (action) {
      case 'suspend':
        final confirmed = await _confirm(
          context,
          title: 'Suspend $name?',
          message: 'This will prevent them from accessing the platform. You can reactivate them later.',
          confirmLabel: 'Suspend',
          danger: true,
        );
        if (confirmed != true || !context.mounted) return;
        await repo.suspendUser(employeeId: employeeId);
        ref.invalidateIfMounted(companyUsersGroupedProvider(companyId));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name suspended')));

      case 'reactivate':
        await repo.reactivateUser(employeeId: employeeId);
        ref.invalidateIfMounted(companyUsersGroupedProvider(companyId));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name reactivated')));

      case 'remove_seat':
        if (userId == null) {
          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No seat assigned to this user')));
          return;
        }
        final confirmed = await _confirm(
          context,
          title: 'Remove $name from seat?',
          message: 'Their seat will be released and made available to other users.',
          confirmLabel: 'Remove',
          danger: false,
        );
        if (confirmed != true || !context.mounted) return;
        await repo.removeUserFromSeat(userId: userId, companyId: companyId);
        ref.invalidateIfMounted(companyUsersGroupedProvider(companyId));
        ref.invalidateIfMounted(organizationSeatsProvider(companyId));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name removed from seat')));

      case 'change_role':
        final newRole = await _pickRole(context, current: user['role'] as String?);
        if (newRole == null || !context.mounted) return;
        await repo.changeEmployeeRole(employeeId: employeeId, newRole: newRole);
        ref.invalidateIfMounted(companyUsersGroupedProvider(companyId));
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$name role changed to $newRole')));
    }
  }

  // ⚠ Every dialog below pops with its own `dialogContext`, never the screen's
  // `context`. The console is a GoRouter `ShellRoute`, so the screen lives
  // under the shell's Navigator while `showDialog` pushes onto the root one —
  // popping with the screen's context removes the PAGE and the console goes
  // white with no exception. See `test/widgets/dialog_pops_the_dialog_test.dart`
  // and the `tool/dialog_context_check.py` guard.
  Future<bool?> _confirm(BuildContext context, {required String title, required String message, required String confirmLabel, bool danger = false}) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: MlTokens.red600) : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<String?> _pickRole(BuildContext context, {String? current}) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Select New Role'),
        children: _availableRoles.map((r) => SimpleDialogOption(
          onPressed: () => Navigator.pop(dialogContext, r),
          child: Row(children: [
            if (r == current) const Icon(Icons.check_rounded, size: 16, color: MlTokens.green600),
            if (r == current) const SizedBox(width: 8),
            Text(_roleLabel(r)),
          ]),
        )).toList(),
      ),
    );
  }

  String _roleLabel(String r) => UserRole.labelFor(r);
}

bool _serialTokenCountsAsValid(SerialToken t) {
  return t.status == 'active' && !t.expiresAt.isBefore(DateTime.now());
}

enum _TokenStatFilter { total, expired, valid }

class _TokensTab extends ConsumerStatefulWidget {
  final String organizationId;
  final String orgName;
  const _TokensTab({required this.organizationId, required this.orgName});

  @override
  ConsumerState<_TokensTab> createState() => _TokensTabState();
}

class _TokensTabState extends ConsumerState<_TokensTab> {
  _TokenStatFilter? _tokenFilter;
  Timer? _countdownPulse;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!TickerMode.valuesOf(context).enabled) {
      _countdownPulse?.cancel();
      _countdownPulse = null;
      return;
    }
    _countdownPulse ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _countdownPulse?.cancel();
    super.dispose();
  }

  void _toggleTokenFilter(_TokenStatFilter next) {
    setState(() {
      _tokenFilter = _tokenFilter == next ? null : next;
    });
  }

  List<SerialToken> _filteredTokens(List<SerialToken> tokens) {
    if (_tokenFilter == null || _tokenFilter == _TokenStatFilter.total) {
      return tokens;
    }
    if (_tokenFilter == _TokenStatFilter.valid) {
      return tokens.where(_serialTokenCountsAsValid).toList();
    }
    return tokens.where((t) => !_serialTokenCountsAsValid(t)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final tokensAsync = ref.watch(organizationTokensProvider(widget.organizationId));
    final canExport = ref.watch(superAdminCanExportDownloadsProvider);

    return tokensAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load tokens',
        message: friendlyError(e),
      ),
      data: (tokens) {
        if (tokens.isEmpty) {
          return const MlEmptyState(
            icon: Icons.vpn_key_outlined,
            title: 'No tokens',
            message: 'No tokens generated yet.',
          );
        }
        final validN = tokens.where(_serialTokenCountsAsValid).length;
        final expiredN = tokens.length - validN;
        final visible = _filteredTokens(tokens);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  Text(
                    '${tokens.length} token${tokens.length > 1 ? 's' : ''} on record',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const Spacer(),
                  if (canExport)
                    OutlinedButton.icon(
                      onPressed: () => _downloadTokenHistory(context, tokens),
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download History'),
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  _FilterStatCard(
                    label: 'TOTAL',
                    value: '${tokens.length}',
                    color: MlTokens.blue600,
                    selected: _tokenFilter == _TokenStatFilter.total,
                    onTap: () => _toggleTokenFilter(_TokenStatFilter.total),
                  ),
                  const SizedBox(width: 12),
                  _FilterStatCard(
                    label: 'EXPIRED',
                    value: '$expiredN',
                    color: MlTokens.green600,
                    selected: _tokenFilter == _TokenStatFilter.expired,
                    onTap: () => _toggleTokenFilter(_TokenStatFilter.expired),
                  ),
                  const SizedBox(width: 12),
                  _FilterStatCard(
                    label: 'VALID',
                    value: '$validN',
                    color: MlTokens.orange500,
                    selected: _tokenFilter == _TokenStatFilter.valid,
                    onTap: () => _toggleTokenFilter(_TokenStatFilter.valid),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        'No tokens in this category',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        Text(
                          'Token records',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        MlWideTable(
                          child: DataTable(
                            headingRowHeight: 44,
                            dataRowMinHeight: 52,
                            dataRowMaxHeight: 72,
                            headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                            border: TableBorder(
                              horizontalInside: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                              top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                              bottom: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                            ),
                            columns: const [
                              DataColumn(label: Text('Token Key')),
                              DataColumn(label: Text('Seats'), numeric: true),
                              DataColumn(label: Text('Active / Inactive')),
                              DataColumn(label: Text('Token Assigned')),
                              DataColumn(label: Text('Token Lifetime')),
                              DataColumn(label: Text('Token Expiration')),
                              DataColumn(label: Text('Token Expires in')),
                              DataColumn(label: Text('')),
                            ],
                            rows: [
                              for (final t in visible)
                                DataRow(
                                  cells: [
                                    DataCell(
                                      SelectableText(
                                        t.tokenPreview,
                                        style: context.mlText.code(size: 14),
                                      ),
                                    ),
                                    DataCell(Text('${t.seatLimit}')),
                                    DataCell(
                                      Text(
                                        _serialTokenCountsAsValid(t) ? 'Active' : 'Inactive',
                                        style: TextStyle(
                                          color: _serialTokenCountsAsValid(t)
                                              ? MlTokens.green600
                                              : Theme.of(context).colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    DataCell(Text(formatAccessTimestamp(t.issuedAt))),
                                    DataCell(Text('${t.validDays} days')),
                                    DataCell(Text(formatAccessTimestamp(t.expiresAt))),
                                    DataCell(
                                      Text(
                                        formatTokenExpiresRemaining(t.expiresAt, compact: true),
                                        style: context.mlText.labelMedium.copyWith(
                                          color: t.expiresAt.isBefore(DateTime.now()) ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      t.isActive
                                          ? TextButton(
                                              onPressed: () => _confirmRevoke(context, ref, t.id),
                                              child: const Text('Revoke', style: TextStyle(color: MlTokens.red600)),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  void _downloadTokenHistory(BuildContext context, List<dynamic> tokens) {
    AuditLogExporter.shareTokenHistoryCsv(context, tokens: tokens, orgName: widget.orgName);
  }

  void _confirmRevoke(BuildContext context, WidgetRef ref, String tokenId) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Revoke Token?'),
        content: const Text('This will suspend the organization and block all users until a new token is generated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: MlTokens.red600),
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await ref.read(superAdminRepositoryProvider).revokeSerialToken(tokenId: tokenId);
                ref.invalidateIfMounted(organizationTokensProvider(widget.organizationId));
                ref.invalidateIfMounted(organizationDetailProvider(widget.organizationId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Token revoked')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error. ${friendlyError(e)}')));
                }
              }
            },
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
  }
}

enum _SeatStatFilter { total, occupied, available }

class _SeatsTab extends ConsumerStatefulWidget {
  final String organizationId;
  const _SeatsTab({required this.organizationId});

  @override
  ConsumerState<_SeatsTab> createState() => _SeatsTabState();
}

class _SeatsTabState extends ConsumerState<_SeatsTab> {
  _SeatStatFilter? _seatFilter;

  void _toggleSeatFilter(_SeatStatFilter next) {
    setState(() {
      _seatFilter = _seatFilter == next ? null : next;
    });
  }

  /// Move an occupied seat to another member of the same company.
  ///
  /// `reassign_seat` has existed with the whole governance in it — authorised
  /// caller, role binding, role valid for the org type, and **max 2 per company
  /// per 30 days** — and had **no call site anywhere in the app**, so none of it
  /// could be reached. This is that call site.
  ///
  /// The remaining allowance is read first and shown up front, because finding
  /// out you have run out only after choosing somebody is a worse way to learn
  /// it.
  Future<void> _reassignSeat(BuildContext context, OrganizationSeat seat) async {
    final repo = ref.read(superAdminRepositoryProvider);

    Map<String, dynamic> allowance;
    List<Map<String, dynamic>> candidates;
    try {
      allowance = await repo.seatReassignmentAllowance(widget.organizationId);
      final grouped =
          await ref.read(companyUsersGroupedProvider(widget.organizationId).future);
      candidates = [
        for (final list in grouped.values)
          for (final u in list)
            if (u['user_id'] != null && u['user_id'] != seat.occupiedByUserId)
              u,
      ];
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
      return;
    }
    if (!context.mounted) return;

    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No other member of this company to move the seat to.')));
      return;
    }

    final remaining = allowance['remaining'] as int? ?? 0;
    final chosen = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reassign seat ${seat.seatNumber}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                remaining > 0
                    ? 'Currently ${seat.occupiedByName ?? 'unassigned'}. '
                        '$remaining of ${allowance['limit'] ?? 2} reassignments '
                        'left in the next ${allowance['period_days'] ?? 30} days.'
                    : 'This company has used all ${allowance['limit'] ?? 2} '
                        'reassignments for the current '
                        '${allowance['period_days'] ?? 30}-day window.',
                style: context.mlText.bodyMedium.copyWith(
                  color: remaining > 0 ? Theme.of(ctx).colorScheme.onSurfaceVariant : Theme.of(ctx).colorScheme.error,
                ),
              ),
              if (seat.roleBinding != null) ...[
                const SizedBox(height: 6),
                Text('This seat is bound to ${seat.roleBinding}.',
                    style: context.mlText.bodyMedium.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    )),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final u in candidates)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                            '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                                .trim()
                                .isEmpty
                            ? (u['email'] as String? ?? 'Unnamed')
                            : '${u['first_name'] ?? ''} ${u['last_name'] ?? ''}'
                                .trim()),
                        subtitle: Text(
                            '${u['email'] ?? '—'} · '
                            '${UserRole.labelFor(u['role'] as String?, fallback: 'no role')}'),
                        onTap: remaining > 0
                            ? () => Navigator.of(ctx).pop(u)
                            : null,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (chosen == null || !context.mounted) return;

    try {
      final name = '${chosen['first_name'] ?? ''} ${chosen['last_name'] ?? ''}'
          .trim();
      final res = await repo.reassignSeat(
        seatId: seat.id,
        newUserId: chosen['user_id'] as String,
        newUserEmail: (chosen['email'] as String?) ?? '',
        newUserName: name.isEmpty ? (chosen['email'] as String? ?? '') : name,
        newUserRole: (chosen['role'] as String?) ?? '',
      );
      final ok = res['success'] == true;
      ref.invalidate(organizationSeatsProvider(widget.organizationId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Seat ${seat.seatNumber} reassigned.'
              : (res['error'] as String? ?? 'Reassignment refused.')),
        ));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  List<OrganizationSeat> _filteredSeats(List<OrganizationSeat> seats) {
    if (_seatFilter == null || _seatFilter == _SeatStatFilter.total) {
      return seats;
    }
    if (_seatFilter == _SeatStatFilter.occupied) {
      return seats.where((s) => s.isOccupied).toList();
    }
    return seats.where((s) => s.isAvailable).toList();
  }

  @override
  Widget build(BuildContext context) {
    final seatsAsync = ref.watch(organizationSeatsProvider(widget.organizationId));

    return seatsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load seats',
        message: friendlyError(e),
      ),
      data: (seats) {
        if (seats.isEmpty) {
          return const MlEmptyState(
            icon: Icons.event_seat_outlined,
            title: 'No seats',
            message: 'No seats allocated yet.',
          );
        }
        final occupied = seats.where((s) => s.isOccupied).length;
        final available = seats.where((s) => s.isAvailable).length;
        final visible = _filteredSeats(seats);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _FilterStatCard(
                    label: 'TOTAL',
                    value: '${seats.length}',
                    color: MlTokens.blue600,
                    selected: _seatFilter == _SeatStatFilter.total,
                    onTap: () => _toggleSeatFilter(_SeatStatFilter.total),
                  ),
                  const SizedBox(width: 12),
                  _FilterStatCard(
                    label: 'OCCUPIED',
                    value: '$occupied',
                    color: MlTokens.green600,
                    selected: _seatFilter == _SeatStatFilter.occupied,
                    onTap: () => _toggleSeatFilter(_SeatStatFilter.occupied),
                  ),
                  const SizedBox(width: 12),
                  _FilterStatCard(
                    label: 'AVAILABLE',
                    value: '$available',
                    color: MlTokens.orange500,
                    selected: _seatFilter == _SeatStatFilter.available,
                    onTap: () => _toggleSeatFilter(_SeatStatFilter.available),
                  ),
                ],
              ),
            ),
            Expanded(
              child: visible.isEmpty
                  ? Center(
                      child: Text(
                        'No seats in this category',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: visible.length,
                      itemBuilder: (context, i) {
                        final s = visible[i];
                        final fn = s.employeeFirstName?.trim();
                        final ln = s.employeeLastName?.trim();
                        final seatTitle = s.isOccupied
                            ? '${fn ?? ''} ${ln ?? ''}'.trim().isNotEmpty
                                ? '${fn ?? ''} ${ln ?? ''}'.trim()
                                : (s.occupiedByName ?? 'Occupied')
                            : 'Available';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: MlShape.radiusMedium,
                            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                          ),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: s.isOccupied ? MlTokens.green600.withValues(alpha: 0.15) : MlTokens.slate500.withValues(alpha: 0.15),
                              child: Text('${s.seatNumber}', style: TextStyle(color: s.isOccupied ? MlTokens.green600 : MlTokens.slate500, fontWeight: FontWeight.bold)),
                            ),
                            title: Text('Seat ${s.seatNumber} · $seatTitle'),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                // S4-3: the occupant's role was stored and
                                // parsed but never shown anywhere. A seat list
                                // that does not say what each seat is being
                                // used for is a list of numbers.
                                s.isOccupied
                                    ? [
                                        _nz(s.occupiedByEmail),
                                        if (s.occupiedByEmployeeRole != null)
                                          s.occupiedByEmployeeRole!,
                                      ].join(' · ')
                                    : s.roleBinding != null
                                        ? 'No assignee · bound to ${s.roleBinding}'
                                        : 'No assignee',
                                style: context.mlText.bodyMedium.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            trailing: Text(
                              s.status,
                              style: context.mlText.bodySmall.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            children: [
                              if (s.isOccupied)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _EmployeeThumb(
                                        imageUrl: s.employeeProfilePhotoUrl,
                                        fallbackLetter: seatTitle.isNotEmpty ? seatTitle[0] : '?',
                                        highlight: MlTokens.green600.withValues(alpha: 0.12),
                                        fg: MlTokens.green800,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _UserDetailLine(label: 'First name', value: _nz(fn)),
                                            _UserDetailLine(label: 'Last name', value: _nz(ln)),
                                            _UserDetailLine(label: 'Contact No.', value: _nz(s.employeeWhatsapp)),
                                            _UserDetailLine(label: 'WhatsApp No.', value: _nz(s.employeeWhatsapp)),
                                            _UserDetailLine(label: 'ID number', value: _nz(s.employeeIdNumber)),
                                            _UserDetailLine(label: 'Login email', value: _nz(s.occupiedByEmail)),
                                            _UserDetailLine(label: 'Role', value: _nz(s.occupiedByEmployeeRole)),
                                            _UserDetailLine(label: 'Seat serial', value: _nz(s.serialNumber)),
                                            const SizedBox(height: 10),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: MlButton.outline(
                                                label: 'Reassign seat',
                                                icon: Icons.swap_horiz_rounded,
                                                compact: true,
                                                onPressed: () =>
                                                    _reassignSeat(context, s),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Clickable dashboard stat that toggles list filtering (tap again to clear).
class _FilterStatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterStatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MlTokens.rMd),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: selected ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(MlTokens.rMd),
              border: Border.all(
                color: selected ? color : semantic.borderCard,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected ? MlTokens.shadowSm : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text(
                    value,
                    style: context.mlText.code(
                      color: color,
                      size: 24,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: context.mlText.labelSmall.copyWith(
                      color: semantic.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
