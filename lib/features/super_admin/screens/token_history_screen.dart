import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/super_admin/data/models/models.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
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
                        style: TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: semantic.textStrong,
                        ),
                      ),
                      subtitle: Text(
                        '${entries.length} events · org $oid',
                        style: TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontSize: 12.5,
                          color: semantic.textMuted,
                        ),
                      ),
                      children: [
                        for (final log in entries)
                          ListTile(
                            dense: true,
                            title: Text(
                              log.actionType,
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
                              style: TextStyle(
                                fontFamily: MlTokens.fontMono,
                                fontSize: 11.5,
                                color: semantic.textFaint,
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
