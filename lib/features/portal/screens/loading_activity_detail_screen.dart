import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/portal/portal_colors.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/utils/mine_supplier_overview_metrics.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/features/portal/models/trip_status.dart';
import 'package:flutter_application_1/features/portal/utils/trip_status_tone.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// Full loading-activity view: the same incoming / scheduled signal as the
/// overview tile, expanded into per-trip detail. Reachable from the overview
/// and the supervisor view.
class LoadingActivityDetailScreen extends ConsumerWidget {
  const LoadingActivityDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Loading activity'),
        backgroundColor: MlSemantic.of(context).surfaceApp,
        foregroundColor: MlSemantic.of(context).textStrong,
      ),
      body: companyId == null
          ? const PortalCompanyRequired()
          : ref.watch(logisticsSnapshotProvider(companyId)).when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => MlLoadFailure(
                    subject: 'the loading activity',
                    error: e,
                    onRetry: () => ref.invalidate(logisticsSnapshotProvider(companyId)),
                ),
                data: (snap) {
                  final now = MlTime.now();
                  final incoming =
                      MineSupplierOverviewMetrics.incomingTrucks(snap.trips);
                  final scheduled = MineSupplierOverviewMetrics.scheduledToday(
                      snap.trips,
                      now: now);
                  final trips = snap.trips;

                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _SummaryCard(
                                    icon: Icons.login_rounded,
                                    label: 'Incoming trucks',
                                    value: '$incoming',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SummaryCard(
                                    icon: Icons.event_available_outlined,
                                    label: 'Scheduled today',
                                    value: '$scheduled',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            // The screen promises "incoming and scheduled
                            // trucks" and was listing EVERY trip, completed
                            // ones included (P8-24). Inbound is anything not
                            // yet loaded and not finished -- the trucks a mine
                            // floor actually has to plan for.
                            Builder(builder: (context) {
                              final inbound = [
                                for (final t in trips)
                                  if (_isInbound(t)) t,
                              ]..sort((a, b) => TripStatus.parse(a.status)
                                  .step
                                  .compareTo(TripStatus.parse(b.status).step));
                              const cap = 50;
                              final shown =
                                  inbound.length < cap ? inbound.length : cap;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Incoming & scheduled',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                      // Say so when the list is truncated. A
                                      // silent cap reads as "this is all of
                                      // them".
                                      Text(
                                        shown == inbound.length
                                            ? '${inbound.length} truck'
                                                '${inbound.length == 1 ? '' : 's'}'
                                            : 'Showing $shown of '
                                                '${inbound.length}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (inbound.isEmpty)
                                    _EmptyTrips()
                                  else
                                    _TripsList(count: shown, trips: inbound),
                                ],
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _SummaryCard(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MlSemantic.of(context).surfaceCard,
            Color.alphaBlend(
                PortalColors.accent.withValues(alpha: 0.16), scheme.surface),
          ],
        ),
        borderRadius: MlShape.radiusLarge,
        border: Border.all(color: MlSemantic.of(context).borderCard),
      ),
      child: Row(
        children: [
          Icon(icon, color: PortalColors.accent, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: MlType.figure(
                        color: scheme.onSurface, size: MlTokens.fsH1)),
                Text(label,
                    style: textTheme.bodyMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TripsList extends StatelessWidget {
  final int count;
  final List trips;
  const _TripsList({required this.count, required this.trips});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: MlShape.radiusLarge,
        border: Border.all(color: MlSemantic.of(context).borderCard),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final t = trips[i];
          final status = TripStatus.parse(t.status as String);
          final reg = t.truckReg as String?;
          final net = t.netTons as double?;
          return ListTile(
            leading: Icon(Icons.local_shipping_outlined,
                color: PortalColors.accent),
            // The truck, because that is what a gate is looking for. The raw
            // wire string with its underscores swapped for spaces is not a
            // label -- `TripStatus` owns the human-readable one (P8-24).
            title: Text(reg ?? 'Truck not yet assigned'),
            subtitle: Text(
              [
                status.label,
                if (net != null) '${net.toStringAsFixed(2)} t',
                'updated ${MlTime.day(t.updatedAt)}',
              ].join(' · '),
            ),
            trailing: MlStatusBadge(
              label: status.label,
              tone: tripStatusTone(status),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyTrips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      decoration: BoxDecoration(
        color: MlSemantic.of(context).surfaceCard,
        borderRadius: MlShape.radiusLarge,
        border: Border.all(color: MlSemantic.of(context).borderCard),
      ),
      child: Column(
        children: [
          Icon(Icons.local_shipping_outlined,
              size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text('No loading activity yet.',
              style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// A truck the mine floor still has to deal with: on its way, at the gate, or
/// on the weighbridge. Excludes anything loaded or finished — the fault in
/// P8-24 was listing completed trips under "incoming and scheduled".
bool _isInbound(dynamic trip) {
  final status = TripStatus.parse(trip.status as String);
  return status.step < TripStatus.loaded.step &&
      status != TripStatus.cancelled;
}
