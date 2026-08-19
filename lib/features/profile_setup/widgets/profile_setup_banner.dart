import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_application_1/features/portal/widgets/ml/ml.dart';
import 'package:flutter_application_1/features/profile_setup/models/profile_setup.dart';
import 'package:flutter_application_1/features/profile_setup/providers/profile_setup_provider.dart';

/// Persistent "account setup incomplete" banner. Renders nothing when the
/// user's setup is complete with nothing expiring, so it is safe to mount
/// unconditionally (portal shell, driver dashboard). Also triggers the
/// once-per-session popup for outstanding REQUIRED items / expired documents.
class ProfileSetupBanner extends ConsumerWidget {
  const ProfileSetupBanner({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myProfileSetupProvider);
    final setup = async.valueOrNull;
    if (setup == null || !setup.isApplicable || !setup.summary.needsAttention) {
      return const SizedBox.shrink();
    }
    _maybeShowPrompt(context, ref, setup);

    final semantic = MlSemantic.of(context);
    final brightness = Theme.of(context).brightness;
    final s = setup.summary;
    final tone = s.expiredCount > 0
        ? MlTone.error
        : (s.missingCount > 0 ? MlTone.warn : MlTone.warn);

    final parts = <String>[
      if (s.missingCount > 0)
        '${s.missingCount} required item${s.missingCount == 1 ? '' : 's'} missing',
      if (s.expiredCount > 0)
        '${s.expiredCount} document${s.expiredCount == 1 ? '' : 's'} expired',
      if (s.expiringCount > 0)
        '${s.expiringCount} expiring soon',
    ];

    return Padding(
      padding: margin ?? const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Material(
        color: tone.well(brightness),
        borderRadius: BorderRadius.circular(MlTokens.rMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(MlTokens.rMd),
          onTap: () => context.go('/account-setup'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  s.expiredCount > 0
                      ? Icons.gpp_bad_outlined
                      : Icons.assignment_late_outlined,
                  size: 20,
                  color: tone.colors(brightness).fg,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account setup ${s.completionPercent}% complete',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (parts.isNotEmpty)
                        Text(
                          parts.join(' · '),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: semantic.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                MlButton.primary(
                  label: 'Complete now',
                  compact: true,
                  onPressed: () => context.go('/account-setup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Once per login session: pop the "still required" dialog when hard
  /// blockers (required missing / expired documents) exist. The session flag
  /// is only mutated inside the post-frame callback — never during build.
  void _maybeShowPrompt(
      BuildContext context, WidgetRef ref, ProfileSetup setup) {
    if (!setup.summary.hasOutstandingRequired) return;
    if (ref.read(profileSetupPromptShownProvider)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      // Re-check: several banners may schedule this in the same frame.
      if (ref.read(profileSetupPromptShownProvider)) return;
      ref.read(profileSetupPromptShownProvider.notifier).state = true;
      showDialog<void>(
        context: context,
        builder: (dialogContext) =>
            _ProfileSetupPromptDialog(setup: setup, hostContext: context),
      );
    });
  }
}

class _ProfileSetupPromptDialog extends StatelessWidget {
  const _ProfileSetupPromptDialog(
      {required this.setup, required this.hostContext});
  final ProfileSetup setup;
  final BuildContext hostContext;

  @override
  Widget build(BuildContext context) {
    final semantic = MlSemantic.of(context);
    final s = setup.summary;
    final missing = s.missingRequired.take(8).toList();

    return AlertDialog(
      title: Text(setup.isCompany
          ? 'Complete your company account setup'
          : 'Complete your account setup'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your profile is ${s.completionPercent}% complete. '
              '${s.missingCount > 0 ? '${s.missingCount} required item${s.missingCount == 1 ? ' is' : 's are'} still missing' : ''}'
              '${s.missingCount > 0 && s.expiredCount > 0 ? ' and ' : ''}'
              '${s.expiredCount > 0 ? '${s.expiredCount} document${s.expiredCount == 1 ? ' has' : 's have'} expired' : ''}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final label in missing)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.radio_button_unchecked,
                          size: 14, color: semantic.textFaint),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(label,
                            style: Theme.of(context).textTheme.bodySmall),
                      ),
                    ],
                  ),
                ),
              if (s.missingRequired.length > missing.length)
                Text('…and ${s.missingRequired.length - missing.length} more',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: semantic.textFaint)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            hostContext.go('/account-setup');
          },
          icon: const Icon(Icons.checklist_rounded, size: 18),
          label: const Text('Complete now'),
        ),
      ],
    );
  }
}
