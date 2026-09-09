import 'package:flutter/material.dart';

/// A widget that registers its child as a tour target.
///
/// Wrap any UI element with TourTarget to make it highlightable during
/// a coach-mark tour. The targetKey is used by the tour system to find
/// and measure the widget's position for the spotlight.
///
/// Example:
/// ```dart
/// TourTarget(
///   id: 'dashboard.analytics',
///   targetKey: GlobalKey(),
///   child: AnalyticsCard(),
/// )
/// ```
class TourTarget extends StatelessWidget {
  /// Unique identifier for this target (matches TourStep.id)
  final String id;

  /// The GlobalKey used to measure this widget's position
  final GlobalKey targetKey;

  /// The child widget to wrap
  final Widget child;

  const TourTarget({
    super.key,
    required this.id,
    required this.targetKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: targetKey,
      child: child,
    );
  }
}
