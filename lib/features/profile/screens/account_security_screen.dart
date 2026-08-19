import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/profile/widgets/change_password_section.dart';
import 'package:flutter_application_1/features/profile/widgets/deactivate_account_card.dart';
import 'package:flutter_application_1/features/profile/widgets/profile_signature_card.dart';

/// Super-admin (and any non-portal) shell: same password change UX as Profile.
class AccountSecurityScreen extends StatelessWidget {
  const AccountSecurityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final email = SupabaseConfig.client.auth.currentUser?.email?.trim();
    if (email == null || email.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'No email address is associated with this session, so password change is not available.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
