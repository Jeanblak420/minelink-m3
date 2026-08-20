import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/super_admin/data/models/target_scope.dart';
import 'package:flutter_application_1/features/super_admin/providers/targets_provider.dart';
import 'package:flutter_application_1/features/super_admin/widgets/targets/targets_chrome.dart';
import 'package:flutter_application_1/features/super_admin/widgets/targets/targets_workspace.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';

/// Platform targets — the whole network as one number.
///
/// Every trip on the platform counts once, whoever hauled it and whoever
/// bought it. This is the figure the other two scopes decompose: the org-type
/// screen splits it by who was involved, the company screen by which company.
class TargetsPlatformScreen extends ConsumerWidget {
  const TargetsPlatformScreen({super.key});

  static const TargetScope scope = TargetScope.platform;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = MlGlass.of(context);
    final data = ref.watch(targetsProvider(scope)).valueOrNull;

    return Container(
      color: t.bg0,
      child: TargetsPage(
        band: TargetsBand(
          title: 'Platform targets',
          subtitle: 'Every organisation combined. Tonnage is weighbridge net '
              'mass — gross less tare, the figure recon and billing already '
              'run on — so a target here is measured against the same number '
              'the waybills carry.',
          icon: Icons.public_rounded,
          scopeLabel: 'PLATFORM-WIDE',
          headline: data == null ? null : TargetsHeadline.of(data),
        ),
        body: const TargetsWorkspace(scope: scope),
      ),
    );
  }
}
