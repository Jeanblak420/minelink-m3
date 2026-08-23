import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/data/models/models.dart';
import 'package:flutter_application_1/features/super_admin/utils/audit_log_csv_exporter.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

// AuditLogExporter & ExportFormat are in the same file via audit_log_csv_exporter.dart

/// Full audit log viewer with filtering by action type and CSV export
class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  String? _selectedActionType;

  static const List<String> _actionTypes = [
    'All',
    'TOKEN_GENERATED',
    'TOKEN_REVOKED',
    'TOKEN_EXPIRED',
    'TOKEN_REQUEST_SUBMITTED',
    'TOKEN_REQUEST_CLAIMED',
    'TOKEN_REQUEST_RELEASED',
    'TOKEN_REQUEST_APPROVED',
    'TOKEN_REQUEST_REJECTED',
    'COMPANY_SUSPENDED',
    'COMPANY_REACTIVATED',
    'SEAT_REQUEST_APPROVED',
    'SEAT_REQUEST_REJECTED',
    'SEAT_LIMIT_UPDATED',
    'SEAT_RELEASED',
    'USER_SUSPENDED',
    'USER_REACTIVATED',
    'USER_ROLE_CHANGED',
  ];

  @override
  Widget build(BuildContext context) {
    final filters = _selectedActionType != null && _selectedActionType != 'All'
        ? {'actionType': _selectedActionType}
        : null;
    final logsAsync = ref.watch(auditLogsProvider(filters));
    final canExport = ref.watch(superAdminCanExportDownloadsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The shared page header, not a hand-rolled title: 'Audit Logs' was
        // 16px PlusJakartaSans ExtraBold (and title-cased, against the app
        // bar's 'Audit logs'), with a bare download icon beside it and no
        // description or count — while every other console screen opens in
        // the Fraunces display face through MlPageHeader. Found 2026-08-23
        // in the Phase 3 pass.
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: MlPageHeader(
            title: 'Audit logs',
            description:
                'Who did what, and when — every administrative action on the '
                'platform, newest first.',
            meta: logsAsync.valueOrNull == null
                ? null
                : mlCount(logsAsync.value!.length, 'entry', 'entries'),
            padding: EdgeInsets.zero,
            actions: [
              if (canExport)
                logsAsync.maybeWhen(
                  data: (logs) => MlButton.outline(
                    label: 'Export',
                    icon: Icons.download_outlined,
                    compact: true,
                    onPressed: () =>
                        AuditLogExporter.pickFormatAndExport(context, logs),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            children: _actionTypes.map((type) {
              final isSelected =
                  type == 'All' ? _selectedActionType == null || _selectedActionType == 'All' : _selectedActionType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(
                      type == 'All'
                          ? 'All'
                          : AuditLog.labelForAction(type),
                      style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedActionType = type;
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => MlEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load logs',
              message: friendlyError(e),
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return const MlEmptyState(
                  icon: Icons.history_toggle_off,
                  title: 'No audit logs found',
                  message: 'No activity matches the selected filter.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                itemCount: logs.length,
                itemBuilder: (context, i) => _AuditLogCard(log: logs[i]),
              );
            },
          ),
        ),
      ],
    );
  }

}


class _AuditLogCard extends StatelessWidget {
  final AuditLog log;
  const _AuditLogCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final tone = _actionTone(log.actionType);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MlCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MlIconWell(
              icon: _actionIcon(log.actionType),
              tone: tone,
              size: 40,
              radius: 11,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // THE BADGE MOVES, THE ENTRY DOES NOT.
                  //
                  // As one Row the badge was unflexed, so it took its natural
                  // width from an unbounded constraint (CLAUDE.md §10.4) and
                  // "COMPANY SUSPENDED" ran **20px past the card** at 412px —
                  // while what was left of the description read "Suspended for
                  // non-payment; t…". Two lines of a 312px column against a
                  // 165px tag repeating what the icon and its colour already
                  // say.
                  //
                  // The description IS the audit entry; the action type is
                  // also the icon, also its tone, and also a filter pill at the
                  // top of the screen. So below 380 — the width the pair needs
                  // before either has to give — the tag becomes a kicker on its
                  // own line and the sentence gets the full column.
                  LayoutBuilder(
                    builder: (context, box) {
                      final badge = MlStatusBadge(
                        label: log.actionLabel,
                        tone: tone,
                      );
                      final description = Text(
                        log.description,
                        style: TextStyle(
                          fontFamily: MlTokens.fontSans,
                          fontWeight: FontWeight.w600,
                          color: semantic.textStrong,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      );
                      if (box.maxWidth < 380) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            badge,
                            const SizedBox(height: 7),
                            description,
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: description),
                          const SizedBox(width: 8),
                          badge,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 13, color: semantic.textFaint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          log.actorEmail,
                          style: context.mlText.bodySmall.copyWith(
                            color: semantic.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _timeAgo(log.createdAt),
                        style: context.mlText.code(
                          color: semantic.textFaint,
                          size: 11,
                          weight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  if (log.organizationName != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.business_outlined, size: 13, color: semantic.textFaint),
                        const SizedBox(width: 4),
                        // Unflexed, this took unbounded width from the Row and
                        // "Consolidated Mineral Offtake & Logistics Holdings"
                        // simply ran off the card — no ellipsis, because an
                        // ellipsis needs a bound to engage against.
                        Expanded(
                          child: Text(
                            log.organizationName!,
                            // TWO lines: the audit trail's whole job is to say
                            // WHO did what to WHICH company, and at one line
                            // the longest company on the platform read
                            // "Consolidated Mineral Offtake & Logistics Hol…"
                            // in a 285px card.
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.mlText.bodySmall.copyWith(
                              color: semantic.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  IconData _actionIcon(String action) {
    if (action.contains('TOKEN')) return Icons.vpn_key_rounded;
    if (action.contains('SEAT')) return Icons.event_seat_rounded;
    if (action.contains('COMPANY') || action.contains('ORGANIZATION')) return Icons.business_rounded;
    return Icons.history_rounded;
  }

  MlTone _actionTone(String action) {
    if (action.contains('REVOKED') || action.contains('REJECTED') || action.contains('SUSPENDED')) {
      return MlTone.error;
    }
    if (action.contains('APPROVED') || action.contains('GENERATED') || action.contains('CREATED') ||
        action.contains('REACTIVATED')) {
      return MlTone.done;
    }
    if (action.contains('EXPIRED')) return MlTone.warn;
    if (action.contains('UPDATED')) return MlTone.transit;
    return MlTone.neutral;
  }

  // One vocabulary, one clock. This used to subtract from `DateTime.now()`,
  // so an entry written twenty-two minutes ago printed "5d ago" whenever the
  // device disagreed with the data — on the screen whose entire job is saying
  // when something happened.
  String _timeAgo(DateTime dt) => MlTime.ago(dt);
}
