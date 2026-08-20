import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/providers/request_provider.dart';
import 'package:flutter_application_1/features/portal/screens/request_transportation_screen.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

/// Available routes the super-admin assigned to this org (§4): selecting one
/// opens the Request Route form pre-filled from the learned route. Shown on
/// the org's Requests screen and mirrored on its dashboard. Renders nothing
/// while loading or when no routes are assigned.
class AvailableRoutesSection extends ConsumerWidget {
  final String companyId;
  final bool enabled;
  const AvailableRoutesSection({
    super.key,
    required this.companyId,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final async = ref.watch(myAvailableRoutesProvider(companyId));

    return async.maybeWhen(
      data: (routes) {
        if (routes.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: MlCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MlSectionTitle(
                  'Available routes',
                  meta: mlCount(routes.length, 'route'),
                  icon: Icons.alt_route_outlined,
                  margin: EdgeInsets.zero,
                ),
                const SizedBox(height: 4),
                Text(
                  'Routes MineLink made available to you. Select one to '
                  'pre-fill a transportation request — everything stays '
                  'editable before you submit.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in routes)
                      ActionChip(
                        avatar: const Icon(Icons.alt_route_outlined, size: 16),
                        label: Text(
                          '${r.routeNumber} · ${r.routeLabel}'
                          '${r.permanent ? ' · permanent' : ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: !enabled
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      RequestTransportationScreen(prefill: r),
                                ),
                              ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}
