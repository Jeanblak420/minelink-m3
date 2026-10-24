import 'package:flutter_application_1/core/design/tokens/m3/ml_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// One marketplace row: a route a transporter accepted, with delivery stats
/// (`list_route_marketplace`).
class MarketplaceRoute {
  final String routeId;
  final String routeNumber;
  final String? commodity;
  final String? loadingPoint;
  final String? offloadingPoint;
  final String? transporterName;
  final DateTime acceptedAt;
  final int tripsTotal;
  final int tripsCompleted;
  final double tonsDelivered;

  const MarketplaceRoute({
    required this.routeId,
    required this.routeNumber,
    required this.acceptedAt,
    required this.tripsTotal,
    required this.tripsCompleted,
    required this.tonsDelivered,
    this.commodity,
    this.loadingPoint,
    this.offloadingPoint,
    this.transporterName,
  });

  String get routeLabel => '${loadingPoint ?? '—'} → ${offloadingPoint ?? '—'}';

  static String? _s(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  factory MarketplaceRoute.fromJson(Map<String, dynamic> j) => MarketplaceRoute(
    routeId: j['route_id'] as String,
    routeNumber: (j['route_number'] as String?) ?? '—',
    commodity: _s(j['commodity']),
    loadingPoint: _s(j['loading_point']),
    offloadingPoint: _s(j['offloading_point']),
    transporterName: _s(j['transporter_name']),
    acceptedAt: DateTime.parse(j['accepted_at'] as String),
    tripsTotal: (j['trips_total'] as num?)?.toInt() ?? 0,
    tripsCompleted: (j['trips_completed'] as num?)?.toInt() ?? 0,
    tonsDelivered: (j['tons_delivered'] as num?)?.toDouble() ?? 0,
  );
}

final routeMarketplaceProvider =
    FutureProvider.autoDispose<List<MarketplaceRoute>>((ref) async {
      final rows = await SupabaseConfig.client.rpc('list_route_marketplace');
      return (rows as List)
          .map((e) => MarketplaceRoute.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    });

/// Transporter route marketplace (CLAUDE.md §4) — every route each
/// transporter runs, with completion stats. SUPER-ADMIN ONLY for now; the
/// banner states it will become public once the developer implements that,
/// at which point requesters will browse each transporter's proven routes.
class RouteMarketplaceScreen extends ConsumerWidget {
  const RouteMarketplaceScreen({super.key});

  static final _dateFmt = DateFormat('dd MMM yyyy');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final semantic = MlSemantic.of(context);
    final async = ref.watch(routeMarketplaceProvider);

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlPageHeader(
            title: 'Route marketplace',
            meta: async.valueOrNull == null
                ? null
                : mlCount(async.value!.length, 'route'),
            description:
                'All routes every transporter runs, with their delivery '
                'record.',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(routeMarketplaceProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // §4: keep super-admin-gated until made public — say so in the UI.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MlTone.atMine.colors(Theme.of(context).brightness).bg,
              borderRadius: MlShape.radiusMedium,
            ),
            child: Text(
              'Visible to you only for now. This marketplace will become '
              'public in a later release — requesters will then browse the '
              'routes each transporter offers and has successfully completed.',
              style: context.mlText.titleSmall.copyWith(
                color: MlTone.atMine.colors(Theme.of(context).brightness).fg,
              ),
            ),
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => MlEmptyState(
              icon: Icons.error_outline,
              title: 'Could not load the marketplace',
              message: friendlyError(e),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 44),
                  decoration: BoxDecoration(
                    color: semantic.surfaceCard,
                    borderRadius: BorderRadius.circular(MlTokens.rXl),
                    border: Border.all(color: semantic.borderCard),
                  ),
                  child: const MlEmptyState(
                    icon: Icons.storefront_outlined,
                    title: 'No accepted routes yet',
                    message:
                        'Rows appear once transporters accept dispatched '
                        'routes and start running them.',
                  ),
                );
              }
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: semantic.surfaceCard,
                  borderRadius: BorderRadius.circular(MlTokens.rXl),
                  border: Border.all(color: semantic.borderCard),
                  boxShadow: MlTokens.shadowSm,
                ),
                child: MlDataTable(
                  cardsOnPhone: true,
                  columns: const [
                    MlColumn('Route ID', flex: 2),
                    MlColumn('Route', flex: 4),
                    MlColumn('Product', flex: 2),
                    MlColumn('Transporter', flex: 3),
                    MlColumn('Accepted', flex: 2),
                    MlColumn('Trips', flex: 1, align: TextAlign.right),
                    MlColumn('Done', flex: 1, align: TextAlign.right),
                    MlColumn('Tons', flex: 2, align: TextAlign.right),
                  ],
                  rows: [
                    for (final r in rows)
                      [
                        _mono(context, r.routeNumber),
                        // Three: as a phone card the route is the line that runs long.
                        _cell(context, r.routeLabel, strong: true, lines: 3),
                        _cell(context, r.commodity ?? '—', lines: 2),
                        _cell(context, r.transporterName ?? '—', lines: 2),
                        _cell(context, _dateFmt.format(MlTime.sast(r.acceptedAt))),
                        _mono(context, '${r.tripsTotal}'),
                        _mono(context, '${r.tripsCompleted}'),
                        _mono(context, r.tonsDelivered.toStringAsFixed(2)),
                      ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  /// A cell of words. [lines] is 2 where the value is a ROUTE — an endpoint
  /// pair like "Iron Hills Mining, Steelpoort → Richards Bay Dry Bulk
  /// Terminal" is 400px and this table's widest column is 274px on a 1600px
  /// window, so at one line the marketplace named where a route STARTS and
  /// dropped where it goes.
  Widget _cell(BuildContext context, String text,
      {bool strong = false, int lines = 1}) {
    final semantic = MlSemantic.of(context);
    return Text(
      text,
      maxLines: lines,
      overflow: TextOverflow.ellipsis,
      style: context.mlText.titleSmall.copyWith(
        color: strong ? semantic.textStrong : semantic.textBody,
        fontWeight: strong ? FontWeight.w700 : FontWeight.w400,
      ),
    );
  }

  Widget _mono(BuildContext context, String text) {
    return Text(
      text,
      textAlign: TextAlign.right,
      maxLines: 1,
      style: context.mlText.code(
        color: MlSemantic.of(context).textStrong,
        size: 13,
        weight: FontWeight.w600,
      ),
    );
  }
}
