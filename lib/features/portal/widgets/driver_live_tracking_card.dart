import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/providers/live_tracking_provider.dart';
import 'package:flutter_application_1/features/portal/services/trip_position_reporter.dart';
import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';

/// The driver's live GPS-sharing toggle (30s pings via
/// [tripPositionReporterProvider]). Extracted from DriverRoutesScreen so the
/// driver Dashboard tab (3-tab shell, spec 2026-07-16 §5) can reuse it.
class DriverLiveTrackingCard extends ConsumerWidget {
  final bool hasActiveTrip;
  const DriverLiveTrackingCard({required this.hasActiveTrip, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reporter = ref.watch(tripPositionReporterProvider);
    final semantic = MlSemantic.of(context);
    final status = reporter.status;
    final isError = status == TripReportingStatus.error;

    final String subtitle;
    switch (status) {
      case TripReportingStatus.active:
        final last = reporter.lastPingAt;
        subtitle = reporter.message ??
            (last == null
                ? 'Sharing every 30 seconds…'
                : 'Sharing every 30 seconds · last ping '
                    '${TimeOfDay.fromDateTime(MlTime.sast(last)).format(context)}');
      case TripReportingStatus.starting:
        subtitle = reporter.message ?? 'Starting…';
      case TripReportingStatus.error:
        subtitle = reporter.message ?? 'GPS error.';
      case TripReportingStatus.off:
        subtitle = reporter.message ??
            (hasActiveTrip
                ? 'Turn on so the mine, buyer and your admin can follow your '
                    'truck on the live map.'
                : 'Available once you have an active trip.');
    }

    return MlCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          MlIconWell(
            icon: reporter.isActive ? Icons.gps_fixed : Icons.gps_off_outlined,
            tone: reporter.isActive
                ? MlTone.done
                : isError
                    ? MlTone.error
                    : MlTone.neutral,
            size: 40,
            radius: 12,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Live location sharing',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isError
                            ? Theme.of(context).colorScheme.error
                            : semantic.textMuted,
                      ),
                ),
              ],
            ),
          ),
          Switch(
            value: reporter.isBusy,
            onChanged: (v) {
              if (v) {
                reporter.start();
              } else {
                reporter.stop(message: 'Live tracking turned off.');
              }
            },
          ),
        ],
      ),
    );
  }
}
