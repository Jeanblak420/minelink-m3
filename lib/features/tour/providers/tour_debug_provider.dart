import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/tour/providers/tour_provider.dart';
import 'package:flutter_application_1/features/tour/providers/tour_seen_provider.dart';
import 'package:flutter_application_1/features/tour/providers/tour_service_provider.dart';

final _log = LoggerFactory.getLogger('TourDebugProvider');

/// Debug utilities for testing the tour system.
///
/// Only available in debug builds. Provides methods to:
/// - Start tours from specific steps
/// - Reset tour completion state
/// - Log tour state and targets
/// - Debug missing targets
class TourDebugNotifier extends StateNotifier<TourDebugState> {
  final Ref ref;

  TourDebugNotifier(this.ref) : super(const TourDebugState());

  /// Start a tour from a specific step index
  void startTourFromStep(int stepIndex) {
    if (!kDebugMode) return;
    
    final steps = ref.read(tourStepsProvider);
    if (steps.isEmpty) {
      _log.w('No tour steps available');
      return;
    }

    if (stepIndex < 0 || stepIndex >= steps.length) {
      _log.w('Invalid step index: $stepIndex (must be 0-${steps.length - 1})');
      return;
    }

    _log.i('Starting tour from step $stepIndex');
    ref.read(tourProvider.notifier).startTour(steps);
    ref.read(tourProvider.notifier).goToStep(stepIndex);
    
    state = state.copyWith(
      lastDebugAction: 'Started tour from step $stepIndex',
      debugModeEnabled: true,
    );
  }

  /// Reset the tour completion state
  Future<void> resetTourCompletion() async {
    if (!kDebugMode) return;
    
    _log.i('Resetting tour completion state');
    await ref.read(tourSeenProvider.notifier).reset();
    
    state = state.copyWith(
      lastDebugAction: 'Reset tour completion',
      debugModeEnabled: true,
    );
  }

  /// Log current tour state
  void logTourState() {
    if (!kDebugMode) return;
    
    final tourState = ref.read(tourProvider);
    final tourSeen = ref.read(tourSeenProvider);
    final steps = ref.read(tourStepsProvider);
    
    _log.i('=== Tour Debug Info ===');
    _log.i('Tour active: ${tourState.isActive}');
    _log.i('Current step: ${tourState.currentStepIndex}/${tourState.steps.length}');
    _log.i('Tour seen: $tourSeen');
    _log.i('Total steps available: ${steps.length}');
    _log.i('Current target: ${tourState.currentTargetId}');
    _log.i('Is navigating: ${tourState.isNavigating}');
    
    for (int i = 0; i < steps.length; i++) {
      final step = steps[i];
      _log.i('Step $i: ${step.id} - ${step.title}');
    }
    
    state = state.copyWith(
      lastDebugAction: 'Logged tour state',
      debugModeEnabled: true,
    );
  }

  /// Debug a specific target key
  void debugTarget(GlobalKey key, String targetId) {
    if (!kDebugMode) return;
    
    _log.i('=== Target Debug: $targetId ===');
    final context = key.currentContext;
    if (context == null) {
      _log.w('Target context is null for $targetId');
      state = state.copyWith(
        lastDebugAction: 'Target $targetId: context is null',
        debugModeEnabled: true,
      );
      return;
    }

    final renderObject = context.findRenderObject() as RenderBox?;
    if (renderObject == null) {
      _log.w('Target render object is null for $targetId');
      state = state.copyWith(
        lastDebugAction: 'Target $targetId: render object is null',
        debugModeEnabled: true,
      );
      return;
    }

    final offset = renderObject.localToGlobal(Offset.zero);
    final size = renderObject.size;
    
    _log.i('Target $targetId position: ${offset.dx}, ${offset.dy}');
    _log.i('Target $targetId size: ${size.width} x ${size.height}');
    _log.i('Target $targetId bounds: ${offset.dx}x${offset.dy} ${size.width}x${size.height}');
    
    state = state.copyWith(
      lastDebugAction: 'Target $targetId: ${offset.dx}x${offset.dy} ${size.width}x${size.height}',
      debugModeEnabled: true,
    );
  }

  /// Enable/disable debug mode
  void setDebugMode(bool enabled) {
    if (!kDebugMode) return;
    
    state = state.copyWith(debugModeEnabled: enabled);
    _log.i('Debug mode ${enabled ? "enabled" : "disabled"}');
  }
}

class TourDebugState {
  final bool debugModeEnabled;
  final String? lastDebugAction;

  const TourDebugState({
    this.debugModeEnabled = false,
    this.lastDebugAction,
  });

  TourDebugState copyWith({
    bool? debugModeEnabled,
    String? lastDebugAction,
  }) {
    return TourDebugState(
      debugModeEnabled: debugModeEnabled ?? this.debugModeEnabled,
      lastDebugAction: lastDebugAction ?? this.lastDebugAction,
    );
  }
}

/// Provider for tour debug utilities (debug builds only)
final tourDebugProvider =
    StateNotifierProvider<TourDebugNotifier, TourDebugState>((ref) {
  return TourDebugNotifier(ref);
});
