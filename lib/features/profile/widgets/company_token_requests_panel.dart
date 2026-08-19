import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/layout/app_breakpoints.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Company CEO / owner: request seat expansion or token renewal from the platform team.
class CompanyTokenRequestsPanel extends ConsumerWidget {
  final String companyId;

  const CompanyTokenRequestsPanel({super.key, required this.companyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Platform requests',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Request additional user seats, renew your access token before it expires, or request a new token if access has lapsed.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final stackVertically = constraints.maxWidth < AppBreakpoints.dashboardWideMin;
                final actions = [
                  _RequestAction(
                    icon: Icons.group_add_outlined,
                    label: 'Request more seats',
                    onPressed: () => _seatExpansion(context, ref),
                  ),
                  _RequestAction(
                    icon: Icons.autorenew,
                    label: 'Renew token',
                    onPressed: () => _tokenRenewal(context, ref),
                  ),
                  _RequestAction(
                    icon: Icons.vpn_key_outlined,
                    label: 'Request new token',
                    onPressed: () => _newToken(context, ref),
                  ),
                ];
                if (stackVertically) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) const SizedBox(height: 8),
                        actions[i].buildButton(context, expand: true),
                      ],
                    ],
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [for (final a in actions) a.buildButton(context)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _seatExpansion(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(superAdminRepositoryProvider);
    final extra = TextEditingController(text: '5');
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
        title: const Text('Request more seats'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: extra,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Additional seats'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Reason (optional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    final ex = int.tryParse(extra.text.trim()) ?? 0;
    if (ex <= 0) return;
    try {
      final snap = await repo.getCompanySeatSnapshotForRequests(companyId);
      final limit = snap['seat_limit'] as int? ?? 0;
      await repo.createCompanyTokenRequest(
        organizationId: companyId,
        requestKind: 'seat_expansion',
        reason: reason.text,
        requestedExtraSeats: ex,
        requestedNewTotal: limit + ex,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seat request submitted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _tokenRenewal(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(superAdminRepositoryProvider);
    final days = TextEditingController(text: '30');
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
      // Cold-phone audit 2026-08-18: this dialog holds input fields and did
      // not scroll, so at a large text size on a narrow phone its content
      // overflowed the viewport and the fields below the fold could not be
      // reached. Measured at 133px of clipped content on the token
      // generator, which is the same shape. `scrollable` only engages when
      // the content exceeds the space, so it is inert on a desktop.
      scrollable: true,
        title: const Text('Renew access token'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: days,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Requested validity (days)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    final d = int.tryParse(days.text.trim());
    if (d == null || d <= 0) return;
    try {
      final snap = await repo.getCompanySeatSnapshotForRequests(companyId);
      final limit = snap['seat_limit'] as int? ?? 0;
      final tokenId = snap['current_token_id'] as String?;
      await repo.createCompanyTokenRequest(
        organizationId: companyId,
        requestKind: 'token_renewal',
        reason: reason.text,
        requestedNewTotal: limit,
        requestedValidDays: d,
        currentTokenId: tokenId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renewal request submitted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _newToken(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(superAdminRepositoryProvider);
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request new token'),
        content: TextField(
          controller: reason,
          decoration: const InputDecoration(labelText: 'Context (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final snap = await repo.getCompanySeatSnapshotForRequests(companyId);
      final limit = snap['seat_limit'] as int? ?? 0;
      final tokenId = snap['current_token_id'] as String?;
      await repo.createCompanyTokenRequest(
        organizationId: companyId,
        requestKind: 'new_token',
        reason: reason.text,
        requestedNewTotal: limit,
        currentTokenId: tokenId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New token request submitted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }
}

class _RequestAction {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _RequestAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  Widget buildButton(BuildContext context, {bool expand = false}) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
    if (!expand) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}
