import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';
import 'package:flutter_application_1/features/portal/providers/portal_tab_index_provider.dart';

/// Navigates one step back through the recorded screen history. Navigation
/// only — never submits, cancels, or clears anything. No-op if there is no
/// previous screen.
void navigateBack(BuildContext context, WidgetRef ref) {
  final target = ref.read(navHistoryProvider.notifier).popForBack();
  if (target == null) return;

  final tabIndex = target.homeTabIndex;
  if (tabIndex != null) {
    ref.read(portalTabIndexProvider.notifier).state = tabIndex;
    context.go('/home');
  } else {
    context.go(target.fullLocation);
  }
}
