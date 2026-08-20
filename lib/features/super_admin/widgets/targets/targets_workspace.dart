import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/super_admin/data/models/target_scope.dart';
import 'package:flutter_application_1/features/super_admin/data/repositories/targets_controller.dart';
import 'package:flutter_application_1/features/super_admin/providers/targets_provider.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_screen_targets.dart';
import 'package:flutter_application_1/features/super_admin/widgets/insights_v2/minelink_targets_core.dart';
import 'package:flutter_application_1/core/design/tokens/ml_surface_tokens.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Live wiring for [MineLinkTargetsScreen], shared by all three scopes.
///
/// The screen is deliberately stateless about persistence: every edit calls out
/// here, this writes it, and fresh data comes back down the provider. Nothing
/// is held optimistically, so a value the server rejects is never left on
/// screen as though it had been accepted.
///
/// Each scope supplies its own chrome above this — see the three screens under
/// `screens/targets_*`.
class TargetsWorkspace extends ConsumerStatefulWidget {
  const TargetsWorkspace({super.key, required this.scope});

  final TargetScope scope;

  @override
  ConsumerState<TargetsWorkspace> createState() => _TargetsWorkspaceState();
}

class _TargetsWorkspaceState extends ConsumerState<TargetsWorkspace> {
  StreamSubscription<TargetsWriteResult>? _writes;

  /// Refusals by target key — `m:2026-09`, `h:d7` — so each dial can show the
  /// reason next to the value that was refused, and keep the typed figure for
  /// correcting. Cleared per key on the next write that succeeds.
  final Map<String, String> _refusals = <String, String>{};

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant TargetsWorkspace old) {
    super.didUpdateWidget(old);
    if (old.scope != widget.scope) {
      _refusals.clear();
      _listen();
    }
  }

  /// Write timing, coalescing and retry state all live in the controller. This
  /// widget's only job on the write path is to say what went wrong, and where.
  void _listen() {
    _writes?.cancel();
    _writes = ref
        .read(targetsControllerProvider(widget.scope))
        .writes
        .listen((result) {
      if (!mounted) return;
      setState(() {
        if (result.key == null) return;
        if (result.ok) {
          _refusals.remove(result.key);
        } else {
          _refusals[result.key!] = result.message;
        }
      });
      // The dial carries the reason for a target it owns; the notice is for
      // whole-cycle actions, which belong to no single dial.
      if (!result.ok && result.key == null) _explain(result.message);
    });
  }

  @override
  void dispose() {
    _writes?.cancel();
    super.dispose();
  }

  /// Surfaces the server's own wording. These messages are written to be read
  /// by a person — "Cycle Aug 2026 → Jul 2027 is locked until 01 Aug 2027" —
  /// so passing them through beats inventing a generic failure notice.
  void _explain(String message) {
    final t = MlGlass.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: t.panel,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          content: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 16, color: t.warn),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: context.mlText.bodyMedium.copyWith(color: t.inkHi),
                ),
              ),
            ],
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final t = MlGlass.of(context);
    final scope = widget.scope;
    final controller = ref.watch(targetsControllerProvider(scope));
    final async = ref.watch(targetsProvider(scope));

    return async.when(
      loading: () => Container(
        color: t.bg0,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(),
      ),
      error: (e, _) => TargetsError(
        message: friendlyError(e),
        onRetry: () => ref.invalidate(targetsProvider(scope)),
      ),
      data: (data) => MineLinkTargetsScreen(
        data: data,
        onMonthTargetChanged: controller.setMonthTarget,
        onHorizonDraftChanged: controller.setHorizonDraft,
        onLockCycle: (targets) => unawaited(controller.lockCycle(targets)),
        onStartNewCycle: () => unawaited(controller.startNewCycle()),
        errorFor: (key) => _refusals[key],
      ),
    );
  }
}

/// Shared failure state — the console's own idiom rather than a bare error.
class TargetsError extends StatelessWidget {
  const TargetsError({
    super.key,
    required this.message,
    required this.onRetry,
    this.title = "Couldn't load targets",
  });

  final String message;
  final VoidCallback onRetry;
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = MlGlass.of(context);
    return Container(
      color: t.bg0,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 34, color: t.bad),
          const SizedBox(height: 12),
          Text(
            title,
            style: context.mlText.titleMedium.copyWith(
              color: t.inkHi,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.mlText.bodySmall.copyWith(color: t.inkMid),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// Month-to-date headline for a scope, used by the scope-specific chrome.
///
/// Reads the same [MlTargetsData] the screen below is rendering, so the band
/// and the dials can never disagree.
@immutable
class TargetsHeadline {
  const TargetsHeadline({
    required this.periodLabel,
    required this.actual,
    required this.target,
    required this.outcome,
    required this.elapsedDays,
    required this.cycleLabel,
    required this.cycleLocked,
  });

  final String periodLabel;
  final double actual;
  final double target;
  final MlTargetOutcome outcome;
  final int elapsedDays;
  final String cycleLabel;
  final bool cycleLocked;

  double get attainment => target <= 0 ? 0 : actual / target;

  static TargetsHeadline of(MlTargetsData data) {
    final month = data.months.isEmpty
        ? null
        : data.months[data.currentIndex.clamp(0, data.months.length - 1)];
    return TargetsHeadline(
      periodLabel: month?.label ?? '—',
      actual: month?.total ?? 0,
      target: month?.target ?? 0,
      outcome: month?.outcome ?? MlTargetOutcome.none,
      elapsedDays: data.elapsedCycleDays,
      cycleLabel: data.cycle.label,
      cycleLocked: data.cycle.isLocked,
    );
  }
}
