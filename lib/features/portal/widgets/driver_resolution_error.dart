import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/design/components/ml_empty_state.dart';

/// Shown on a driver screen when its trip / assignment data could not be
/// resolved because a query failed (RLS denial, dropped connection, schema
/// drift). This exists so a real error is never silently rendered as an idle
/// "no active trip / no truck assigned" state — the two are indistinguishable
/// to the driver otherwise. Offers a retry that re-runs the failed providers.
class DriverResolutionError extends StatelessWidget {
  final VoidCallback onRetry;

  const DriverResolutionError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return MlEmptyState(
      icon: Icons.cloud_off_rounded,
      title: "Couldn't load your trip",
      message: 'We could not reach the server to load your assignment. '
          'Check your connection and try again.',
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Retry'),
      ),
    );
  }
}
