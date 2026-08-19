import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/navigation/nav_history_provider.dart';

/// Feeds the [navHistoryProvider] from a shell. Records a visit on mount and
/// whenever [location] or [isRoot] changes. Renders [child] unchanged.
class NavHistoryRecorder extends ConsumerStatefulWidget {
  final NavLocation location;
  final bool isRoot;
  final Widget child;

  const NavHistoryRecorder({
    super.key,
    required this.location,
    required this.isRoot,
    required this.child,
  });

  @override
  ConsumerState<NavHistoryRecorder> createState() => _NavHistoryRecorderState();
}

class _NavHistoryRecorderState extends ConsumerState<NavHistoryRecorder> {
  @override
  void initState() {
    super.initState();
    _record(widget.location, widget.isRoot);
  }

  @override
  void didUpdateWidget(covariant NavHistoryRecorder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location ||
        oldWidget.isRoot != widget.isRoot) {
      _record(widget.location, widget.isRoot);
    }
  }

  void _record(NavLocation location, bool isRoot) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(navHistoryProvider.notifier).visit(location, isRoot: isRoot);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
