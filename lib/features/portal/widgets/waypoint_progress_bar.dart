import 'package:flutter/material.dart';

import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/portal/models/trip_waypoint.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';

/// Ordered waypoint chips for a trip's mine-nav sequence (phase-5 design §3.2):
/// Main Gate → Weighbridge → Loading Point → Weighbridge → Main Gate →
/// Drop-off, rendered from the actual `trip_waypoints` rows.
///
/// - `MlTone.done` + check: completed waypoints
/// - `MlTone.transit` + pulse: the current waypoint (first not completed)
/// - muted: future waypoints
///
/// Display-only by default; [onWaypointTapped] is an optional hook for later
/// phases (security confirmations) — never wire it to `TripStatus`.
class WaypointProgressBar extends StatelessWidget {
  final List<TripWaypoint> waypoints;
  final void Function(TripWaypoint waypoint)? onWaypointTapped;

  const WaypointProgressBar({
    required this.waypoints,
    this.onWaypointTapped,
    super.key,
  });

  static IconData _iconFor(WaypointType type) {
    switch (type) {
      case WaypointType.mainGate:
        return Icons.door_sliding_outlined;
      case WaypointType.weighbridge:
        return Icons.scale_outlined;
      case WaypointType.loadingPoint:
        return Icons.inventory_2_outlined;
      case WaypointType.dropOff:
        return Icons.flag_outlined;
    }
  }

  static String _shortLabel(WaypointType type) {
    switch (type) {
      case WaypointType.mainGate:
        return 'MG';
      case WaypointType.weighbridge:
        return 'WB';
      case WaypointType.loadingPoint:
        return 'LP';
      case WaypointType.dropOff:
        return 'DO';
    }
  }

  /// The first not-yet-completed waypoint, or -1 when all are done.
  int get _currentIndex {
    for (var i = 0; i < waypoints.length; i++) {
      if (!waypoints[i].isCompleted) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    if (waypoints.isEmpty) return const SizedBox.shrink();
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final done = MlTone.done.colors(brightness);
    final current = MlTone.transit.colors(brightness);
    final currentIx = _currentIndex;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          for (var i = 0; i < waypoints.length; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: waypoints[i - 1].isCompleted
                        ? done.fg
                        : semantic.borderCard,
                    borderRadius: BorderRadius.circular(MlTokens.rPill),
                  ),
                ),
              ),
            _WaypointDot(
              waypoint: waypoints[i],
              icon: _iconFor(waypoints[i].locationType),
              fallbackLabel: _shortLabel(waypoints[i].locationType),
              isCurrent: i == currentIx,
              doneColors: done,
              currentColors: current,
              semantic: semantic,
              onTap: onWaypointTapped == null
                  ? null
                  : () => onWaypointTapped!(waypoints[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaypointDot extends StatelessWidget {
  final TripWaypoint waypoint;
  final IconData icon;
  final String fallbackLabel;
  final bool isCurrent;
  final MlToneColors doneColors;
  final MlToneColors currentColors;
  final MlSemantic semantic;
  final VoidCallback? onTap;

  const _WaypointDot({
    required this.waypoint,
    required this.icon,
    required this.fallbackLabel,
    required this.isCurrent,
    required this.doneColors,
    required this.currentColors,
    required this.semantic,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final completed = waypoint.isCompleted;
    final label = waypoint.name.trim().isEmpty
        ? fallbackLabel
        : (waypoint.name.length > 9
            ? '${waypoint.name.substring(0, 8)}…'
            : waypoint.name);

    final dot = Container(
      width: isCurrent ? 30 : 26,
      height: isCurrent ? 30 : 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: completed
            ? doneColors.fg
            : isCurrent
                ? currentColors.bg
                : semantic.surfaceSunken,
        border: Border.all(
          color: completed
              ? doneColors.fg
              : isCurrent
                  ? currentColors.fg
                  : semantic.borderCard,
          width: 2,
        ),
      ),
      alignment: Alignment.center,
      child: completed
          ? const Icon(Icons.check_rounded, size: 14, color: MlTokens.inkOnFill)
          : isCurrent
              ? MlPulsingDot(color: currentColors.fg)
              : Icon(icon, size: 12, color: semantic.textFaint),
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          dot,
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.mlText.labelSmall.copyWith(
              color: completed ? doneColors.fg : isCurrent ? currentColors.fg : semantic.textMuted,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft pulse on the current waypoint's dot.
///
/// Public so `test/widgets/reduce_motion_test.dart` can drive THIS class rather
/// than a copy of it. A copy would be free to drift from the thing it stands
/// for, and the property under test — that a repeating controller is never
/// started when the user has asked the system to stop moving things — is
/// exactly the sort that a copy keeps while the original loses it.
class MlPulsingDot extends StatefulWidget {
  final Color color;
  const MlPulsingDot({super.key, required this.color});

  @override
  State<MlPulsingDot> createState() => MlPulsingDotState();
}

class MlPulsingDotState extends State<MlPulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
    // Starts settled, and only repeats if the user has not asked the system to
    // stop moving things — see didChangeDependencies.
    value: 1,
  );
  late final Animation<double> _animation =
      Tween<double>(begin: 0.45, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A REPEATING animation cannot be handled the way a one-shot can. Collapsing
    // its duration to 1ms — which is what MlMotion does, correctly, for a
    // transition — would spin this dot at a thousand frames a second. The only
    // right answer for a loop is not to start it, and to hold the settled
    // frame: here that is full opacity, the state the pulse returns to.
    //
    // This dot marks the CURRENT waypoint on a trip in progress, so it is on
    // screen for as long as the driver is driving. An unstoppable pulse in
    // somebody's peripheral vision for a four-hour haul is exactly what
    // `disableAnimations` exists to switch off.
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduce) {
      if (_controller.isAnimating) _controller.stop();
      _controller.value = 1;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 11,
        height: 11,
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}
