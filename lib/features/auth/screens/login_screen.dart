import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/core/routing/app_router.dart';
import 'package:flutter_application_1/core/theme/app_theme.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';
import 'package:flutter_application_1/features/auth/utils/whatsapp_identity.dart';
import 'package:flutter_application_1/features/auth/widgets/signin/minelink_signin_fields.dart';
import 'package:flutter_application_1/features/auth/widgets/signin/minelink_signin_screen.dart';
import 'package:flutter_application_1/features/auth/widgets/signin/platform_reduce_motion.dart';

/// Sign-in. The look is the 2026-08-10 sign-in drop
/// (`widgets/signin/minelink_signin_*.dart`); this file is the only wiring
/// between it and MineLink's auth layer.
///
/// The screen holds no session state — every credential leaves through a
/// callback and comes back as either null (signed in) or the message to show.
/// So all this file does is translate `AuthStateNotifier`'s
/// set-the-error-on-state contract into that return-the-message one.
///
/// Two things worth knowing before changing anything here:
///
/// **The router, not this screen, chooses where you land.** `AppRouter`'s
/// `refreshListenable` is bound to `onAuthStateChange`, so the moment a session
/// exists the redirect re-runs, sees `/login`, and sends a platform admin to
/// `/super-admin`, a company user owing a password change to
/// `/mandatory-password-change`, and everyone else to `/home`. That is strictly
/// better than a hardcoded destination here, so it is left alone. The success
/// overlay renders in the gap while the redirect awaits its profile-gate read;
/// [MineLinkSignInScreen.onSignedIn] fires 900 ms later and is only a safety
/// net — by then the screen is normally already unmounted, which suppresses it.
///
/// **`AuthShell` is still live.** `/forgot-password` and `/reset-password` use
/// it. Only this screen moved.
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auth is always dark, whatever `themeModeProvider` says — same rule the
    // shell it replaces applied. The drop paints its own surfaces, but the
    // Material bits inside it (text selection, icon splashes, autofill) still
    // resolve against the ambient theme, and on light they would fight a dark
    // card.
    // Feed the browser's `prefers-reduced-motion` in on web, where Flutter does
    // not (see `platform_reduce_motion.dart`). Without this the panel animates
    // for someone who asked their system not to, and the screen's "Animation is
    // switched off — Play anyway" card can never appear because nothing ever
    // tells it motion was suppressed. Only ever adds the suppression; it cannot
    // turn motion on where MediaQuery says off.
    final media = MediaQuery.of(context);
    final reduce = media.disableAnimations || (platformReduceMotion() ?? false);

    return MediaQuery(
      data: media.copyWith(disableAnimations: reduce),
      child: Theme(
        data: AppTheme.darkTheme,
        child: MineLinkSignInScreen(
          onPasswordSignIn: (identity, password, remember) =>
              _signIn(ref, identity, password),
          // WhatsApp codes are real here (Supabase phone auth + the
          // `whatsapp-send-otp` Send-SMS hook), so both callbacks are passed
          // and the path stays. Were they null the button, the code view and
          // the resend timer would all disappear rather than pretend.
          onRequestWhatsAppCode: (identity) => _requestCode(ref, identity),
          onVerifyWhatsAppCode: (identity, code) =>
              _verifyCode(ref, identity, code),
          onForgotPassword: () => AppRouter.router.go('/forgot-password'),
          onSignedIn: () => AppRouter.router.go('/home'),
        ),
      ),
    );
  }

  static Future<String?> _signIn(
    WidgetRef ref,
    String identity,
    String password,
  ) async {
    final id = identity.trim();
    // Admin-created Mine/Supplier users have no mailbox — they are identified
    // by WhatsApp number and registered against a deterministic synthetic
    // email. Same derivation as at creation, so the credential matches.
    final email = looksLikeEmail(id) ? id : whatsappAuthEmail(id);
    if (email.isEmpty) {
      return 'Enter your email address or WhatsApp number.';
    }

    final notifier = ref.read(authStateProvider.notifier);
    notifier.clearError();
    await notifier.signIn(email: email, password: password);

    // Succeeding is exactly what unmounts this screen: the sign-in flips
    // `onAuthStateChange`, the router redirects off `/login`, and `ref` then
    // throws `StateError` instead of reporting. Null means "no error to show",
    // which is the truth — we only got here by signing in.
    if (!ref.context.mounted) return null;
    final state = ref.read(authStateProvider);
    // `user` is checked first on purpose: `_syncAuthState` sets an error
    // *alongside* a real user when the follow-up profile read fails, and that
    // is a signed-in state — refusing it would strand someone who is in.
    if (state.user != null) return null;
    return state.error ?? 'Unable to sign in right now. Please try again.';
  }

  static Future<String?> _requestCode(WidgetRef ref, String identity) async {
    final id = identity.trim();
    // Ask the field, rather than re-deriving the rule: it is the single
    // authority on what counts as a usable identity.
    if (MlIdentityField.read(id) != MlIdentityKind.phone) {
      return 'Enter your WhatsApp number to receive a code.';
    }

    final notifier = ref.read(authStateProvider.notifier);
    notifier.clearError();
    try {
      await notifier.sendWhatsappOtp(id);
      return null;
    } catch (_) {
      // `sendWhatsappOtp` rethrows after putting the server's own wording on
      // the state; prefer that to anything invented here.
      if (!ref.context.mounted) return null;
      return ref.read(authStateProvider).error ??
          'We could not send a code to that number. Please try again.';
    }
  }

  static Future<String?> _verifyCode(
    WidgetRef ref,
    String identity,
    String code,
  ) async {
    final notifier = ref.read(authStateProvider.notifier);
    notifier.clearError();
    // Goes through the notifier, not `AuthService`, because this is also what
    // stamps `DeviceVerificationStore` — without it the router's WhatsApp
    // re-verification gate would bounce the user straight back out to
    // `/whatsapp-otp` having just entered a code.
    final ok = await notifier.verifyWhatsappOtp(
      whatsappNumber: identity.trim(),
      token: code,
    );
    if (ok) return null;
    // A rejected code leaves the screen up, so this is normally safe; guard it
    // anyway so a redirect racing the verify cannot turn a refusal into a crash.
    if (!ref.context.mounted) return null;
    return ref.read(authStateProvider).error ??
        'That code was not accepted. Please try again.';
  }
}
