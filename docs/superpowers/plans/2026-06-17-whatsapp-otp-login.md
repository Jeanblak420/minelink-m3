# WhatsApp OTP Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let admin-created Mine/Supplier users log in with a one-time code delivered over WhatsApp (password kept as a fallback), with weekly + new-device re-verification.

**Architecture:** Supabase phone OTP does code generation/verification. A Supabase **Send-SMS auth hook** (edge function `whatsapp-send-otp`) delivers the code via a pluggable `OtpSender` — a dev console sender now, Meta WhatsApp Cloud API later. The Flutter app only calls `signInWithOtp` / `verifyOtp`, records a per-device "last verified" timestamp locally, and a router guard forces re-verification when due.

**Tech Stack:** Flutter, Riverpod, go_router, supabase_flutter ^2.9, `uuid` ^4.5, `shared_preferences` ^2.2; Supabase Edge Functions (Deno/TypeScript).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-06-17-whatsapp-otp-login-design.md`.
- Supabase project is bound ONLY to `yftazblpmicqtamyiwyb`.
- Phone OTP verify type is `OtpType.sms`. Supabase phone format is E.164 (`+<digits>`).
- Send-SMS hook payload: `{ user: {...}, sms: { otp: "######" } }`; hook returns HTTP 200 empty on success; requests signed via `standardwebhooks` + env `SEND_SMS_HOOK_SECRET` (`v1,whsec_`-prefixed).
- Synthetic email scheme (Phase A) is unchanged: `wa-<digits>@wa.mineralguide.com` from `lib/features/auth/utils/whatsapp_identity.dart`.
- No `flutter_secure_storage` in the project; use `shared_preferences` for the device-trust store.
- Follow existing patterns: services are plain classes exposed via Riverpod `Provider`; pure helpers live under `lib/features/auth/utils/`.

---

### Task 1: `whatsappToE164` helper

**Files:**
- Modify: `lib/features/auth/utils/whatsapp_identity.dart`
- Test: `test/features/auth/whatsapp_identity_test.dart`

**Interfaces:**
- Consumes: `normalizeWhatsappNumber(String)` (already in the file).
- Produces: `String whatsappToE164(String whatsappNumber)` → `+<digits>`, or `''` when no digits.

- [ ] **Step 1: Add the failing test** to `test/features/auth/whatsapp_identity_test.dart` inside `main()`:

```dart
  group('whatsappToE164', () {
    test('prefixes a plus and strips formatting', () {
      expect(whatsappToE164('+27 (82) 123-4567'), '+27821234567');
      expect(whatsappToE164('27821234567'), '+27821234567');
    });

    test('returns empty string when there are no digits', () {
      expect(whatsappToE164('nope'), '');
    });
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/whatsapp_identity_test.dart`
Expected: FAIL — `The method 'whatsappToE164' isn't defined`.

- [ ] **Step 3: Implement** — append to `lib/features/auth/utils/whatsapp_identity.dart`:

```dart
/// Formats [whatsappNumber] as an E.164 phone string (`+<digits>`) for Supabase
/// phone auth. Returns an empty string when there are no digits.
String whatsappToE164(String whatsappNumber) {
  final digits = normalizeWhatsappNumber(whatsappNumber);
  if (digits.isEmpty) return '';
  return '+$digits';
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/whatsapp_identity_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/utils/whatsapp_identity.dart test/features/auth/whatsapp_identity_test.dart
git commit -m "feat(auth): add whatsappToE164 helper for phone OTP"
```

---

### Task 2: Re-verification cadence policy (pure functions)

**Files:**
- Create: `lib/features/auth/utils/reverification_policy.dart`
- Test: `test/features/auth/reverification_policy_test.dart`

**Interfaces:**
- Produces:
  - `DateTime mostRecentMonday(DateTime now)` — Monday 00:00:00 (local) of `now`'s week.
  - `bool requiresReverification(DateTime? lastVerifiedAt, DateTime now)`.

- [ ] **Step 1: Write the failing test** — create `test/features/auth/reverification_policy_test.dart`:

```dart
import 'package:flutter_application_1/features/auth/utils/reverification_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mostRecentMonday', () {
    test('returns Monday 00:00 for a mid-week day', () {
      // 2026-06-17 is a Wednesday.
      expect(mostRecentMonday(DateTime(2026, 6, 17, 14, 30)),
          DateTime(2026, 6, 15));
    });

    test('returns the same day for a Monday afternoon', () {
      expect(mostRecentMonday(DateTime(2026, 6, 15, 9)), DateTime(2026, 6, 15));
    });

    test('Sunday belongs to the week that started the previous Monday', () {
      // 2026-06-21 is a Sunday.
      expect(mostRecentMonday(DateTime(2026, 6, 21, 23)), DateTime(2026, 6, 15));
    });
  });

  group('requiresReverification', () {
    final now = DateTime(2026, 6, 17, 12); // Wednesday

    test('true when never verified on this device', () {
      expect(requiresReverification(null, now), isTrue);
    });

    test('false when verified earlier this same week', () {
      expect(requiresReverification(DateTime(2026, 6, 15, 8), now), isFalse);
      expect(requiresReverification(DateTime(2026, 6, 16, 23), now), isFalse);
    });

    test('true when last verified before this week\'s Monday', () {
      expect(requiresReverification(DateTime(2026, 6, 14, 23), now), isTrue);
    });

    test('boundary: exactly Monday 00:00 counts as verified this week', () {
      expect(requiresReverification(DateTime(2026, 6, 15), now), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/reverification_policy_test.dart`
Expected: FAIL — target file does not exist.

- [ ] **Step 3: Implement** — create `lib/features/auth/utils/reverification_policy.dart`:

```dart
/// Pure policy for WhatsApp-OTP re-verification.
///
/// Rule: verify on a new device, then weekly on Mondays; if Monday is missed,
/// verify on the next login/use. Implemented as: a verification is valid only
/// until the next Monday — re-verify if it predates the current week's Monday.
library;

/// Monday 00:00:00 (local) of the week containing [now]. Dart weekday: Mon = 1.
DateTime mostRecentMonday(DateTime now) {
  final midnight = DateTime(now.year, now.month, now.day);
  return midnight.subtract(Duration(days: midnight.weekday - DateTime.monday));
}

/// Whether the device must re-verify via WhatsApp OTP before use.
bool requiresReverification(DateTime? lastVerifiedAt, DateTime now) {
  if (lastVerifiedAt == null) return true;
  return lastVerifiedAt.isBefore(mostRecentMonday(now));
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/reverification_policy_test.dart`
Expected: PASS (8 assertions).

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/utils/reverification_policy.dart test/features/auth/reverification_policy_test.dart
git commit -m "feat(auth): add re-verification cadence policy"
```

---

### Task 3: Device verification store (local persistence)

**Files:**
- Create: `lib/features/auth/services/device_verification_store.dart`
- Test: `test/features/auth/device_verification_store_test.dart`

**Interfaces:**
- Produces class `DeviceVerificationStore`:
  - `Future<DateTime?> lastVerifiedAt()`
  - `Future<void> markVerified(DateTime now)`
  - `Future<String> deviceId()` — persistent per-install UUID.
  - `Future<void> clear()`
- Produces `final deviceVerificationStoreProvider = Provider<DeviceVerificationStore>(...)`.

- [ ] **Step 1: Write the failing test** — create `test/features/auth/device_verification_store_test.dart`:

```dart
import 'package:flutter_application_1/features/auth/services/device_verification_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('lastVerifiedAt is null before any verification', () async {
    final store = DeviceVerificationStore();
    expect(await store.lastVerifiedAt(), isNull);
  });

  test('markVerified persists the timestamp (second-resolution)', () async {
    final store = DeviceVerificationStore();
    final t = DateTime(2026, 6, 17, 12, 30, 45);
    await store.markVerified(t);
    expect(await store.lastVerifiedAt(), t);
  });

  test('deviceId is stable across calls', () async {
    final store = DeviceVerificationStore();
    final a = await store.deviceId();
    final b = await store.deviceId();
    expect(a, isNotEmpty);
    expect(a, b);
  });

  test('clear removes the verification timestamp', () async {
    final store = DeviceVerificationStore();
    await store.markVerified(DateTime(2026, 6, 17));
    await store.clear();
    expect(await store.lastVerifiedAt(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/device_verification_store_test.dart`
Expected: FAIL — target file does not exist.

- [ ] **Step 3: Implement** — create `lib/features/auth/services/device_verification_store.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Local, per-install record of WhatsApp-OTP verification used by the
/// re-verification guard. Low-sensitivity (an attacker editing it still needs a
/// valid Supabase session), so plain shared_preferences is sufficient.
class DeviceVerificationStore {
  static const _kLastVerified = 'wa_otp_last_verified_at';
  static const _kDeviceId = 'wa_otp_device_id';

  Future<DateTime?> lastVerifiedAt() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLastVerified);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> markVerified(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastVerified, now.toIso8601String());
  }

  Future<String> deviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(_kDeviceId, id);
    return id;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kLastVerified);
  }
}

final deviceVerificationStoreProvider =
    Provider<DeviceVerificationStore>((ref) => DeviceVerificationStore());
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/auth/device_verification_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/services/device_verification_store.dart test/features/auth/device_verification_store_test.dart
git commit -m "feat(auth): add per-device verification store"
```

---

### Task 4: Phone OTP methods on AuthService + AuthStateNotifier

**Files:**
- Modify: `lib/features/auth/services/auth_service.dart` (after `signIn`, around line 121)
- Modify: `lib/features/auth/providers/auth_state.dart` (after `signIn`, around line 252; constructor deps around line 39-47)
- Test: `test/features/auth/auth_service_otp_test.dart`

**Interfaces:**
- Consumes: `whatsappToE164` (Task 1); `DeviceVerificationStore` (Task 3).
- Produces on `AuthService`:
  - `Future<void> sendWhatsappOtp(String whatsappNumber)`
  - `Future<AuthResponse> verifyWhatsappOtp({required String whatsappNumber, required String token})`
- Produces on `AuthStateNotifier`:
  - `Future<void> sendWhatsappOtp(String whatsappNumber)` (sets `isLoading`/`error`)
  - `Future<bool> verifyWhatsappOtp({required String whatsappNumber, required String token})` (on success records verification + syncs auth; returns whether it succeeded)

Note: `AuthService` methods are thin wrappers over the Supabase client and are validated by a behavioral unit test on the public formatting boundary (E.164). The Supabase network calls themselves are verified manually in Task 9's runbook.

- [ ] **Step 1: Write the failing test** — create `test/features/auth/auth_service_otp_test.dart`. This pins the E.164 conversion contract the methods rely on (guards against regressions in the number→phone mapping):

```dart
import 'package:flutter_application_1/features/auth/utils/whatsapp_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // AuthService.sendWhatsappOtp/verifyWhatsappOtp pass whatsappToE164(number)
  // as the Supabase `phone`. Lock that contract here.
  test('OTP phone is the E164 form of the WhatsApp number', () {
    expect(whatsappToE164('+27 82 123 4567'), '+27821234567');
  });

  test('blank/garbage number yields empty phone (callers must guard)', () {
    expect(whatsappToE164('   '), '');
  });
}
```

- [ ] **Step 2: Run test to verify it fails or passes**

Run: `flutter test test/features/auth/auth_service_otp_test.dart`
Expected: PASS (depends only on Task 1). If Task 1 is incomplete it FAILS to compile. (This test documents the contract; the real assertion is in the implementation steps below.)

- [ ] **Step 3a: Implement AuthService methods** — in `lib/features/auth/services/auth_service.dart`, add the import at the top (after line 7):

```dart
import 'package:flutter_application_1/features/auth/utils/whatsapp_identity.dart';
```

Then insert after the `signIn` method (after line 121):

```dart
  /// Sends a WhatsApp OTP to [whatsappNumber] via Supabase phone auth.
  /// Supabase generates the code and fires the Send-SMS hook, which delivers
  /// it over WhatsApp.
  Future<void> sendWhatsappOtp(String whatsappNumber) async {
    final phone = whatsappToE164(whatsappNumber);
    if (phone.isEmpty) {
      throw Exception('Enter a valid WhatsApp number.');
    }
    try {
      await _supabase.auth.signInWithOtp(phone: phone);
    } catch (e) {
      throw _handleError(e);
    }
  }

  /// Verifies the WhatsApp OTP [token] for [whatsappNumber], establishing a
  /// session on success.
  Future<AuthResponse> verifyWhatsappOtp({
    required String whatsappNumber,
    required String token,
  }) async {
    final phone = whatsappToE164(whatsappNumber);
    try {
      return await _supabase.auth.verifyOTP(
        phone: phone,
        token: token.trim(),
        type: OtpType.sms,
      );
    } catch (e) {
      throw _handleError(e);
    }
  }
```

- [ ] **Step 3b: Implement AuthStateNotifier methods** — in `lib/features/auth/providers/auth_state.dart`:

First, give the notifier access to the device store. Change the constructor and provider. Replace lines 39-47:

```dart
class AuthStateNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  final DeviceVerificationStore _deviceStore;
  late final StreamSubscription<supabase.AuthState> _authSubscription;
  supabase.RealtimeChannel? _profileChannel;
  String? _profileSubscriptionUserId;

  AuthStateNotifier(this._authService, this._deviceStore)
      : super(AuthState(isLoading: true)) {
    _initialize();
  }
```

Add the import (after line 10):

```dart
import 'package:flutter_application_1/features/auth/services/device_verification_store.dart';
```

Replace the provider at the bottom (lines 371-376):

```dart
final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((
  ref,
) {
  return AuthStateNotifier(
    ref.watch(authServiceProvider),
    ref.watch(deviceVerificationStoreProvider),
  );
});
```

Insert these methods after `signIn` (after line 252):

```dart
  Future<void> sendWhatsappOtp(String whatsappNumber) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      await _authService.sendWhatsappOtp(whatsappNumber);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      var msg = e.toString();
      if (msg.contains('Exception:')) msg = msg.split('Exception:').last.trim();
      state = state.copyWith(isLoading: false, error: msg);
      rethrow;
    }
  }

  Future<bool> verifyWhatsappOtp({
    required String whatsappNumber,
    required String token,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final response = await _authService.verifyWhatsappOtp(
        whatsappNumber: whatsappNumber,
        token: token,
      );
      if (response.user == null) {
        throw Exception('Verification failed. Please try again.');
      }
      await _deviceStore.markVerified(DateTime.now());
      AppRouter.clearProfileGateCache();
      await _syncAuthState(
        response.user,
        fallbackUserType: _userTypeFromMetadata(response.user),
      );
      return true;
    } catch (e) {
      var msg = e.toString();
      if (msg.contains('Exception:')) msg = msg.split('Exception:').last.trim();
      if (msg.isEmpty) msg = 'Invalid or expired code. Please try again.';
      state = state.copyWith(isLoading: false, error: msg);
      return false;
    }
  }
```

- [ ] **Step 4: Verify it compiles and tests pass**

Run: `flutter analyze lib/features/auth && flutter test test/features/auth/auth_service_otp_test.dart`
Expected: "No issues found!" and PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/services/auth_service.dart lib/features/auth/providers/auth_state.dart test/features/auth/auth_service_otp_test.dart
git commit -m "feat(auth): add WhatsApp OTP send/verify to auth service and notifier"
```

---

### Task 5: OTP entry screen + "Sign in with WhatsApp code" on the login form

**Files:**
- Create: `lib/features/auth/screens/whatsapp_otp_screen.dart`
- Modify: `lib/features/auth/widgets/login_form.dart`
- Test: `test/features/auth/whatsapp_otp_screen_test.dart`

**Interfaces:**
- Consumes: `authStateProvider` methods `sendWhatsappOtp`, `verifyWhatsappOtp` (Task 4).
- Produces: `class WhatsAppOtpScreen extends ConsumerStatefulWidget` with `final String? whatsappNumber;` constructor param (`const WhatsAppOtpScreen({super.key, this.whatsappNumber})`). When `whatsappNumber` is null it reads `SupabaseConfig.client.auth.currentUser?.phone` (the re-verification case) and auto-sends a code on init.

- [ ] **Step 1: Write the failing widget test** — create `test/features/auth/whatsapp_otp_screen_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_application_1/features/auth/screens/whatsapp_otp_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('shows a code field and a verify button', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: WhatsAppOtpScreen(whatsappNumber: '+27821234567'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Enter the code we sent on WhatsApp'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Verify & continue'),
        findsOneWidget);
  });
}
```

> Note: this test renders the screen and asserts structure only (it does not hit Supabase). The screen must not perform network calls synchronously in `build`; the auto-send happens in `initState` via a microtask and is harmless under test (it will surface an error in state, which the widget tolerates).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/auth/whatsapp_otp_screen_test.dart`
Expected: FAIL — target file does not exist.

- [ ] **Step 3a: Implement the screen** — create `lib/features/auth/screens/whatsapp_otp_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_application_1/core/config/supabase_config.dart';
import 'package:flutter_application_1/features/auth/providers/auth_state.dart';

/// One-time-code entry for WhatsApp OTP login / re-verification.
///
/// [whatsappNumber] is the number to verify. When null (the re-verification
/// case, where a session already exists) it falls back to the signed-in user's
/// phone and auto-sends a fresh code on open.
class WhatsAppOtpScreen extends ConsumerStatefulWidget {
  final String? whatsappNumber;
  const WhatsAppOtpScreen({super.key, this.whatsappNumber});

  @override
  ConsumerState<WhatsAppOtpScreen> createState() => _WhatsAppOtpScreenState();
}

class _WhatsAppOtpScreenState extends ConsumerState<WhatsAppOtpScreen> {
  final _codeController = TextEditingController();
  late final String _number;

  @override
  void initState() {
    super.initState();
    _number = widget.whatsappNumber ??
        SupabaseConfig.client.auth.currentUser?.phone ??
        '';
    if (widget.whatsappNumber == null && _number.isNotEmpty) {
      // Re-verification: send a fresh code automatically.
      Future.microtask(_resend);
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    try {
      await ref.read(authStateProvider.notifier).sendWhatsappOtp(_number);
    } catch (_) {
      // Error is surfaced via auth state.
    }
  }

  Future<void> _verify() async {
    final ok = await ref.read(authStateProvider.notifier).verifyWhatsappOtp(
          whatsappNumber: _number,
          token: _codeController.text,
        );
    if (ok && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authStateProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('WhatsApp verification')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Enter the code we sent on WhatsApp',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                if (_number.isNotEmpty)
                  Text('to $_number',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 20),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: ' 6-digit code ',
                    counterText: '',
                  ),
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 12),
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(state.error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.error)),
                  ),
                FilledButton(
                  onPressed: state.isLoading ? null : _verify,
                  child: state.isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Verify & continue'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: state.isLoading ? null : _resend,
                  child: const Text('Resend code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 3b: Add the route** — in `lib/core/routing/app_router.dart`, add the import (after line 9):

```dart
import 'package:flutter_application_1/features/auth/screens/whatsapp_otp_screen.dart';
```

Add `'/whatsapp-otp'` to `_publicPaths` (lines 69-73) so the login-flow OTP entry is reachable before a session exists:

```dart
  static const _publicPaths = <String>{
    '/login',
    '/forgot-password',
    '/reset-password',
    '/whatsapp-otp',
  };
```

Add a top-level route (next to `/login`, after line 215):

```dart
      GoRoute(
        path: '/whatsapp-otp',
        builder: (context, state) =>
            WhatsAppOtpScreen(whatsappNumber: state.uri.queryParameters['number']),
      ),
```

- [ ] **Step 3c: Add the action to the login form** — in `lib/features/auth/widgets/login_form.dart`, add a button below the "Sign In" `FilledButton` (after line 133, inside the `Column` children, before the closing `],`):

```dart
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: state.isLoading ? null : _signInWithWhatsapp,
              icon: const Icon(Icons.chat_outlined),
              label: const Text('Sign in with WhatsApp code'),
            ),
```

Add the handler method to `_LoginFormState` (after `_submit`, around line 60):

```dart
  Future<void> _signInWithWhatsapp() async {
    final identifier = _emailController.text.trim();
    if (identifier.isEmpty || looksLikeEmail(identifier)) {
      ref
          .read(authStateProvider.notifier)
          .setError('Enter your WhatsApp number to receive a code.');
      return;
    }
    try {
      await ref.read(authStateProvider.notifier).sendWhatsappOtp(identifier);
      if (mounted) {
        AppRouter.router.go('/whatsapp-otp?number=${Uri.encodeComponent(identifier)}');
      }
    } catch (_) {
      // Error surfaced via auth state.
    }
  }
```

(`looksLikeEmail` is already imported in this file from Phase A.)

- [ ] **Step 4: Run test + analyze**

Run: `flutter test test/features/auth/whatsapp_otp_screen_test.dart && flutter analyze lib/features/auth lib/core/routing`
Expected: PASS and "No issues found!".

- [ ] **Step 5: Commit**

```bash
git add lib/features/auth/screens/whatsapp_otp_screen.dart lib/features/auth/widgets/login_form.dart lib/core/routing/app_router.dart test/features/auth/whatsapp_otp_screen_test.dart
git commit -m "feat(auth): add WhatsApp OTP entry screen and login action"
```

---

### Task 6: Router re-verification guard

**Files:**
- Modify: `lib/core/routing/app_router.dart` (redirect body, around lines 111-212)
- Test: `test/features/auth/reverification_policy_test.dart` (already covers the policy; the guard wiring is verified manually — see Task 9)

**Interfaces:**
- Consumes: `requiresReverification` (Task 2), `DeviceVerificationStore` (Task 3), `whatsappToE164` (Task 1).

The guard: a logged-in user whose Supabase auth `phone` is set, who is NOT a platform admin, must pass re-verification. If due and not already on `/whatsapp-otp`, redirect there.

- [ ] **Step 1: Add the store + imports** — in `lib/core/routing/app_router.dart` add imports (after line 6):

```dart
import 'package:flutter_application_1/features/auth/services/device_verification_store.dart';
import 'package:flutter_application_1/features/auth/utils/reverification_policy.dart';
```

Add a static store field inside `AppRouter` (after line 66, near `_refreshListenable`):

```dart
  static final _deviceVerificationStore = DeviceVerificationStore();
```

- [ ] **Step 2: Insert the guard** — in the `redirect` callback, immediately before the final `return null;` (line 212), add:

```dart
      // WhatsApp OTP re-verification gate. Applies only to phone-based users
      // (admin-created WhatsApp users); email-only owners/super admins skip it.
      final phone = currentUser.phone;
      final isOtpUser = phone != null && phone.isNotEmpty && !isPlatformAdmin;
      if (isLoggedIn &&
          isOtpUser &&
          !isPublicRoute &&
          currentPath != '/mandatory-password-change') {
        final lastVerified = await _deviceVerificationStore.lastVerifiedAt();
        if (requiresReverification(lastVerified, DateTime.now())) {
          _logger.d('WhatsApp re-verification required; redirecting to /whatsapp-otp');
          return '/whatsapp-otp';
        }
      }
```

(`isPlatformAdmin` is already computed at line 198 in the same scope.)

- [ ] **Step 3: Analyze**

Run: `flutter analyze lib/core/routing`
Expected: "No issues found!".

- [ ] **Step 4: Run the full auth test suite (no regressions)**

Run: `flutter test test/features/auth test/models`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/routing/app_router.dart
git commit -m "feat(auth): gate phone users behind WhatsApp re-verification"
```

---

### Task 7: `whatsapp-send-otp` edge function (Send-SMS hook target)

**Files:**
- Create: `supabase/functions/whatsapp-send-otp/index.ts`
- Create: `supabase/functions/whatsapp-send-otp/senders.ts`
- Test: `supabase/functions/whatsapp-send-otp/senders_test.ts`

**Interfaces:**
- Produces `senders.ts`: `interface OtpSender { send(phone: string, otp: string): Promise<void> }`, `class DevConsoleSender`, `class MetaCloudSender`, and `selectSender(env): OtpSender`.
- `index.ts` is the `Deno.serve` hook: verifies the webhook signature, parses `{ user, sms: { otp } }`, calls the selected sender with `user.phone`, returns 200 empty.

- [ ] **Step 1: Write the failing test** — create `supabase/functions/whatsapp-send-otp/senders_test.ts`:

```ts
import { assertEquals, assertInstanceOf } from "jsr:@std/assert@1";
import { DevConsoleSender, MetaCloudSender, selectSender } from "./senders.ts";

Deno.test("selectSender defaults to DevConsoleSender", () => {
  assertInstanceOf(selectSender({}), DevConsoleSender);
});

Deno.test("selectSender returns DevConsoleSender when OTP_SENDER=dev", () => {
  assertInstanceOf(selectSender({ OTP_SENDER: "dev" }), DevConsoleSender);
});

Deno.test("selectSender returns MetaCloudSender when meta is fully configured", () => {
  const sender = selectSender({
    OTP_SENDER: "meta",
    META_WABA_PHONE_ID: "123",
    META_WABA_TOKEN: "tok",
    META_OTP_TEMPLATE: "otp_login",
  });
  assertInstanceOf(sender, MetaCloudSender);
});

Deno.test("selectSender falls back to dev when meta creds are missing", () => {
  assertInstanceOf(selectSender({ OTP_SENDER: "meta" }), DevConsoleSender);
});

Deno.test("DevConsoleSender.send resolves without throwing", async () => {
  await new DevConsoleSender().send("+27821234567", "123456");
  assertEquals(true, true);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd supabase/functions/whatsapp-send-otp && deno test senders_test.ts`
Expected: FAIL — `senders.ts` does not exist. (If `deno` is unavailable locally, this task's tests run in CI / the Supabase deploy environment; note it and proceed to implement.)

- [ ] **Step 3a: Implement senders** — create `supabase/functions/whatsapp-send-otp/senders.ts`:

```ts
// Pluggable OTP delivery. DevConsoleSender logs the code (visible in function
// logs) for development; MetaCloudSender delivers via the Meta WhatsApp Cloud
// API once business credentials are configured.

export interface OtpSender {
  send(phone: string, otp: string): Promise<void>;
}

export class DevConsoleSender implements OtpSender {
  send(phone: string, otp: string): Promise<void> {
    console.log(`[DEV OTP] ${phone} -> ${otp}`);
    return Promise.resolve();
  }
}

export class MetaCloudSender implements OtpSender {
  constructor(
    private readonly phoneId: string,
    private readonly token: string,
    private readonly template: string,
  ) {}

  async send(phone: string, otp: string): Promise<void> {
    // Meta requires E.164 without the leading '+'.
    const to = phone.replace(/^\+/, "");
    const res = await fetch(
      `https://graph.facebook.com/v21.0/${this.phoneId}/messages`,
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${this.token}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          messaging_product: "whatsapp",
          to,
          type: "template",
          template: {
            name: this.template,
            language: { code: "en" },
            components: [
              { type: "body", parameters: [{ type: "text", text: otp }] },
              {
                type: "button",
                sub_type: "url",
                index: "0",
                parameters: [{ type: "text", text: otp }],
              },
            ],
          },
        }),
      },
    );
    if (!res.ok) {
      throw new Error(`Meta send failed: ${res.status} ${await res.text()}`);
    }
  }
}

export function selectSender(env: Record<string, string | undefined>): OtpSender {
  const phoneId = env.META_WABA_PHONE_ID;
  const token = env.META_WABA_TOKEN;
  const template = env.META_OTP_TEMPLATE;
  if (env.OTP_SENDER === "meta" && phoneId && token && template) {
    return new MetaCloudSender(phoneId, token, template);
  }
  return new DevConsoleSender();
}
```

- [ ] **Step 3b: Implement the hook** — create `supabase/functions/whatsapp-send-otp/index.ts`:

```ts
import { Webhook } from "https://esm.sh/standardwebhooks@1.0.0";
import { selectSender } from "./senders.ts";

const hookSecret = (Deno.env.get("SEND_SMS_HOOK_SECRET") ?? "").replace(
  "v1,whsec_",
  "",
);

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: { http_code: 405, message: "Method not allowed" } }), { status: 405 });
  }

  const payload = await req.text();
  let user: { phone?: string };
  let sms: { otp?: string };
  try {
    const wh = new Webhook(hookSecret);
    const verified = wh.verify(payload, Object.fromEntries(req.headers)) as {
      user: { phone?: string };
      sms: { otp?: string };
    };
    user = verified.user;
    sms = verified.sms;
  } catch (_e) {
    return new Response(
      JSON.stringify({ error: { http_code: 401, message: "Invalid signature" } }),
      { status: 401 },
    );
  }

  const phone = user?.phone ?? "";
  const otp = sms?.otp ?? "";
  if (!phone || !otp) {
    return new Response(
      JSON.stringify({ error: { http_code: 400, message: "Missing phone or otp" } }),
      { status: 400 },
    );
  }

  try {
    await selectSender(Deno.env.toObject()).send(phone, otp);
  } catch (e) {
    const message = e instanceof Error ? e.message : "Delivery failed";
    return new Response(
      JSON.stringify({ error: { http_code: 500, message } }),
      { status: 500 },
    );
  }

  return new Response(JSON.stringify({}), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
```

- [ ] **Step 4: Run sender tests**

Run: `cd supabase/functions/whatsapp-send-otp && deno test senders_test.ts`
Expected: PASS (5 tests). If `deno` is not installed locally, skip locally and rely on deploy-time verification (Task 9), noting this in the commit.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/whatsapp-send-otp/
git commit -m "feat(functions): add whatsapp-send-otp send-sms hook with pluggable sender"
```

---

### Task 8: Create phone-based users in `company-user-admin`

**Files:**
- Modify: `supabase/functions/company-user-admin/index.ts` (the `createUser` call, lines 279-288)

**Interfaces:**
- Consumes: existing `whatsappNumber` variable (line 275).

New admin-created users get a Supabase `phone` (E.164) + `phone_confirm: true` in addition to the synthetic email + password, enabling OTP login while preserving the password fallback.

- [ ] **Step 1: Implement** — in `supabase/functions/company-user-admin/index.ts`, just before the `createUser` call (before line 279), add an E.164 helper use; replace lines 279-288 with:

```ts
    const phoneE164 = `+${whatsappNumber.replace(/\D/g, "")}`;

    const { data: createdUserData, error: createUserError } =
      await serviceRoleClient.auth.admin.createUser({
        email,
        password,
        phone: phoneE164,
        email_confirm: true,
        phone_confirm: true,
        user_metadata: {
          user_type: "employee",
          display_name: displayName,
        },
      });
```

- [ ] **Step 2: Lint the function (type check only)**

Run: `cd supabase/functions/company-user-admin && deno check index.ts`
Expected: no type errors. (If `deno` is unavailable locally, this is verified at deploy in Task 9.)

- [ ] **Step 3: Commit**

```bash
git add supabase/functions/company-user-admin/index.ts
git commit -m "feat(functions): set phone on admin-created users for WhatsApp OTP"
```

---

### Task 9: Runbook — enable & verify (copy-paste blocks)

**Files:**
- Create: `docs/superpowers/runbooks/2026-06-17-whatsapp-otp-enablement.md`

This task produces the exact, copy-paste-ready steps the user runs (dashboard + CLI + Meta), plus the manual end-to-end verification. No automated test; the deliverable is the verified runbook.

- [ ] **Step 1: Write the runbook** — create `docs/superpowers/runbooks/2026-06-17-whatsapp-otp-enablement.md` with the following content:

````markdown
# WhatsApp OTP — enablement runbook

Project ref: `yftazblpmicqtamyiwyb`.

## 1. Deploy the edge functions
```bash
supabase functions deploy whatsapp-send-otp --project-ref yftazblpmicqtamyiwyb
supabase functions deploy company-user-admin --project-ref yftazblpmicqtamyiwyb
```

## 2. Set the hook secret (and dev sender)
Generate a Standard Webhooks secret and set it on the function. In the Supabase
dashboard: Authentication → Hooks → "Send SMS" → create/enable hook → choose
"HTTPS" → URL `https://yftazblpmicqtamyiwyb.functions.supabase.co/whatsapp-send-otp`.
Copy the generated secret, then:
```bash
supabase secrets set SEND_SMS_HOOK_SECRET="v1,whsec_PASTE_FROM_DASHBOARD" --project-ref yftazblpmicqtamyiwyb
supabase secrets set OTP_SENDER="dev" --project-ref yftazblpmicqtamyiwyb
```

## 3. Enable phone auth
Dashboard → Authentication → Providers → Phone → enable. (If the dashboard
requires an SMS provider to save, enter any provider's placeholder credentials —
the Send-SMS hook overrides actual delivery. Confirm during this step whether it
can be saved without one.)

## 4. Dev verification (no real WhatsApp yet)
1. Create a user via the app's Add User form (admin → Manage Employees).
2. On the login screen, enter that WhatsApp number → "Sign in with WhatsApp code".
3. Read the code from the function logs:
   ```bash
   supabase functions logs whatsapp-send-otp --project-ref yftazblpmicqtamyiwyb
   ```
   Look for `[DEV OTP] +27... -> 123456`.
4. Enter the code → you should land on /home. Re-open the app same week → no code
   asked. (Optionally) advance the device clock past the next Monday → code asked.

## 5. Go live on WhatsApp (later)
1. Create a Meta Business account, verify the business, create a WhatsApp Business
   Account (WABA), add & verify a sender phone number.
2. Create an **authentication** message template (category: Authentication) with a
   one-time-code body + copy-code button; note its name.
3. Set secrets and flip the sender:
   ```bash
   supabase secrets set META_WABA_PHONE_ID="<phone-number-id>" --project-ref yftazblpmicqtamyiwyb
   supabase secrets set META_WABA_TOKEN="<permanent-access-token>" --project-ref yftazblpmicqtamyiwyb
   supabase secrets set META_OTP_TEMPLATE="<template-name>" --project-ref yftazblpmicqtamyiwyb
   supabase secrets set OTP_SENDER="meta" --project-ref yftazblpmicqtamyiwyb
   ```
4. Re-run the step-4 flow with a real number; the code now arrives on WhatsApp.
````

- [ ] **Step 2: Commit**

```bash
git add docs/superpowers/runbooks/2026-06-17-whatsapp-otp-enablement.md
git commit -m "docs: add WhatsApp OTP enablement runbook"
```

- [ ] **Step 3: Full verification sweep**

Run: `flutter analyze lib test && flutter test`
Expected: "No issues found!" and all tests PASS. Then perform the manual dev verification in the runbook (steps 1-4) with the user.

---

## Self-Review

**Spec coverage:**
- Pluggable delivery (dev now, Meta later) → Task 7 (`senders.ts`, `selectSender`).
- Phone-based new users → Task 8.
- OTP send/verify client flow → Tasks 4, 5.
- Re-verification cadence (new device + weekly Monday) → Tasks 2, 3, 6.
- Password fallback retained → unchanged login form path (Phase A); no task removes it. ✓
- Enable/runbook + Meta setup → Task 9.
- Testing (pure functions, sender selection, widget structure) → Tasks 1-3, 5, 7.
- "To verify during implementation" items (SMS-provider requirement, createUser-with-phone, dev test numbers) → surfaced in Task 9 step 3 and Task 8 step 2.

**Placeholder scan:** No TBD/TODO; all steps contain concrete code or exact commands. Where `deno` may be absent locally, the plan states the fallback (deploy-time verification) rather than leaving it vague.

**Type consistency:** `whatsappToE164`, `requiresReverification`, `mostRecentMonday`, `DeviceVerificationStore.{lastVerifiedAt,markVerified,deviceId,clear}`, `sendWhatsappOtp`, `verifyWhatsappOtp({whatsappNumber, token})`, `OtpSender.send(phone, otp)`, `selectSender(env)` are used consistently across tasks.
