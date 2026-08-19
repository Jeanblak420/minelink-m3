import 'package:flutter/material.dart';

/// A single step in the guided "Take a tour" walkthrough.
///
/// Steps are defined in code per org type / role (see
/// `TutorialService.getTutorialForUser`); they are not persisted, so the
/// model stays a plain immutable value object.
class TutorialStep {
  final String title;
  final String description;

  /// Optional key naming the portal area this step talks about (informational
  /// only — the overlay is an honest step-by-step guide, not a spotlight).
  final String? targetWidgetKey;

  final IconData? icon;

  /// When true the step offers a call-to-action button that navigates to
  /// [actionRoute] with label [actionLabel].
  final bool hasAction;
  final String? actionLabel;
  final String? actionRoute;

  const TutorialStep({
    required this.title,
    required this.description,
    this.targetWidgetKey,
    this.icon,
    this.hasAction = false,
    this.actionLabel,
    this.actionRoute,
  });
}
