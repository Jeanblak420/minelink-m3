import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/chat/models/messaging_models.dart';
import 'package:flutter_application_1/features/chat/providers/messaging_providers.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/super_admin/data/models/business_pair.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_link_builder.dart';
import 'package:flutter_application_1/features/super_admin/widgets/company_name_link.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Super-admin screen for manually linking companies in chat. Linking is 100%
/// manual (auto-linking was removed 2026-07-14). Four sections: the two-sided
/// grouped Connect builder, request-driven Recommendations, the live Connected
/// list, and revoked History.
class ChatConnectionsScreen extends ConsumerStatefulWidget {
  const ChatConnectionsScreen({super.key});

  @override
  ConsumerState<ChatConnectionsScreen> createState() =>
      _ChatConnectionsScreenState();
}

class _ChatConnectionsScreenState extends ConsumerState<ChatConnectionsScreen> {
  bool _busy = false;

  Future<void> _grant(String a, String b, String okMsg) => _run(
    () => ref.read(messagingServiceProvider).grantConnection(a, b),
    okMsg,
  );

  Future<void> _revoke(OrgConnection conn, String aName, String bName) async {
    // Resolved before the confirm dialog: `ref` throws once this screen is
    // gone, and a dialog can outlive it.
    final messaging = ref.read(messagingServiceProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke chat link'),
        content: Text(
          '$aName and $bName will no longer see each other in chat, and existing '
          'conversations between them become unavailable. You can grant the link again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke link'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => messaging.revokeConnection(conn.id),
      'Chat link revoked.',
    );
  }

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    // Callers reach here after a confirm-dialog await, and `setState` on a
    // disposed State throws just as `ref` does.
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await action();
      ref.invalidateIfMounted(orgConnectionsProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(okMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final companies = ref.watch(organizationsProvider).valueOrNull ?? const [];
    final connectionsAsync = ref.watch(orgConnectionsProvider);
    final pairsAsync = ref.watch(businessPairsProvider);

    final nameById = <String, String>{
      for (final c in companies)
        (c['id'] as String):
            (c['company_name'] as String?)?.trim().isNotEmpty == true
            ? c['company_name'] as String
            : 'Unknown company',
    };
    final orgTypeById = <String, String?>{
      for (final c in companies) (c['id'] as String): c['org_type'] as String?,
    };
    String nameOf(String id) =>
        nameById[id] ?? 'Company ${id.length >= 6 ? id.substring(0, 6) : id}';

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(connectionsAsync),
          const SizedBox(height: 16),
          // 1. Connect builder.
          _sectionTitle(semantic, 'Connect two companies'),
          const SizedBox(height: 10),
          if (companies.length < 2)
            _hintCard(
              semantic,
              'Add at least two companies to create a chat link.',
            )
          else
            CompanyLinkBuilder(companies: companies),
          const SizedBox(height: 28),
          // 2. Recommendations from accepted requests.
          _sectionTitle(semantic, 'Recommended from accepted requests'),
          const SizedBox(height: 4),
          Text(
            'Companies tied together by an accepted request or transaction. They are '
            'NOT linked automatically — review and connect the ones you want.',
            style: context.mlText.bodyMedium.copyWith(color: semantic.textFaint),
          ),
          const SizedBox(height: 10),
          _recommendations(
            semantic,
            pairsAsync,
            connectionsAsync.valueOrNull ?? const [],
            nameOf,
            orgTypeById,
          ),
          const SizedBox(height: 28),
          // 3 + 4. Connected + History.
          connectionsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => MlEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load chat links',
              message: friendlyError(e),
            ),
            data: (connections) => _connectedAndHistory(
              semantic,
              connections,
              nameOf,
              orgTypeById,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _header(AsyncValue<List<dynamic>> connectionsAsync) => MlPageHeader(
    title: 'Company chat links',
    meta: connectionsAsync.valueOrNull == null
        ? null
        : mlCount(connectionsAsync.value!.length, 'link'),
    description:
        'Manually connect two companies so their people can message each '
        'other in MineLink Messenger. Company names link to their profiles.',
    actions: [
      IconButton(
        tooltip: 'Refresh',
        onPressed: () {
          ref.invalidate(orgConnectionsProvider);
          ref.invalidate(businessPairsProvider);
        },
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );

  // The reference's section heading — Fraunces, as MlSectionTitle draws it
  // — not 16px sans bold. The four section headings on this screen all go
  // through here. Phase 3 pass, 2026-08-23.
  Widget _sectionTitle(MlSemantic semantic, String text) => Text(
    text,
    style: context.mlText.editorialMedium.copyWith(
      color: semantic.textStrong,
    ),
  );

  Widget _hintCard(MlSemantic semantic, String message) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: semantic.surfaceCard,
      borderRadius: BorderRadius.circular(MlTokens.rXl),
      border: Border.all(color: semantic.borderCard),
    ),
    child: Text(
      message,
      style: context.mlText.bodyMedium.copyWith(color: semantic.textFaint),
    ),
  );

  Widget _recommendations(
    MlSemantic semantic,
    AsyncValue<List<BusinessPair>> pairsAsync,
    List<OrgConnection> connections,
    String Function(String) nameOf,
    Map<String, String?> orgTypeById,
  ) {
    final connectedKeys = {
      for (final c in connections.where((c) => !c.isRevoked))
        '${c.companyLowId}|${c.companyHighId}',
    };
    return pairsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _hintCard(
        semantic,
        'Could not load recommendations. ${friendlyError(e)}',
      ),
      data: (pairs) {
        final open = pairs
            .where((p) => !connectedKeys.contains(p.key))
            .toList();
        if (open.isEmpty) {
          return _hintCard(
            semantic,
            'No new recommendations — every business pair is already connected or none exist yet.',
          );
        }
        return Column(
          children: [
            for (final p in open) ...[
              _RecommendationCard(
                semantic: semantic,
                pair: p,
                aName: nameOf(p.companyIdA),
                bName: nameOf(p.companyIdB),
                aType: companyOrgTypeLabel(orgTypeById[p.companyIdA]),
                bType: companyOrgTypeLabel(orgTypeById[p.companyIdB]),
                busy: _busy,
                onConnect: () => _grant(
                  p.companyIdA,
                  p.companyIdB,
                  '${nameOf(p.companyIdA)} and ${nameOf(p.companyIdB)} are now connected in chat.',
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _connectedAndHistory(
    MlSemantic semantic,
    List<OrgConnection> connections,
    String Function(String) nameOf,
    Map<String, String?> orgTypeById,
  ) {
    final active = connections.where((c) => !c.isRevoked).toList()
      ..sort(
        (a, b) => nameOf(
          a.companyLowId,
        ).toLowerCase().compareTo(nameOf(b.companyLowId).toLowerCase()),
      );
    final revoked = connections.where((c) => c.isRevoked).toList()
      ..sort(
        (a, b) =>
            (b.revokedAt ?? DateTime(0)).compareTo(a.revokedAt ?? DateTime(0)),
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(semantic, 'Connected  ·  ${active.length}'),
        const SizedBox(height: 10),
        if (active.isEmpty)
          _hintCard(
            semantic,
            'No active chat links yet. Connect two companies above.',
          )
        else
          for (final conn in active) ...[
            _ConnectionCard(
              semantic: semantic,
              conn: conn,
              revoked: false,
              busy: _busy,
              aId: conn.companyLowId,
              bId: conn.companyHighId,
              aName: nameOf(conn.companyLowId),
              bName: nameOf(conn.companyHighId),
              aType: companyOrgTypeLabel(orgTypeById[conn.companyLowId]),
              bType: companyOrgTypeLabel(orgTypeById[conn.companyHighId]),
              onAction: () => _revoke(
                conn,
                nameOf(conn.companyLowId),
                nameOf(conn.companyHighId),
              ),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 24),
        _sectionTitle(semantic, 'History — revoked  ·  ${revoked.length}'),
        const SizedBox(height: 10),
        if (revoked.isEmpty)
          _hintCard(semantic, 'No revoked links.')
        else
          for (final conn in revoked) ...[
            _ConnectionCard(
              semantic: semantic,
              conn: conn,
              revoked: true,
              busy: _busy,
              aId: conn.companyLowId,
              bId: conn.companyHighId,
              aName: nameOf(conn.companyLowId),
              bName: nameOf(conn.companyHighId),
              aType: companyOrgTypeLabel(orgTypeById[conn.companyLowId]),
              bType: companyOrgTypeLabel(orgTypeById[conn.companyHighId]),
              onAction: () => _grant(
                conn.companyLowId,
                conn.companyHighId,
                'Chat link granted again.',
              ),
            ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final MlSemantic semantic;
  final BusinessPair pair;
  final String aName, bName, aType, bType;
  final bool busy;
  final VoidCallback onConnect;

  const _RecommendationCard({
    required this.semantic,
    required this.pair,
    required this.aName,
    required this.bName,
    required this.aType,
    required this.bType,
    required this.busy,
    required this.onConnect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rXl),
        border: Border.all(color: semantic.borderCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Wrapped for the same reason as `_ConnectionCard` below: two
          // `Flexible`s share a row equally, so the longer company name is cut
          // to the shorter one's width even when the row has space to spare.
          Wrap(
            spacing: 8,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              CompanyNameLink(companyId: pair.companyIdA, name: aName),
              Icon(
                Icons.sync_alt_rounded,
                size: 16,
                color: semantic.textFaint,
              ),
              CompanyNameLink(companyId: pair.companyIdB, name: bName),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$aType  ·  $bType',
            style: context.mlText.bodyMedium.copyWith(color: semantic.textFaint),
          ),
          const SizedBox(height: 6),
          Text(
            pair.reason,
            style: context.mlText.bodyMedium.copyWith(
              color: semantic.textStrong,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tied together ${MlTime.stamp(pair.date)}',
            style: context.mlText.bodySmall.copyWith(color: semantic.textFaint),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: MlButton.primary(
              label: 'Connect via MineLink Messenger',
              icon: Icons.link_rounded,
              compact: true,
              onPressed: busy ? null : onConnect,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  final MlSemantic semantic;
  final OrgConnection conn;
  final bool revoked;
  final String aId, bId, aName, bName, aType, bType;
  final bool busy;
  final VoidCallback onAction;

  const _ConnectionCard({
    required this.semantic,
    required this.conn,
    required this.revoked,
    required this.aId,
    required this.bId,
    required this.aName,
    required this.bName,
    required this.aType,
    required this.bType,
    required this.busy,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final when = revoked ? conn.revokedAt : conn.grantedAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rXl),
        border: Border.all(color: semantic.borderCard),
      ),
      child: Builder(
        builder: (context) {
          // The two company names, side by side when they fit and wrapped when
          // they do not. Two `Flexible`s in a Row split whatever is left
          // EQUALLY: on a 412px phone the badge and the Revoke button took
          // 254px of the card, and each half of "Iron Hills Mining ⇄ Atlas
          // Buyer Group" was drawn in 43px — "Iron…" ⇄ "Atla…". A chat link is
          // between two named companies; if it cannot say which two, the row
          // says nothing at all.
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  CompanyNameLink(companyId: aId, name: aName),
                  Icon(
                    Icons.sync_alt_rounded,
                    size: 16,
                    color: semantic.textFaint,
                  ),
                  CompanyNameLink(companyId: bId, name: bName),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$aType  ·  $bType'
                '${when != null ? '  ·  ${revoked ? 'Revoked' : 'Linked'} ${MlTime.stamp(when)}' : ''}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.mlText.bodyMedium.copyWith(
                  color: semantic.textFaint,
                ),
              ),
            ],
          );
          final badge = MlStatusBadge(
            label: revoked ? 'Revoked' : 'Connected',
            tone: revoked ? MlTone.error : MlTone.done,
          );
          final action = revoked
              ? MlButton.primary(
                  label: 'Grant again',
                  icon: Icons.link_rounded,
                  compact: true,
                  onPressed: busy ? null : onAction,
                )
              : MlButton.danger(
                  label: 'Revoke',
                  icon: Icons.link_off_rounded,
                  compact: true,
                  onPressed: busy ? null : onAction,
                );

          return LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 560) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    identity,
                    const SizedBox(height: 12),
                    Wrap(spacing: 10, runSpacing: 8, children: [badge, action]),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 12),
                  badge,
                  const SizedBox(width: 10),
                  action,
                ],
              );
            },
          );
        },
      ),
    );
  }
}
