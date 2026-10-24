import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/core/time/ml_time.dart';
import 'package:flutter_application_1/features/super_admin/data/models/device_checkin_row.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';

/// The Crash reports page's "Devices" line and its list (Jean's go-ahead,
/// 2026-10-24). Every signed-in install checks in once a day
/// (`DeviceCheckin`), through the same authenticated path the crash sink
/// writes on. A device that checked in today could have reported a crash; a
/// quiet one is worth a look before a quiet crash table is believed.

/// A device has gone quiet when it has not checked in for this long. A day's
/// grace on top of the daily check-in, and another for a weekend off.
const kDeviceQuietAfter = Duration(days: 3);

({int today, int quiet}) deviceCheckinCounts(
    List<DeviceCheckinRow> rows, DateTime now) {
  var today = 0, quiet = 0;
  for (final r in rows) {
    final age = now.difference(r.lastSeenAt);
    if (age < const Duration(hours: 24)) today++;
    if (age >= kDeviceQuietAfter) quiet++;
  }
  return (today: today, quiet: quiet);
}

String deviceCheckinSummary(List<DeviceCheckinRow> rows, DateTime now) {
  if (rows.isEmpty) return 'No device has checked in yet.';
  final c = deviceCheckinCounts(rows, now);
  final today = '${mlCount(c.today, 'device')} checked in today';
  return c.quiet == 0
      ? today
      : '$today · ${c.quiet} quiet for ${kDeviceQuietAfter.inDays}+ days';
}

/// The one line under "Last report received", with the way into the list.
class DeviceCheckinsLine extends ConsumerWidget {
  const DeviceCheckinsLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(deviceCheckinsProvider);
    final muted = context.mlText.bodySmall
        .copyWith(color: MlSemantic.of(context).textMuted);
    return async.when(
      loading: () => Text('Devices: checking…', style: muted),
      error: (_, __) => Text('Devices: could not load the check-ins.',
          style: muted),
      data: (rows) {
        final now = MlTime.instant();
        return Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Devices: ${deviceCheckinSummary(rows, now)}', style: muted),
            if (rows.isNotEmpty)
              MlButton.outline(
                label: 'Show devices',
                icon: Icons.devices_outlined,
                compact: true,
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => FractionallySizedBox(
                    heightFactor: 0.85,
                    child: DeviceCheckinList(rows: rows, now: now),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Every device, most recent first: who last used it, what it runs, when it
/// last checked in, and whether it has gone quiet.
class DeviceCheckinList extends StatelessWidget {
  const DeviceCheckinList({super.key, required this.rows, required this.now});

  final List<DeviceCheckinRow> rows;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final s = MlSemantic.of(context);
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      itemCount: rows.length + 1,
      separatorBuilder: (_, i) =>
          i == 0 ? const SizedBox(height: 12) : Divider(color: s.divider),
      itemBuilder: (context, i) {
        if (i == 0) {
          return MlPageHeader(
            title: 'Devices',
            description: 'Each signed-in install checks in once a day. '
                'Quiet means no check-in for '
                '${kDeviceQuietAfter.inDays} days or more.',
            meta: mlCount(rows.length, 'device'),
            padding: EdgeInsets.zero,
          );
        }
        final r = rows[i - 1];
        final age = now.difference(r.lastSeenAt);
        final badge = age < const Duration(hours: 24)
            ? const MlStatusBadge(label: 'Today', tone: MlTone.done)
            : age >= kDeviceQuietAfter
                ? MlStatusBadge(
                    label: 'Quiet ${mlCount(age.inDays, 'day')}',
                    tone: MlTone.warn)
                : null;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.userLabel ?? 'No one signed in',
                      style: context.mlText.titleSmall
                          .copyWith(color: s.textStrong),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        r.platform,
                        if (r.appVersion != null) 'v${r.appVersion}',
                        'last check-in ${MlTime.ago(r.lastSeenAt, asOf: now)}',
                      ].join(' · '),
                      style: context.mlText.bodySmall
                          .copyWith(color: s.textMuted),
                    ),
                  ],
                ),
              ),
              if (badge != null) ...[const SizedBox(width: 12), badge],
            ],
          ),
        );
      },
    );
  }
}
