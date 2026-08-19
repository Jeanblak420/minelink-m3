import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/features/profile_setup/models/profile_setup.dart';
import 'package:flutter_application_1/features/profile_setup/providers/profile_setup_provider.dart';

/// Employer view of an employee's account-setup state (percent + outstanding
/// items), fed by the manager-authorized `get_profile_setup(employee_id)`.
/// Renders nothing while loading/on error so it can sit in the live profile
/// without adding failure states.
class ProfileSetupEmployerCard extends ConsumerWidget {
  const ProfileSetupEmployerCard({super.key, required this.employeeId});
  final String employeeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(employeeProfileSetupProvider(employeeId));
    final setup = async.valueOrNull;
    if (setup == null || !setup.isApplicable) return const SizedBox.shrink();

    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final s = setup.summary;
    final tone = s.expiredCount > 0
        ? MlTone.error
        : s.missingCount > 0
            ? MlTone.warn
            : s.expiringCount > 0
                ? MlTone.warn
                : MlTone.done;

    final outstanding = [
      for (final i in setup.items)
        if (i.status.needsAction && i.isRequired) i,
    ];
    final expiringOrExpired = [
      for (final i in setup.items)
        if (i.status == SetupItemStatus.expired ||
            i.status == SetupItemStatus.expiring)
          i,
    ];

    return MlCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MlSectionTitle('Profile setup',
                    icon: Icons.checklist_rounded,
                    // The badge beside this says how *complete* the setup is;
                    // the meta says what is actually outstanding, which is the
                    // number the employer acts on.
                    meta: outstanding.isEmpty && expiringOrExpired.isEmpty
                        ? 'Nothing outstanding'
                        : mlCount(
                            outstanding.length + expiringOrExpired.length,
                            'item needs attention',
                            'items need attention'),
                    margin: EdgeInsets.zero),
              ),
              MlStatusBadge(
                label: s.hasOutstandingRequired
                    ? '${s.completionPercent}% complete'
                    : (s.expiringCount > 0 ? 'Renewals due' : 'Complete'),
                tone: tone,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(MlTokens.rPill),
            child: LinearProgressIndicator(
              value: s.completionPercent / 100,
              minHeight: 6,
              backgroundColor: semantic.surfaceSunken,
              valueColor: AlwaysStoppedAnimation(tone.colors(brightness).fg),
            ),
          ),
          if (outstanding.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Still outstanding',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: semantic.textFaint)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final i in outstanding)
                  MlStatusBadge(label: i.label, tone: _chipTone(i)),
              ],
            ),
          ],
          if (expiringOrExpired.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final i in expiringOrExpired)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    Icon(
                      i.status == SetupItemStatus.expired
                          ? Icons.gpp_bad_outlined
                          : Icons.schedule_rounded,
                      size: 14,
                      color: (i.status == SetupItemStatus.expired
                              ? MlTone.error
                              : MlTone.warn)
                          .colors(brightness)
                          .fg,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${i.label} — ${_expiryText(i)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: semantic.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (!s.needsAttention) ...[
            const SizedBox(height: 8),
            Text(
              'All required items are in place and nothing is close to expiry.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: semantic.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  MlTone _chipTone(ProfileSetupItem i) => switch (i.status) {
        SetupItemStatus.expired => MlTone.error,
        _ => MlTone.warn,
      };

  String _expiryText(ProfileSetupItem i) {
    final days = i.daysToExpiry;
    if (days == null) return i.status.label;
    if (days < 0) return 'expired ${-days} day${days == -1 ? '' : 's'} ago';
    if (days == 0) return 'expires today';
    return 'expires in $days day${days == 1 ? '' : 's'}';
  }
}
