import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/auth/models/user_type.dart';
import 'package:flutter_application_1/features/portal/providers/logistics_provider.dart';
import 'package:flutter_application_1/features/portal/utils/portal_company_resolution.dart';
import 'package:flutter_application_1/features/portal/utils/portal_dashboard_navigation.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/portal/widgets/portal_company_required.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Buyer Routes & Mines (ui_kits/buyer BuyerRoutesMines): route cards with a
/// tinted conveyor well and origin → destination, plus the linked
/// mines/suppliers list from live transactions.
class BuyerRoutesMinesScreen extends ConsumerWidget {
  const BuyerRoutesMinesScreen({super.key});

  static const _tones = [
    MlTone.accent,
    MlTone.atMine,
    MlTone.done,
    MlTone.transit,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companyId = resolvePortalCompanyId(ref);
    if (companyId == null) {
      return const PortalCompanyRequired();
    }

    final routesAsync = ref.watch(logisticsSnapshotProvider(companyId));
    final partnersAsync = ref.watch(partnerCompaniesProvider(
        (companyId: companyId, orgFilter: 'mineSupplier')));
    final semantic = MlSemantic.of(context);

    return MlPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MlSectionTitle(
            'Routes & Mines',
            // `routes`, not `waybills`.
            //
            // This counted the snapshot's TRANSACTIONS and called them route
            // records, on the header of a section whose cards are the routes:
            // photographed 2026-08-21 reading "4 route records" over two route
            // cards. The two lists are related but they are not the same list,
            // and the header is the only number a reader has to check the
            // section against.
            meta: routesAsync.valueOrNull == null
                ? null
                : mlCount(routesAsync.value!.routes.length, 'route'),
            icon: Icons.alt_route_rounded,
            margin: const EdgeInsets.only(bottom: 4),
          ),
          Text(
            'All your purchase routes across mines and delivery points.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          routesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error. ${friendlyError(e)}'),
            data: (snap) {
              if (snap.routes.isEmpty) {
                return MlCard(
                  child: MlEmptyState(
                    icon: Icons.alt_route_rounded,
                    title: 'No haul routes yet.',
                    message:
                        'Routes appear here as soon as they are created against your company.',
                  ),
                );
              }
              return LayoutBuilder(builder: (context, c) {
                final w = c.maxWidth;
                final cols = w > 880 ? 2 : 1;
                const gap = 14.0;
                final itemW = cols <= 1 ? w : (w - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (var i = 0; i < snap.routes.length; i++)
                      SizedBox(
                        width: itemW,
                        child: MlCard(
                          onTap: () => openPortalTabByLabel(
                              ref, context, 'Truck locations'),
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MlIconWell(
                                icon: Icons.conveyor_belt,
                                tone: _tones[i % _tones.length],
                                size: 48,
                                radius: 14,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _RouteArrow(
                                      from: snap.routes[i].originLabel,
                                      to: snap.routes[i].destinationLabel,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Updated ${MaterialLocalizations.of(context).formatShortDate(snap.routes[i].updatedAt)}',
                                      style: context.mlText.bodySmall.copyWith(
                                        color: semantic.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  size: 22, color: semantic.textFaint),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              });
            },
          ),
          const SizedBox(height: 28),
          MlSectionTitle('Linked mines & suppliers',
              icon: Icons.domain_outlined,
              meta: partnersAsync.valueOrNull == null
                  ? null
                  : mlCount(partnersAsync.value!.length, 'partner')),
          partnersAsync.when(
            loading: () => const CircularProgressIndicator(),
            error: (e, _) => Text('Partners. ${friendlyError(e)}'),
            data: (pins) {
              if (pins.isEmpty) {
                return MlCard(
                  child: MlEmptyState(
                    icon: Icons.domain_outlined,
                    title: 'No mine/supplier partners found yet.',
                    message:
                        'Partners linked through your transactions appear here.',
                  ),
                );
              }
              return MlCard(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    for (var i = 0; i < pins.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: semantic.divider),
                      ListTile(
                        leading: const MlIconWell(
                            icon: Icons.domain_outlined,
                            size: 40,
                            radius: 11),
                        title: Text(pins[i].name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        // `CompanyPin.orgType` is `companies.org_type` verbatim, so this
                        // read "mineSupplier" under both partners —
                        // Postgres's vocabulary on a buyer's screen.
                        subtitle: Text(OrgType.labelFor(pins[i].orgType,
                            fallback: 'Partner')),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RouteArrow extends StatelessWidget {
  final String from;
  final String to;

  const _RouteArrow({required this.from, required this.to});

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final style = context.mlText.titleSmall.copyWith(color: semantic.textStrong);
    return Wrap(
      spacing: 7,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(from, style: style),
        Icon(Icons.arrow_forward_rounded, size: 15, color: semantic.textFaint),
        Text(to, style: style),
      ],
    );
  }
}
