import 'package:flutter/material.dart';

/// A single step in a contextual coach-mark tour.
///
/// Unlike the old TutorialStep, this targets REAL UI elements using
/// targetKey and supports contextual positioning, cross-screen navigation,
/// and interaction with the highlighted target.
class TourStep {
  /// Unique identifier for this step
  final String id;

  /// The GlobalKey of the widget to highlight
  final GlobalKey targetKey;

  /// Title shown in the tooltip
  final String title;

  /// Short description explaining the target
  final String description;

  /// Optional icon for the tooltip
  final IconData? icon;

  /// Preferred tooltip position (top, bottom, left, right, auto)
  final TooltipPosition position;

  /// Optional route to navigate to before showing this step
  final String? navigateTo;

  /// Whether the user can interact with the highlighted target
  final bool allowTargetInteraction;

  /// Padding around the spotlight cutout
  final double spotlightPadding;

  const TourStep({
    required this.id,
    required this.targetKey,
    required this.title,
    required this.description,
    this.icon,
    this.position = TooltipPosition.auto,
    this.navigateTo,
    this.allowTargetInteraction = false,
    this.spotlightPadding = 8.0,
  });
}

/// Preferred tooltip position relative to the target
enum TooltipPosition {
  top,
  bottom,
  left,
  right,
  auto,
}
