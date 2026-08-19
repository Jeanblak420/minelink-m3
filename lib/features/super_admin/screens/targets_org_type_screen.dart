import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/features/super_admin/data/models/target_scope.dart';
import 'package:flutter_application_1/features/super_admin/providers/targets_provider.dart';
import 'package:flutter_application_1/features/super_admin/widgets/targets/targets_chrome.dart';
import 'package:flutter_application_1/features/super_admin/widgets/targets/targets_workspace.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';

/// The three org types, in the order the console lists them everywhere else.
enum TargetOrgType {
  mineSupplier('mineSupplier', 'Mines / Suppliers', Icons.terrain_rounded,
      'what left the pit', 'that left the pit'),
  buyer('buyer', 'Buyers', Icons.work_outline_rounded, 'what was received',
      'that was received'),
  transporter('transporter', 'Transporters', Icons.local_shipping_outlined,
      'what was hauled', 'that was hauled');

  const TargetOrgType(
      this.wire, this.label, this.icon, this.lens, this.loadClause);

  final String wire;
  final String label;
  final IconData icon;

  /// How this type's tonnage should be read, as a STANDALONE label — it is the
  /// sublabel on the scope pill, where it reads "WHAT WAS HAULED".
  ///
  /// Deliberately not the same string as [loadClause]. This one answers a
  /// question the pill implies; that one is a relative clause inside a
  /// sentence, and the two forms are not interchangeable.
  final String lens;

  /// The same idea as a relative clause, for use mid-sentence.
  ///
  /// Split out 2026-08-17 after the org-type screens were opened in a browser
  /// for the first time and the band read, on all three:
  ///
  ///     Every load what was hauled — the tonnage on trips with a transporter…
  ///
  /// [lens] was written for the pill, where it is correct, and then
  /// interpolated into a sentence where it is not. Nothing failed: the string
  /// was well-formed, the layout was fine, and no test asserts on prose. It
  /// was visible the moment the screen was rendered and invisible until then.
  final String loadClause;

  static TargetOrgType parse(String? raw) => TargetOrgType.values.firstWhere(
        (o) => o.wire == raw,
        orElse: () => TargetOrgType.transporter,
      );
}

/// Targets per org type — one commitment for the mines, one for the buyers,
/// one for the transporters.
class TargetsOrgTypeScreen extends ConsumerWidget {
  const TargetsOrgTypeScreen({super.key, required this.orgType});

  final TargetOrgType orgType;

  static const String basePath = '/super-admin/targets/org-type';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = MlGlass.of(context);
    final scope = TargetScope.orgType(orgType.wire);
    final data = ref.watch(targetsProvider(scope)).valueOrNull;

    return Container(
      color: t.bg0,
      child: Column(
        children: [
          TargetsBand(
            title: '${orgType.label} targets',
            subtitle: 'Every load ${orgType.loadClause} — the tonnage on trips '
                'with a '
                '${orgType == TargetOrgType.mineSupplier ? "mine" : orgType == TargetOrgType.buyer ? "buyer" : "transporter"} '
                'on them. A load counts once for each side of the transaction, '
                'so these three do not add up to the platform figure; each is '
                'the same movement seen from one side.',
            icon: orgType.icon,
            scopeLabel: 'BY ORG TYPE',
            headline: data == null ? null : TargetsHeadline.of(data),
            selector: Row(
              children: [
                Text(
                  'ORG TYPE',
                  style: TextStyle(
                    fontFamily: MlGlass.sans,
                    fontSize: 8.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                    color: t.inkLo,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final o in TargetOrgType.values)
                        TargetsScopePill(
                          label: o.label,
                          sublabel: o.lens.toUpperCase(),
                          icon: o.icon,
                          selected: o == orgType,
                          // A path segment rather than screen state: an admin
                          // comparing the three wants to link somebody to one.
                          onTap: () => context.go('$basePath/${o.wire}'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            // Keyed so switching type tears the workspace down rather than
            // letting the previous type's dials linger over new data.
            child: TargetsWorkspace(key: ValueKey(orgType), scope: scope),
          ),
        ],
      ),
    );
  }
}
