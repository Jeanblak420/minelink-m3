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
                        // A LABEL THAT CANNOT FIT ELLIPSISES; IT IS NOT CUT.
                        //
                        // On a 412px phone this read `RT-0042 · Iron Hills
                        // Mining → Richards Bay · perm` — truncated mid-word,
                        // with no ellipsis to say so.
                        //
                        // NOT an overflow, and not the `Wrap` trap it looks
                        // like. `RenderWrap` DOES bound its children to the
                        // row, and measurement confirms it: the chip lays out
                        // at 33..379 inside a card at 16..396, with or without
                        // any constraint of our own (a `ConstrainedBox` was
                        // tried here first and was a no-op). What overran was
                        // the LABEL inside the correctly-bounded chip: with no
                        // `maxLines`/`overflow`, `Chip` clips its label rather
                        // than shortening it, and clipping is silent — no
                        // stripe, nothing in the layout sweeps.
                        //
                        // The route NUMBER leads the label, so what survives
                        // the truncation is the identifier.
                        label: Text(
                          '${r.routeNumber} · ${r.routeLabel}'
                          '${r.permanent ? ' · permanent' : ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
