import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/navigation/nav_back.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';

/// Steps back one screen through the recorded navigation history. Hidden when
/// there is no previous screen (i.e. on the main Dashboard/Overview). Purely
/// navigational — never triggers undo/submit/clear side effects.
class AppNavigationBackButton extends ConsumerWidget {
  final Color? color;

  const AppNavigationBackButton({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canGoBack = ref.watch(navHistoryProvider.select((s) => s.length > 1));
    if (!canGoBack) {
      return const SizedBox.shrink();
    }
    return IconButton(
      tooltip: 'Back',
      icon: Icon(Icons.arrow_back_rounded, color: color),
      onPressed: () => navigateBack(context, ref),
    );
  }
}
