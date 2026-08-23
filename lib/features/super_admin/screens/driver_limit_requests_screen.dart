import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/safe_ref.dart';
import 'package:flutter_application_1/features/fleet/models/vehicle_driver.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Super-admin-only: every transporter request to raise a truck's driver
/// limit (RLS-gated by list_driver_limit_requests).
final driverLimitRequestsProvider =
    FutureProvider.autoDispose<List<DriverLimitRequest>>((ref) async {
      final rows = await SupabaseConfig.client.rpc(
        'list_driver_limit_requests',
      );
      return (rows as List)
          .map((e) => DriverLimitRequest.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });

/// Driver-limit requests — transporters ask to put more than 2 drivers on a
/// truck (long-distance crews); the super-admin approves up to a hard max of
/// 5 (CLAUDE.md §4 driver-per-truck rule).
class DriverLimitRequestsScreen extends ConsumerStatefulWidget {
  const DriverLimitRequestsScreen({super.key});

  @override
  ConsumerState<DriverLimitRequestsScreen> createState() =>
      _DriverLimitRequestsScreenState();
}

class _DriverLimitRequestsScreenState
    extends ConsumerState<DriverLimitRequestsScreen> {
  bool _busy = false;

  Future<void> _decide(DriverLimitRequest r, bool approve) async {
    setState(() => _busy = true);
    try {
      await SupabaseConfig.client.rpc(
        'decide_driver_limit_request',
        params: {'p_id': r.id, 'p_approve': approve},
      );
      ref.invalidateIfMounted(driverLimitRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? '${r.registration} may now carry up to ${mlCount(r.requestedLimit, 'driver')}.'
                  : 'Request for ${r.registration} declined.',
            ),
          ),
        );
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
    final async = ref.watch(driverLimitRequestsProvider);

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Transporter driver limits',
            meta: async.valueOrNull == null
                ? null
                : mlCount(async.value!.length, 'request'),
            description:
                'Transporter requests to put more than 2 drivers on a '
                'truck. You can approve up to a maximum of 5.',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(driverLimitRequestsProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => MlEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load requests',
              message: friendlyError(e),
            ),
            data: (requests) {
              if (requests.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 44),
                  decoration: BoxDecoration(
                    color: semantic.surfaceCard,
                    borderRadius: BorderRadius.circular(MlTokens.rXl),
                    border: Border.all(color: semantic.borderCard),
                  ),
                  child: const MlEmptyState(
                    icon: Icons.groups_outlined,
                    title: 'No driver-limit requests',
                    message:
                        'When a transporter asks to add more drivers to a '
                        'truck, the request appears here.',
                  ),
                );
              }
              return Column(
                children: [
                  for (final r in requests) ...[
                    _RequestCard(
                      request: r,
                      busy: _busy,
                      onApprove: () => _decide(r, true),
                      onDecline: () => _decide(r, false),
                    ),
                    const SizedBox(height: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final DriverLimitRequest request;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onDecline;

  const _RequestCard({
    required this.request,
    required this.busy,
    required this.onApprove,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final r = request;
    final tone = switch (r.status) {
      'approved' => MlTone.done,
      'declined' => MlTone.error,
      _ => MlTone.atMine,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rXl),
        border: Border.all(color: semantic.borderCard),
      ),
      child: Builder(builder: (context) {
        // Identity on the left, the decision on the right — the reference's
        // placement for a row's actions (§4). These all rode in one Wrap, so
        // Approve / Decline and the status pill floated mid-row wherever the
        // text happened to end. Found 2026-08-23 in the Phase 3 pass. Under
        // 820px the trailing block drops under the identity.
        final identity = Wrap(
          spacing: 20,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            MlPlatePill(r.registration, fontSize: 13),
            Text(
              r.companyName ?? '—',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: semantic.textStrong,
              ),
            ),
            Text(
              '${r.currentLimit} → ${mlCount(r.requestedLimit, 'driver')}',
              style: TextStyle(
                fontFamily: MlTokens.fontMono,
                fontWeight: FontWeight.w700,
                color: semantic.textStrong,
              ),
            ),
            Text(
              // No name means DROP the clause, not print "by —". An em dash
              // in a table cell reads as "we do not know this"; in the
              // middle of a sentence it reads as a mistake. The timestamp
              // still stands on its own.
              r.requestedByName == null
                  ? MlTime.stamp(r.createdAt)
                  : 'by ${r.requestedByName} · ${MlTime.stamp(r.createdAt)}',
              style:
                  context.mlText.bodyMedium.copyWith(color: semantic.textFaint),
            ),
          ],
        );
        final wide = MediaQuery.sizeOf(context).width >= 820;
        final trailing = Wrap(
          alignment: wide ? WrapAlignment.end : WrapAlignment.start,
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (r.isPending) ...[
              MlButton.go(
                label: 'Approve',
                icon: Icons.check_rounded,
                compact: true,
                onPressed: busy ? null : onApprove,
              ),
              MlButton.danger(
                label: 'Decline',
                icon: Icons.close_rounded,
                compact: true,
                onPressed: busy ? null : onDecline,
              ),
            ] else
              MlStatusBadge(
                label: r.status == 'approved' ? 'Approved' : 'Declined',
                tone: tone,
              ),
          ],
        );
        if (wide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: identity),
              const SizedBox(width: 12),
              trailing,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            identity,
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: trailing),
          ],
        );
      }),
    );
  }
}
