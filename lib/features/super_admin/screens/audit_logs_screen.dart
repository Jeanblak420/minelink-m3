import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/features/super_admin/data/models/models.dart';
import 'package:flutter_application_1/features/super_admin/utils/audit_log_csv_exporter.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

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

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Audit Logs',
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: MlTokens.fsH3,
                      fontWeight: FontWeight.w800,
                      color: MlSemantic.of(context).textStrong,
                    ),
                  ),
                ),
                if (canExport)
                  logsAsync.when(
                    data: (logs) => IconButton(
                      icon: const Icon(Icons.download_rounded),
                      tooltip: 'Export Logs',
                      onPressed: () => AuditLogExporter.pickFormatAndExport(context, logs),
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: _actionTypes.map((type) {
                final isSelected =
                    type == 'All' ? _selectedActionType == null || _selectedActionType == 'All' : _selectedActionType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(type == 'All' ? 'All' : _formatLabel(type), style: const TextStyle(fontSize: 12)),
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
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, i) => _AuditLogCard(log: logs[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatLabel(String actionType) {
    return actionType
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          log.description,
                          style: TextStyle(
                            fontFamily: MlTokens.fontSans,
                            fontWeight: FontWeight.w600,
                            color: semantic.textStrong,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      MlStatusBadge(label: _formatLabel(log.actionType), tone: tone),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.person_outline, size: 13, color: semantic.textFaint),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          log.actorEmail,
                          style: TextStyle(fontFamily: MlTokens.fontSans, fontSize: 12, color: semantic.textMuted),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _timeAgo(log.createdAt),
                        style: TextStyle(fontFamily: MlTokens.fontMono, fontSize: 11, color: semantic.textFaint),
                      ),
                    ],
                  ),
                  if (log.organizationName != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.business_outlined, size: 13, color: semantic.textFaint),
                        const SizedBox(width: 4),
                        Text(
                          log.organizationName!,
                          style: TextStyle(fontFamily: MlTokens.fontSans, fontSize: 12, color: semantic.textMuted),
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

  String _formatLabel(String actionType) {
    return actionType
        .split('_')
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
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

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
