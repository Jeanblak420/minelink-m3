import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/design/tokens/ml_tokens.dart';
import 'package:flutter_application_1/core/utils/logger.dart';
import 'package:flutter_application_1/features/tour/models/tour_step.dart';
import 'package:flutter_application_1/features/tour/providers/tour_provider.dart';

final _log = LoggerFactory.getLogger('TourOverlay');

/// A contextual coach-mark tour overlay with spotlight and tooltip.
///
/// Replaces the old full-screen TutorialOverlay with a real in-app
/// guided tour that highlights actual UI elements and shows contextual
/// tooltips next to them.
class TourOverlay extends ConsumerStatefulWidget {
  const TourOverlay({super.key});

  @override
  ConsumerState<TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<TourOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleIn;

  /// Last step id we already handled navigation for. Stops the navigation
  /// block below re-firing on the rebuild caused by setNavigating(false).
  String? _lastNavigatedStepId;

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
    _scaleIn = Tween<double>(begin: 0.95, end: 1.0).animate(
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
    final tourState = ref.watch(tourProvider);

    if (!tourState.isActive || tourState.currentStep == null) {
      if (_animController.isCompleted || _animController.isAnimating) {
        _animController.reverse();
      }
      return const SizedBox.shrink();
    }

    if (!_animController.isAnimating && !_animController.isCompleted) {
      _animController.forward();
    }

    final step = tourState.currentStep!;
    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;

    // Handle navigation to another screen if needed.
    //
    // Every step runs through here — including plain same-screen steps — so
    // the flag must be per-step, not global. navigateTo steps always set
    // their own flag (never stacked Future.delays), same-screen steps reset
    // it, and the guard below keeps the stale 300ms timer from a previous
    // navigateTo step clearing the flag of its successor (which is exactly
    // what wedged the tour on Fleet Register: the routes timer fired mid
    // routes-measure and re-armed isNavigating on the routes step).
    if (step.navigateTo != null) {
      if (_lastNavigatedStepId != step.id && !tourState.isNavigating) {
        _lastNavigatedStepId = step.id;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final capturedStepId = step.id;
          final navigator = context; // Capture context before async gap
          ref.read(tourProvider.notifier).setNavigating(true);
          navigator.go(step.navigateTo!);
          // Give the screen time to render before finding the target.
          // The id check stops this stale timer clearing a LATER step's flag
          // when the user taps Next before the delay elapses.
          Future.delayed(const Duration(milliseconds: 600), () {
            if (!mounted) return;
            if (ref.read(tourProvider).currentStep?.id != capturedStepId) {
              return;
            }
            ref.read(tourProvider.notifier).setNavigating(false);
          });
        });
      }
    } else {
      _lastNavigatedStepId = null;
    }

    final isWaitingOnNavigation =
        step.navigateTo != null && tourState.isNavigating;

    return FadeTransition(
      opacity: _fadeIn,
      child: Material(
        color: Colors.transparent,
        child: _TourOverlayContent(
          // Keyed by step so a Next/Back always rebuilds the measurer fresh:
          // otherwise its stale _targetRect/_retryCount leak into the new
          // step and wedge the tour when the next target is slow to mount.
          key: ValueKey('tour-step-${step.id}'),
          step: step,
          semantic: semantic,
          brightness: brightness,
          isWaitingOnNavigation: isWaitingOnNavigation,
          onNext: () => ref.read(tourProvider.notifier).nextStep(),
          onPrevious: () => ref.read(tourProvider.notifier).previousStep(),
          onSkip: () => ref.read(tourProvider.notifier).stopTour(),
          scaleAnimation: _scaleIn,
        ),
      ),
    );
  }
}

class _TourOverlayContent extends ConsumerStatefulWidget {
  final TourStep step;
  final MlSemantic semantic;
  final Brightness brightness;
  final bool isWaitingOnNavigation;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;
  final Animation<double> scaleAnimation;

  const _TourOverlayContent({
    super.key,
    required this.step,
    required this.semantic,
    required this.brightness,
    this.isWaitingOnNavigation = false,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    required this.scaleAnimation,
  });

  @override
  ConsumerState<_TourOverlayContent> createState() =>
      _TourOverlayContentState();
}

class _TourOverlayContentState extends ConsumerState<_TourOverlayContent> {
  Rect? _targetRect;
  Size? _screenSize;
  int _retryCount = 0;
  static const _maxRetries = 3;
  bool _isMeasuring = false;

  @override
  void initState() {
    super.initState();
    _measureTarget();
  }

  @override
  void didUpdateWidget(_TourOverlayContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step.id != widget.step.id) {
      _retryCount = 0;
      _isMeasuring = false;
      _measureTarget();
    } else if (oldWidget.isWaitingOnNavigation &&
        !widget.isWaitingOnNavigation) {
      // navigateTo screen finished rendering — the target is mountable now.
      _isMeasuring = false;
      _measureTarget();
    }
  }

  void _measureTarget() {
    if (_isMeasuring) return;
    // While a navigateTo step is still waiting for its screen to render,
    // don't measure (the old screen's keys are stale) and — critically —
    // don't start any skip/retry timer. The content is keyed by step id so
    // this state is fresh per step anyway.
    if (widget.isWaitingOnNavigation) return;
    _isMeasuring = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _isMeasuring = false;
        return;
      }
      // Step changed or the wait ended while the frame was pending: re-run
      // through the current state instead of measuring stale conditions.
      if (widget.isWaitingOnNavigation) {
        _isMeasuring = false;
        return;
      }
      final measuredStepId = widget.step.id;

      final targetContext = widget.step.targetKey.currentContext;
      if (targetContext == null) {
        _log.w('Target context not found for step ${widget.step.id}');
        _isMeasuring = false;
        // Target not found - skip this step after a delay via an id-checked
        // nextStep: even if this state's `mounted` is still true (keyed
        // states stay mounted through a step change until the next frame),
        // the notifier itself refuses to skip unless the tour is still on
        // the step that armed the timer.
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          ref
              .read(tourProvider.notifier)
              .nextStep(onlyIfStepId: measuredStepId);
        });
        return;
      }

      // Capture screen size before async gap
      // ignore: use_build_context_synchronously
      final screenSize = MediaQuery.sizeOf(context);

      // Try to scroll the target into view if it's in a scrollable container
      _scrollTargetIntoView(targetContext).then((_) {
        if (!mounted) {
          _isMeasuring = false;
          return;
        }
        // Step changed while scrolling (fast Next taps): drop this stale
        // measurement instead of painting the new step's tooltip on the old
        // step's rect. Live provider read — the old `widget.step.id` check
        // could never see the step change on a keyed (disposed) state.
        final liveStepId = ref.read(tourProvider).currentStep?.id;
        if (liveStepId != measuredStepId || widget.isWaitingOnNavigation) {
          _isMeasuring = false;
          return;
        }

        // Re-find the render object after scrolling. The target may have
        // unmounted while the scroll ran (e.g. the screen changed) — looking
        // up a deactivated element is unsafe, so an unmounted target reads
        // as "not found" and takes the retry/skip path below.
        final renderObject = targetContext.mounted
            ? targetContext.findRenderObject() as RenderBox?
            : null;
        if (renderObject != null) {
          final offset = renderObject.localToGlobal(Offset.zero);
          final size = renderObject.size;
          if (!mounted) {
            _isMeasuring = false;
            return;
          }
          setState(() {
            _targetRect = Rect.fromLTWH(
              offset.dx,
              offset.dy,
              size.width,
              size.height,
            );
            _screenSize = screenSize;
          });
          _isMeasuring = false;
        } else {
          _log.w('Target render object not found for step ${widget.step.id}');
          _isMeasuring = false;
          // Retry a few times before skipping — every timer goes through the
          // id-checked nextStep / re-measure, so a stale timer from a
          // previous step can only ever skip the step that armed it.
          if (_retryCount < _maxRetries) {
            _retryCount++;
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              if (ref.read(tourProvider).currentStep?.id != measuredStepId) {
                return;
              }
              _measureTarget();
            });
          } else {
            _log.w('Max retries reached for step ${widget.step.id}, skipping');
            Future.delayed(const Duration(milliseconds: 500), () {
              if (!mounted) return;
              ref
                  .read(tourProvider.notifier)
                  .nextStep(onlyIfStepId: measuredStepId);
            });
          }
        }
      });
    });
  }

  Future<void> _scrollTargetIntoView(BuildContext targetContext) async {
    // Find the nearest scrollable ancestor
    ScrollableState? scrollableState;
    try {
      scrollableState = Scrollable.of(targetContext);
    } catch (_) {
      // No scrollable ancestor found
      return;
    }

    // Ensure the target is visible
    await Future.delayed(const Duration(milliseconds: 100));

    // The State may be gone after the await, and so may the target itself —
    // both reads below must be guarded on their own object, not on an
    // unrelated `mounted`.
    if (!mounted || !targetContext.mounted) return;

    // Capture render object before async gap
    final renderObject = targetContext.findRenderObject();
    if (renderObject == null) return;

    try {
      // Try to scroll to make the target visible
      await scrollableState.position.ensureVisible(
        renderObject,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
      );
      // Wait for the scroll animation to complete
      await Future.delayed(const Duration(milliseconds: 350));
    } catch (e) {
      _log.w('Failed to scroll target into view: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // A navigateTo step whose screen hasn't rendered yet shows nothing but
    // also must NOT start any skip/retry measurement — the target keys on
    // the old screen are stale by definition.
    if (widget.isWaitingOnNavigation) {
      return const SizedBox.shrink();
    }
    if (_targetRect == null || _screenSize == null) {
      return const SizedBox.shrink();
    }

    final padding = widget.step.spotlightPadding;
    final spotlightRect = Rect.fromLTWH(
      _targetRect!.left - padding,
      _targetRect!.top - padding,
      _targetRect!.width + padding * 2,
      _targetRect!.height + padding * 2,
    );

    final tooltipPosition = _calculateTooltipPosition(spotlightRect);

    // Space the tooltip must stay inside. The tooltip itself is capped at
    // [maxTooltipWidth] below, so positioning math must assume that exact
    // width — assuming a smaller width is what let wide tooltips hang off
    // the right edge of the screen (e.g. the "Add a Vehicle" step).
    const margin = 16.0;
    final maxTooltipWidth = math.min(400.0, _screenSize!.width - margin * 2);
    final maxTooltipHeight = math.min(480.0, _screenSize!.height - margin * 2);
    // Defensive re-clamp: even if the estimate used for positioning is off,
    // the rendered card can never be placed partly off-screen.
    final safeLeft = tooltipPosition.offset.dx
        .clamp(
          margin,
          math.max(margin, _screenSize!.width - margin - maxTooltipWidth),
        )
        .toDouble();
    final safeTop = tooltipPosition.offset.dy
        .clamp(margin, math.max(margin, _screenSize!.height - margin - 200.0))
        .toDouble();

    return Stack(
      children: [
        // Semi-transparent overlay with spotlight cutout
        GestureDetector(
          behavior: widget.step.allowTargetInteraction
              ? HitTestBehavior.translucent
              : HitTestBehavior.opaque,
          child: CustomPaint(
            size: _screenSize!,
            painter: _SpotlightPainter(
              spotlightRect: spotlightRect,
              overlayColor: MlTokens.navy950.withValues(alpha: 0.72),
            ),
          ),
        ),
        // Tooltip — always fully on-screen, scrolls internally if the
        // content is taller than the available space instead of clipping.
        Positioned(
          left: safeLeft,
          top: safeTop,
          child: ScaleTransition(
            scale: widget.scaleAnimation,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxTooltipWidth,
                maxHeight: maxTooltipHeight,
              ),
              child: _TourTooltip(
                step: widget.step,
                semantic: widget.semantic,
                brightness: widget.brightness,
                position: tooltipPosition.position,
                onNext: widget.onNext,
                onPrevious: widget.onPrevious,
                onSkip: widget.onSkip,
              ),
            ),
          ),
        ),
      ],
    );
  }

  _TooltipPosition _calculateTooltipPosition(Rect spotlightRect) {
    // _screenSize is always non-null here (build returns early otherwise),
    // but guard anyway so a missing size still yields a centred tooltip.
    final screenSize = _screenSize;
    if (screenSize == null) {
      return const _TooltipPosition(
        position: TooltipPosition.bottom,
        offset: Offset(16, 16),
      );
    }

    // Must match the ConstrainedBox in build(): the tooltip can render up to
    // 400px wide, so planning for only 320px is what pushed right-edge
    // targets (e.g. "Add vehicle") partly off-screen.
    const margin = 16.0;
    const arrowSize = 12.0;
    const tooltipHeight = 240.0;

    final width = screenSize.width;
    final height = screenSize.height;
    final tooltipWidth = math.min(400.0, width - margin * 2);

    // Try each position in order of preference
    final positions = [
      TooltipPosition.bottom,
      TooltipPosition.top,
      TooltipPosition.left,
      TooltipPosition.right,
    ];

    for (final position in positions) {
      Offset? offset;
      bool fits = false;

      switch (position) {
        case TooltipPosition.bottom:
          offset = Offset(
            spotlightRect.left + spotlightRect.width / 2 - tooltipWidth / 2,
            spotlightRect.bottom + arrowSize + margin,
          );
          fits = offset.dy + tooltipHeight < height - margin;
          break;
        case TooltipPosition.top:
          offset = Offset(
            spotlightRect.left + spotlightRect.width / 2 - tooltipWidth / 2,
            spotlightRect.top - tooltipHeight - arrowSize - margin,
          );
          fits = offset.dy >= margin;
          break;
        case TooltipPosition.left:
          offset = Offset(
            spotlightRect.left - tooltipWidth - arrowSize - margin,
            spotlightRect.top + spotlightRect.height / 2 - tooltipHeight / 2,
          );
          fits = offset.dx >= margin;
          break;
        case TooltipPosition.right:
          final rightOffset = Offset(
            spotlightRect.right + arrowSize + margin,
            spotlightRect.top + spotlightRect.height / 2 - tooltipHeight / 2,
          );
          offset = rightOffset;
          fits = rightOffset.dx + tooltipWidth < width - margin;
          break;
        case TooltipPosition.auto:
          continue;
      }

      if (fits) {
        // Clamp fully inside the viewport on BOTH axes — a tooltip below a
        // right-edge target must slide left AND up enough to stay visible,
        // never hang off any edge.
        final clampedDx = offset.dx
            .clamp(margin, math.max(margin, width - margin - tooltipWidth))
            .toDouble();
        final clampedDy = offset.dy
            .clamp(margin, math.max(margin, height - margin - tooltipHeight))
            .toDouble();
        return _TooltipPosition(
          position: position,
          offset: Offset(clampedDx, clampedDy),
        );
      }
    }

    // Fallback: centre the card in the viewport so it is always readable,
    // even when the spotlight leaves no room on any side.
    final fallbackWidth = math.min(tooltipWidth, width - margin * 2);
    final fallbackHeight = math.min(tooltipHeight, height - margin * 2);
    return _TooltipPosition(
      position: TooltipPosition.bottom,
      offset: Offset(
        (width - fallbackWidth) / 2,
        (height - fallbackHeight) / 2,
      ),
    );
  }
}

class _TooltipPosition {
  final TooltipPosition position;
  final Offset offset;

  const _TooltipPosition({required this.position, required this.offset});
}

/// Custom painter that creates a semi-transparent overlay with a cutout
class _SpotlightPainter extends CustomPainter {
  final Rect spotlightRect;
  final Color overlayColor;

  _SpotlightPainter({required this.spotlightRect, required this.overlayColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRect(spotlightRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, Paint()..color = overlayColor);
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) {
    return oldDelegate.spotlightRect != spotlightRect ||
        oldDelegate.overlayColor != overlayColor;
  }
}

/// The tooltip card shown next to the highlighted target
class _TourTooltip extends ConsumerWidget {
  final TourStep step;
  final MlSemantic semantic;
  final Brightness brightness;
  final TooltipPosition position;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;

  const _TourTooltip({
    required this.step,
    required this.semantic,
    required this.brightness,
    required this.position,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accentWell = MlTone.accent.well(brightness);
    final tourState = ref.watch(tourProvider);
    final isLast = tourState.isLastStep;
    final isFirst = tourState.isFirstStep;

    // The card itself must never overflow: long titles wrap, the
    // description scrolls internally on short viewports, and the action
    // row wraps instead of pushing the "Next" button off-screen.
    return Container(
      decoration: BoxDecoration(
        color: semantic.surfaceCard,
        borderRadius: BorderRadius.circular(MlTokens.rLg),
        border: Border.all(color: semantic.borderCard),
        boxShadow: MlTokens.shadowLg,
      ),
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 320),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon + title
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (step.icon != null) ...[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accentWell,
                        borderRadius: BorderRadius.circular(MlTokens.rMd),
                      ),
                      child: Icon(step.icon, color: MlTokens.accent, size: 20),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      step.title,
                      softWrap: true,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: context.mlText.headlineSmall.copyWith(
                        color: semantic.textStrong,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Description — always fully readable, wraps to any width.
              Text(
                step.description,
                softWrap: true,
                style: context.mlText.bodyMedium.copyWith(
                  color: semantic.textBody,
                ),
              ),
              const SizedBox(height: 16),
              // Navigation buttons — Wrap so Skip/Back/Next never clip on
              // narrow cards; Next stays visible via run alignment.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 8,
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor: semantic.textMuted,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Text(
                      'Skip',
                      style: context.mlText.bodySmall.copyWith(
                        color: semantic.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!isFirst)
                        TextButton(
                          onPressed: onPrevious,
                          style: TextButton.styleFrom(
                            foregroundColor: semantic.textBody,
                          ),
                          child: const Text(
                            'Back',
                            style: TextStyle(
                              fontFamily: MlTokens.fontSans,
                              fontSize: MlTokens.fsBodySm,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ElevatedButton(
                        onPressed: onNext,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MlTokens.accent,
                          foregroundColor: MlTokens.inkOnFill,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(MlTokens.rSm),
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
            ],
          ),
        ),
      ),
    );
  }
}
