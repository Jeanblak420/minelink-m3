import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/design/tokens/m3/ml_typography.dart';
import 'package:flutter_application_1/features/super_admin/providers/super_admin_providers.dart';
import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/core/utils/friendly_error.dart';

/// Owner-facing "Platform settings" page at `/super-admin/settings`.
///
/// The child (delegated) super-admin concept has been flattened away — both
/// super-admins are equal, full-rights (CLAUDE.md §4) — so there are no
/// delegated-admin controls left to surface here.
class PlatformAdminSettingsScreen extends ConsumerWidget {
  const PlatformAdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final roleAsync = ref.watch(currentPlatformRoleProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: roleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorBlock(message: 'Error. ${friendlyError(e)}'),
          data: (role) {
            if (!role.isSuperAdmin) {
              return const _OwnerOnlyPlaceholder();
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Platform settings',
                  style: context.mlText.titleLarge.copyWith(
                    color: MlSemantic.of(context).textStrong,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Both super-admins have identical, full rights. There are '
                  'no delegated-admin controls to configure.',
                  style: TextStyle(
                    fontFamily: MlTokens.fontSans,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OwnerOnlyPlaceholder extends StatelessWidget {
  const _OwnerOnlyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const MlEmptyState(
      icon: Icons.lock_outline,
      title: 'Owner only',
      message: 'Platform settings are visible only to the super admin.',
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  const _ErrorBlock({required this.message});

  @override
  Widget build(BuildContext context) {
    return MlEmptyState(
      icon: Icons.error_outline,
      title: 'Something went wrong',
      message: message,
    );
  }
}
