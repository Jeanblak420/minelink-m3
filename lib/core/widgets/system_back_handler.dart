import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/navigation/nav_back.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';

/// Makes the phone's own Back (button, gesture or a launcher's custom gesture)
/// behave like the in-app Back arrow instead of closing the app.
///
/// Why this is needed: the shells move between screens with `context.go`, which
/// REPLACES the page, so every navigator holds exactly one page. go_router
/// 13's `popRoute` only calls `maybePop` when some navigator can pop; when none
/// can it returns `false` without consulting any `PopScope`, and Android then
/// finishes the activity. The `PopScope(canPop: false)` the shells already had
/// was therefore never reached by a system back. A [BackButtonListener] sits
/// ahead of `popRoute` in the router's back-button dispatcher, so it is.
///
/// Order, per press:
/// 1. Something the router can pop (dialog, sheet, open drawer, pushed route)
///    → let the router close it.
/// 2. Recorded history → step back exactly as [AppNavigationBackButton] does.
/// 3. Not on the shell's landing screen (e.g. arrived via a notification
///    link, so no history) → [goToRoot].
/// 4. On the landing screen → "Press back again to exit"; a second press
///    within [exitWindow] lets Android close the app.
class SystemBackHandler extends ConsumerStatefulWidget {
  final bool isRoot;
  final VoidCallback goToRoot;
  final Widget child;

  static const Duration exitWindow = Duration(seconds: 2);

  const SystemBackHandler({
    super.key,
    required this.isRoot,
    required this.goToRoot,
    required this.child,
  });

  @override
  ConsumerState<SystemBackHandler> createState() => _SystemBackHandlerState();
}

class _SystemBackHandlerState extends ConsumerState<SystemBackHandler> {
  DateTime? _lastRootPress;

  Future<bool> _onBack() async {
    if (!mounted) return false;

    if (GoRouter.maybeOf(context)?.canPop() ?? false) return false;

    if (ref.read(navHistoryProvider.notifier).canGoBack) {
      _lastRootPress = null;
      navigateBack(context, ref);
      return true;
    }

    if (!widget.isRoot) {
      _lastRootPress = null;
      widget.goToRoot();
      return true;
    }

    final now = DateTime.now();
    final last = _lastRootPress;
    if (last != null && now.difference(last) <= SystemBackHandler.exitWindow) {
      _lastRootPress = null;
      return false; // second press: let the app close
    }
    _lastRootPress = now;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: SystemBackHandler.exitWindow,
        ),
      );
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Needs a Router above it, which the app always has and bare-widget tests
    // do not.
    if (Router.maybeOf(context) == null) return widget.child;
    return BackButtonListener(
      onBackButtonPressed: _onBack,
      child: widget.child,
    );
  }
}
