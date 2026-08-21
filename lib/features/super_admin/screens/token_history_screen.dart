import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/super_admin/data/models/models.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_link_builder.dart'
    show companyOrgTypeLabel;
import 'package:intl/intl.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Audit timeline of token-related actions, tabbed by organization type.
class TokenHistoryScreen extends ConsumerStatefulWidget {
  const TokenHistoryScreen({super.key});

  @override
  ConsumerState<TokenHistoryScreen> createState() => _TokenHistoryScreenState();
}

class _TokenHistoryScreenState extends ConsumerState<TokenHistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _orgTypes = ['transporter', 'buyer', 'mineSupplier'];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _orgTypes.length, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _tabLabel(String key) {
    switch (key) {
      case 'mineSupplier':
        return 'Mines / suppliers';
      case 'buyer':
        return 'Buyers';
      case 'transporter':
      default:
        return 'Transporters';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // THIS SCREEN HAD NO TITLE.
          //
          // Every other console screen states what it is - Audit Logs, Crash
          // reports, Account deactivations, Live map - and this one opened
          // straight onto a tab bar, so an admin arriving from the rail landed
          // on three org-type tabs with nothing saying what was being listed.
          // Jean's brief is about the placement of everything; a screen missing
          // the one piece of chrome that names it is not that.
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: MlPageHeader(
              title: 'Token history',
              description: 'Every token-related action on the platform, newest '
                  'first, grouped by the organization it happened to.',
            ),
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabs,
            isScrollable: true,
            tabs: [for (final t in _orgTypes) Tab(text: _tabLabel(t))],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [for (final t in _orgTypes) _OrgTypeAuditTab(orgType: t)],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrgTypeAuditTab extends ConsumerWidget {
  final String orgType;

  const _OrgTypeAuditTab({required this.orgType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(tokenHistoryAuditLogsProvider(orgType));
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => MlEmptyState(
        icon: Icons.error_outline,
        title: 'Could not load history',
        message: friendlyError(e),
      ),
      data: (logs) {
        if (logs.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(tokenHistoryAuditLogsProvider(orgType)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 80),
                MlEmptyState(
                  icon: Icons.history_toggle_off,
                  title: 'No token history',
                  message: 'No token-related audit entries for this type yet.',
                ),
              ],
            ),
          );
        }
        final byOrg = <String, List<AuditLog>>{};
        for (final log in logs) {
          final oid = log.organizationId ?? '—';
          byOrg.putIfAbsent(oid, () => []).add(log);
        }
        final orgKeys = byOrg.keys.toList()
          ..sort((a, b) => (byOrg[b]!.first.createdAt).compareTo(byOrg[a]!.first.createdAt));

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(tokenHistoryAuditLogsProvider(orgType)),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orgKeys.length,
            itemBuilder: (context, i) {
              final oid = orgKeys[i];
              final entries = byOrg[oid]!..sort((a, b) => b.createdAt.compareTo(a.createdAt));
              final title = entries.first.organizationName ?? oid;
              final semantic = MlSemantic.of(context);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: MlCard(
                  padding: EdgeInsets.zero,
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: const MlIconWell(
                        icon: Icons.vpn_key_outlined,
                        tone: MlTone.accent,
                        size: 38,
                        radius: 11,
                      ),
                      title: Text(
                        title,
                        style: context.mlText.titleMedium.copyWith(
                          color: semantic.textStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        // Was "9 events · org o1". `oid` is a database key: when
                        // the name IS known it adds nothing, and when it is not
                        // the title already shows it (`title = organizationName
                        // ?? oid`) — so the id was either noise or a
                        // repetition. The org TYPE is the useful second fact,
                        // and it is what the tab above is filtered by.
                        '${entries.length} '
                        '${entries.length == 1 ? 'event' : 'events'}'
                        '${entries.first.organizationType == null ? '' : ' · '
                            '${companyOrgTypeLabel(entries.first.organizationType)}'}',
                        style: context.mlText.bodyMedium.copyWith(
                          color: semantic.textMuted,
                        ),
                      ),
                      children: [
                        for (final log in entries)
                          ListTile(
                            dense: true,
                            title: Text(
                              // Not `log.actionType`: that is the wire value,
                              // and it rendered as TOKEN_GENERATED here while
                              // the audit-log screen said "Token Generated" for
                              // the very same row.
                              log.actionLabel,
                              style: TextStyle(
                                fontFamily: MlTokens.fontSans,
                                fontWeight: FontWeight.w600,
                                color: semantic.textStrong,
                              ),
                            ),
                            subtitle: Text(
                              log.description,
                              style: TextStyle(
                                fontFamily: MlTokens.fontSans,
                                color: semantic.textMuted,
                              ),
                            ),
                            trailing: Text(
                              DateFormat('yyyy-MM-dd HH:mm:ss').format(MlTime.sast(log.createdAt)),
                              style: context.mlText.code(
                                color: semantic.textFaint,
                                size: 12,
                                weight: FontWeight.w400,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
