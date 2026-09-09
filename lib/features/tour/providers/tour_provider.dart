import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/tour/models/tour_step.dart';
import 'package:flutter_application_1/features/tour/providers/tour_seen_provider.dart';

final _log = LoggerFactory.getLogger('TourProvider');

/// State for the active tour
class TourState {
  final bool isActive;
  final int currentStepIndex;
  final List<TourStep> steps;
  final String? currentTargetId;
  final bool isNavigating;

  const TourState({
    this.isActive = false,
    this.currentStepIndex = 0,
    this.steps = const [],
    this.currentTargetId,
    this.isNavigating = false,
  });

  TourStep? get currentStep =>
      currentStepIndex >= 0 && currentStepIndex < steps.length
      ? steps[currentStepIndex]
      : null;

  bool get isFirstStep => currentStepIndex == 0;
  bool get isLastStep => currentStepIndex == steps.length - 1;

  TourState copyWith({
    bool? isActive,
    int? currentStepIndex,
    List<TourStep>? steps,
    String? currentTargetId,
    bool? isNavigating,
  }) {
    return TourState(
      isActive: isActive ?? this.isActive,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      steps: steps ?? this.steps,
      currentTargetId: currentTargetId ?? this.currentTargetId,
      isNavigating: isNavigating ?? this.isNavigating,
    );
  }
}

/// Manages the active coach-mark tour state
class TourNotifier extends StateNotifier<TourState> {
  final Ref ref;

  TourNotifier(this.ref) : super(const TourState());

  /// Start a tour with the given steps
  void startTour(List<TourStep> steps) {
    _log.i('Starting tour with ${steps.length} steps');
    if (steps.isEmpty) {
      _log.w('Cannot start tour with empty steps list');
      return;
    }
    state = TourState(
      isActive: true,
      currentStepIndex: 0,
      steps: steps,
      currentTargetId: steps.first.id,
    );
  }

  /// Stop the current tour
  void stopTour() {
    _log.i('Stopping tour');
    state = const TourState();
    // Mark tour as seen when stopped
    ref.read(tourSeenProvider.notifier).markSeen();
  }

  /// Advance to the next step — or finish the tour when already on the last
  /// step. When [onlyIfStepId] is given, the advance happens ONLY if the
  /// tour is still sitting on that step id. The overlay's skip/retry timers
  /// pass the id that armed them, so a stale timer can never skip the step
  /// the user has already moved on to (the wedge that killed every tour
  /// after Fleet Register on slow renders).
  void nextStep({String? onlyIfStepId}) {
    if (onlyIfStepId != null && state.currentStep?.id != onlyIfStepId) {
      return;
    }
    if (state.isLastStep) {
      stopTour();
      return;
    }
    _log.i('Moving to step ${state.currentStepIndex + 1}');
    state = state.copyWith(
      currentStepIndex: state.currentStepIndex + 1,
      currentTargetId: state.steps[state.currentStepIndex + 1].id,
    );
  }

  /// Move to the previous step
  void previousStep() {
    if (state.isFirstStep) return;
    _log.i('Moving to step ${state.currentStepIndex - 1}');
    state = state.copyWith(
      currentStepIndex: state.currentStepIndex - 1,
      currentTargetId: state.steps[state.currentStepIndex - 1].id,
    );
  }

  /// Jump to a specific step
  void goToStep(int index) {
    if (index < 0 || index >= state.steps.length) return;
    _log.i('Jumping to step $index');
    state = state.copyWith(
      currentStepIndex: index,
      currentTargetId: state.steps[index].id,
    );
  }

  /// Set navigation state (when moving between screens)
  void setNavigating(bool isNavigating) {
    state = state.copyWith(isNavigating: isNavigating);
  }
}

/// Provider for the tour state
final tourProvider = StateNotifierProvider<TourNotifier, TourState>((ref) {
  return TourNotifier(ref);
});
