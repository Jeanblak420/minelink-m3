import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/widgets/lazy_indexed_stack.dart';
import 'package:flutter_application_1/features/portal/providers/portal_tab_index_provider.dart';
import 'package:flutter_application_1/features/portal/providers/portal_workspace_provider.dart';

/// Body for `/home`: switches portal tabs (chrome lives in [PortalShellLayout]).
/// Visited tabs are kept alive so in-progress input survives tab switches and
/// back-navigation within a session.
class HomeTabBodyScreen extends ConsumerWidget {
  const HomeTabBodyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(portalWorkspaceProvider);
    final idx = ref.watch(portalTabIndexProvider);
    final tabs = vm.tabs;

    if (vm.phase != PortalWorkspacePhase.ready || tabs == null || tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final selected = idx.clamp(0, tabs.length - 1);

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LazyIndexedStack(
        index: selected,
        children: [for (final t in tabs) t.screen],
      ),
    );
  }
}

/// Back-compat alias for routes/tests.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const HomeTabBodyScreen();
}
