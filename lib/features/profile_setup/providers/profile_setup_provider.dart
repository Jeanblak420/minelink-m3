import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/profile_setup/models/profile_setup.dart';
import 'package:flutter_application_1/features/profile_setup/services/profile_setup_service.dart';

/// The signed-in user's own account-setup state. Invalidate after any field
/// save, document upsert, photo upload, or signature change. Watches auth so
/// it never leaks across logins.
final myProfileSetupProvider =
    FutureProvider.autoDispose<ProfileSetup>((ref) async {
  final auth = ref.watch(authStateProvider);
  if (auth.user == null) {
    return const ProfileSetup(items: [], summary: ProfileSetupSummary.empty);
  }
  return ref.watch(profileSetupServiceProvider).fetch();
});

/// A specific employee's setup state, for the employer view (manager/platform
/// admin — the RPC authorizes server-side).
final employeeProfileSetupProvider =
    FutureProvider.family.autoDispose<ProfileSetup, String>(
  (ref, employeeId) =>
      ref.watch(profileSetupServiceProvider).fetch(employeeId: employeeId),
);

/// Session flag so the "complete your account setup" popup shows at most once
/// per login session.
final profileSetupPromptShownProvider = StateProvider<bool>((ref) {
  ref.watch(authStateProvider.select((s) => s.user?.id));
  return false;
});
