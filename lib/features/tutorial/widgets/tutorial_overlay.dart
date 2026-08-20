import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/features/tutorial/models/tutorial_step.dart';
import 'package:flutter_application_1/features/tutorial/providers/tutorial_providers.dart';

/// A full-screen guided walkthrough: a dimmed backdrop with a step card that
/// explains each part of the portal and can navigate straight to the relevant
/// screen (via the step's action route), with a step counter and controls.
///
/// Renders nothing when the tour is not active, so it is safe (and cheap) to
/// keep permanently mounted in a [Stack] at the portal shell level. The tour
/// is fully optional: Skip is always available and completing or skipping it
/// persists the "seen" flag via [tutorialSeenProvider].
class TutorialOverlay extends ConsumerStatefulWidget {
  const TutorialOverlay({super.key});

  @override
  ConsumerState<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends ConsumerState<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: MlTokens.durBase,
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: MlTokens.easeOutCubic,
    );
    _scaleIn = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: MlTokens.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlayState = ref.watch(tutorialOverlayProvider);
    final steps = ref.watch(tutorialStepsProvider);
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;

    if (!overlayState.isVisible || steps.isEmpty) {
      if (_animController.isCompleted || _animController.isAnimating) {
        _animController.reverse();
      }
      return const SizedBox.shrink();
    }

    if (!_animController.isAnimating && !_animController.isCompleted) {
      _animController.forward();
    }

    final currentIdx = overlayState.currentStep.clamp(0, steps.length - 1);
    final step = steps[currentIdx];
    final totalSteps = steps.length;

    return FadeTransition(
      opacity: _fadeIn,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Dimmed backdrop (blocks interaction with the app underneath
            // while the tour is showing — dismissible via Skip at any time).
            GestureDetector(
              onTap: () {}, // block taps through
              child: Container(
                color: MlTokens.navy950.withValues(alpha: 0.72),
              ),
            ),
            // Content card
            Positioned(
              left: 24,
              right: 24,
              bottom: 48,
              child: ScaleTransition(
                scale: _scaleIn,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // P10-D8 (client ruling, 2026-08-12): the
                        // `DemoDataIndicator` banner used to sit here, reading
                        // "Demo Data Active — showing example content". It was
                        // removed rather than retriggered, because there was
                        // nothing true left for it to say: the tour narrates
                        // the operator's OWN live screens, and no widget has
                        // ever read `ShowcaseItem.data`, so no example content
                        // is shown at any point. The banner therefore labelled
                        // real data as demo. The 14 `showcase_data` rows stay
                        // by the client's explicit choice — the banner was the
                        // defect, not the rows. If a future tour genuinely
                        // renders showcase content, the honest trigger is that
                        // rendering, not the mere existence of the rows.
                        _StepCard(
                          step: step,
                          currentIdx: currentIdx,
                          totalSteps: totalSteps,
                          semantic: semantic,
                          brightness: brightness,
                          onNext: () {
                            if (currentIdx == totalSteps - 1) {
                              _finish();
                            } else {
                              ref
                                  .read(tutorialOverlayProvider.notifier)
                                  .nextStep(totalSteps);
                            }
                          },
                          onPrevious: () => ref
                              .read(tutorialOverlayProvider.notifier)
                              .previousStep(),
                          onSkip: _finish,
                          onAction:
                              step.hasAction && step.actionRoute != null
                                  ? () => context.go(step.actionRoute!)
                                  : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _finish() {
    ref.read(tutorialOverlayProvider.notifier).dismiss();
    ref.read(tutorialSeenProvider.notifier).markSeen();
  }
}

/// The card that displays the step content with navigation buttons.
class _StepCard extends StatelessWidget {
  final TutorialStep step;
  final int currentIdx;
  final int totalSteps;
  final MlSemantic semantic;
  final Brightness brightness;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;
  final VoidCallback? onAction;

  const _StepCard({
    required this.step,
    required this.currentIdx,
    required this.totalSteps,
    required this.semantic,
    required this.brightness,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = currentIdx == totalSteps - 1;
    final isFirst = currentIdx == 0;
    final accentWell = MlTone.accent.well(brightness);

    return Container(
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.r2xl),
        border: Border.all(color: semantic.borderCard),
        boxShadow: MlTokens.shadowLg,
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepCounter(
            currentIdx: currentIdx,
            totalSteps: totalSteps,
            semantic: semantic,
          ),
          const SizedBox(height: 16),
          // Icon + title
          Row(
            children: [
              if (step.icon != null) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentWell,
                    borderRadius: BorderRadius.circular(MlTokens.rLg),
                  ),
                  child: Icon(step.icon, color: MlTokens.accent, size: 24),
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  step.title,
                  style: context.mlText.editorialSmall.copyWith(
                    color: semantic.textStrong,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Description
          Text(
            step.description,
            style: context.mlText.bodyLarge.copyWith(color: semantic.textBody),
          ),
          const SizedBox(height: 24),
          // Action button (go to the feature this step describes)
          if (step.hasAction && onAction != null) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(
                  step.actionLabel ?? 'Go',
                  style: const TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: MlTokens.fsBodySm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MlTokens.accent,
                  foregroundColor: MlTokens.inkOnFill,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MlTokens.rMd),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Navigation buttons
          Row(
            children: [
              TextButton(
                onPressed: onSkip,
                style: TextButton.styleFrom(
                  foregroundColor: semantic.textMuted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'Skip',
                  style: context.mlText.bodyMedium.copyWith(
                    color: semantic.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Spacer(),
              if (!isFirst)
                TextButton(
                  onPressed: onPrevious,
                  style: TextButton.styleFrom(
                    foregroundColor: semantic.textBody,
                  ),
                  child: const Text(
                    'Previous',
                    style: TextStyle(
                      fontFamily: MlTokens.fontSans,
                      fontSize: MlTokens.fsBodySm,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: MlTokens.accent,
                  foregroundColor: MlTokens.inkOnFill,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(MlTokens.rMd),
                  ),
                ),
                child: Text(
                  isLast ? 'Got it!' : 'Next',
                  style: const TextStyle(
                    fontFamily: MlTokens.fontSans,
                    fontSize: MlTokens.fsBodySm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Displays "Step X of Y" with dot indicators and a progress bar.
class _StepCounter extends StatelessWidget {
  final int currentIdx;
  final int totalSteps;
  final MlSemantic semantic;

  const _StepCounter({
    required this.currentIdx,
    required this.totalSteps,
    required this.semantic,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentIdx + 1) / totalSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Step ${currentIdx + 1} of $totalSteps',
              style: const TextStyle(
                fontFamily: MlTokens.fontSans,
                fontSize: MlTokens.fsBodySm,
                fontWeight: FontWeight.w600,
                color: MlTokens.accent,
              ),
            ),
            const Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(totalSteps, (i) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= currentIdx
                        ? MlTokens.accent
                        : semantic.borderStrong,
                  ),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(MlTokens.rPill),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: semantic.surfaceSunken,
            valueColor: const AlwaysStoppedAnimation<Color>(MlTokens.accent),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
