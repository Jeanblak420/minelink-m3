import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/core/design/components/ml_components.dart';
import 'package:flutter_application_1/features/profile/providers/account_email_provider.dart';
import 'package:flutter_application_1/features/profile/widgets/change_password_section.dart';
import 'package:flutter_application_1/features/profile/widgets/deactivate_account_card.dart';
import 'package:flutter_application_1/features/profile/widgets/profile_signature_card.dart';

/// Super-admin (and any non-portal) shell: same password change UX as Profile.
///
/// Reads the account email from [accountEmailProvider] rather than from
/// `SupabaseConfig.client` directly — see that provider for why, and for what
/// the direct call cost.
class AccountSecurityScreen extends ConsumerWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(accountEmailProvider);

    // IT SAYS WHAT PAGE THIS IS.
    //
    // It did not. Both routes that mount it are leaves of a shell, and a shell
    // names the section in its top bar — but the page itself opened straight
    // into a signature card, so on the portal the reader got three unlabelled
    // cards floating in a 560px column with nothing tying them together, and no
    // sentence saying that this is where a password is changed. Photographed
    // 2026-08-21. Every other portal page opens with `MlPageHeader`.
    Widget page(Widget body) => MlPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MlPageHeader(
                title: 'Account & security',
                description: 'Your password, your signature, and closing your '
                    'account. These are personal to your login — nothing here '
                    'changes your company.',
              ),
              body,
            ],
          ),
        );

    if (email == null) {
      return page(
        const MlEmptyState(
          icon: Icons.mail_lock_outlined,
          title: 'No email address on this session',
          message: 'This account signs in another way, so there is no password '
              'to change here. Your signature and account settings are still '
              'available from your profile.',
        ),
      );
    }

    return page(
      Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChangePasswordSection(),
              SizedBox(height: 18),
              ProfileSignatureCard(),
              SizedBox(height: 18),
              DeactivateAccountCard(),
            ],
          ),
        ),
      ),
    );
  }
}
