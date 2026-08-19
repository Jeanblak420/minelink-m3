<!-- markdownlint-disable-file -->
# WhatsApp OTP login (Phase B) — design

Date: 2026-06-17

## Context

Admin-created Mine/Supplier users are identified by a **WhatsApp number**, not an email
(Phase A: `docs/superpowers/specs/2026-06-17-admin-mine-supplier-users-roles-design.md`).
Phase B lets them log in by receiving a one-time code over WhatsApp instead of (primarily)
a password.

Decisions taken in brainstorming:
- **Delivery is pluggable**: build the full OTP login now with a dev-stub sender; add the
  Meta WhatsApp Cloud API sender later. No app rebuild needed to switch — it is an edge
  function change only.
- **Identity**: new admin-created users are **phone-based from creation**; existing
  synthetic-email users (from Phase A) are left as-is and keep using number + password.
- **Password**: WhatsApp OTP is the primary login; password is kept as a fallback.
- **Re-verification cadence**: verify on a new device, then weekly on Mondays; if Monday is
  missed, verify on the next login/use. Tracked per device.

## Confirmed Supabase facts (from docs, 2026-06-17)

- Supabase **Send-SMS auth hook** delivers the OTP to a hook we own. Payload:
  `{ user: {...}, sms: { otp: "123456" } }` (6-digit). Hook returns HTTP 200 with empty body
  on success; `{ error: { http_code, message } }` + non-200 on failure. Can be an HTTPS edge
  function. Requests are signed — verify with the `standardwebhooks` lib and the
  `SEND_SMS_HOOK_SECRET` env (`v1,whsec_`-prefixed).
  Docs: https://supabase.com/docs/guides/auth/auth-hooks/send-sms-hook
- Phone OTP client calls: `signInWithOtp({ phone })` then
  `verifyOtp({ phone, token, type: 'sms' })` (Dart: `OtpType.sms`).
  Docs: https://supabase.com/docs/guides/auth/phone-login
- The built-in `channel: whatsapp` only works with Twilio/Twilio Verify — **not** our path.
  The **hook** is how we deliver over WhatsApp with any provider (docs explicitly list
  "Use alternate messaging channels such as WhatsApp" as a hook use case).

**To verify during implementation (not blocking the design):**
- Whether enabling the Send-SMS hook still requires a configured SMS provider in the
  dashboard, or fully replaces it.
- `auth.admin.createUser({ phone, phone_confirm: true })` accepting a phone (and a user
  holding both email + phone). The hook payload example shows phone-only users exist.
- Dashboard "test phone numbers with fixed OTP" for dev (preferred dev path; fallback is the
  hook logging the code).

## Architecture

```
Login (WhatsApp #) ─► auth.signInWithOtp(phone)
        │                    │ Supabase generates + stores code, fires hook
        │                    ▼
        │            Send-SMS hook ─► edge fn `whatsapp-send-otp`
        │                                 │ verify signature (SEND_SMS_HOOK_SECRET)
        │                                 │ OtpSender (selected by env):
        │                                 ├─ DevConsoleSender  (now: console.log)
        │                                 └─ MetaCloudSender   (later: WhatsApp Cloud API)
        ▼
OTP entry screen ─► auth.verifyOtp(phone, token, type: sms) ─► session
        │
        ▼
  record device verification (lastVerifiedAt = now) ─► enter app
```

The Flutter app only ever calls `signInWithOtp` / `verifyOtp`; it is provider-agnostic.

## Components

### Server (Supabase)
1. **Enable phone auth** + register the **Send-SMS hook** pointing at the
   `whatsapp-send-otp` edge function (dashboard/CLI; documented as runbook steps — cannot be
   done purely in migrations).
2. **New edge fn `whatsapp-send-otp`** (the hook target):
   - Verify the webhook signature using `SEND_SMS_HOOK_SECRET`.
   - Parse `{ user, sms: { otp } }`; recipient phone = `user.phone`.
   - `OtpSender` interface: `send(phone, otp): Promise<void>`.
     - `DevConsoleSender` — `console.log` the code (visible in function logs). Active when
       `OTP_SENDER=dev` (default) or Meta creds are absent.
     - `MetaCloudSender` — POST to the Meta WhatsApp Cloud API using an approved
       authentication template; active when `OTP_SENDER=meta` and creds present
       (`META_WABA_PHONE_ID`, `META_WABA_TOKEN`, `META_OTP_TEMPLATE`).
   - Return 200 empty on success.
3. **Modify `company-user-admin` create flow**: also set `phone` (E.164) +
   `phone_confirm: true` on `auth.admin.createUser`, in addition to the existing synthetic
   email + password. New users thus have **phone (OTP) + synthetic email + password
   (fallback)**; both cohorts keep a uniform password path, new users additionally get OTP.

### Flutter
4. `whatsapp_identity.dart` gains `whatsappToE164(number)` → `+<digits>` (Supabase phone
   format), unit-tested alongside the existing helpers.
5. **OTP login flow**:
   - Entry: reuse the existing login field; a "Sign in with WhatsApp code" action calls
     `signInWithOtp(phone: whatsappToE164(number))` and navigates to the OTP screen.
   - **OTP entry screen** (`lib/features/auth/screens/whatsapp_otp_screen.dart`): 6-digit
     input, resend (rate-limited), error display; calls `verifyOtp(...)`.
   - On success → `DeviceVerificationStore.markVerified(now)` then route into the app.
   - **Password fallback** stays on the existing login form unchanged (number/email +
     password). For a typed number, password sign-in uses the synthetic-email + password
     path (works for both cohorts).
6. **Device-trust + cadence**:
   - `DeviceVerificationStore` — local secure storage (`flutter_secure_storage` if present,
     else the app's existing secure store) holding `{ deviceId, lastVerifiedAt }`. `deviceId`
     is a UUID generated once per install.
   - Pure functions in `lib/features/auth/utils/reverification_policy.dart`:
     - `DateTime mostRecentMonday(DateTime now)` → Monday 00:00 local of the current week.
     - `bool requiresReverification(DateTime? lastVerifiedAt, DateTime now)` =
       `lastVerifiedAt == null || lastVerifiedAt.isBefore(mostRecentMonday(now))`.
   - **Router guard**: for OTP-eligible users (auth user has a non-null `phone`), if
     `requiresReverification`, redirect to the OTP screen before granting access. Email-only
     users (company owners, super admins) bypass the guard entirely.

## Data flow — first login on a new device
1. User enters WhatsApp number, taps "Sign in with WhatsApp code".
2. `signInWithOtp(phone)` → Supabase fires hook → `whatsapp-send-otp` sends code (dev: logs).
3. User enters code → `verifyOtp` → session established.
4. `markVerified(now)` writes `lastVerifiedAt`. Guard passes; app opens.
5. Next open same week → guard sees `lastVerifiedAt >= thisMonday` → no OTP.
6. After the next Monday → guard requires OTP again on first use.

## Error handling
- Delivery failure / not received → "Resend code" (rate-limited) + password fallback link.
- Wrong/expired code → inline error; Supabase enforces expiry (~60s) and attempt limits.
- Offline → standard retry messaging; guard does not lock the user out of the login screen.
- Dev sender clearly labels itself so no real code is expected in development.
- Hook signature mismatch → 401 from the edge function (and logged).

## Testing
- Pure unit tests: `mostRecentMonday` (mid-week, Sunday, exactly Monday 00:00), and
  `requiresReverification` (null/new device, same week, after Monday rollover, boundary at
  Monday 00:00). `whatsappToE164` formatting.
- Edge fn: `OtpSender` selection by env; signature-verification rejects bad signatures
  (logic-level test; full hook is integration-tested manually against Supabase).
- Widget test: OTP entry screen happy path with a mocked Supabase client.

## Rollout / runbook (documented, executed with the user)
1. Enable phone provider in Supabase Auth settings.
2. Deploy `whatsapp-send-otp`; set `SEND_SMS_HOOK_SECRET`; register the Send-SMS hook.
3. Dev: configure test phone numbers with fixed OTP (or rely on the dev sender's logged
   code). Verify end-to-end with a test user.
4. Later: provision Meta WhatsApp Business (verified business, WABA, number, approved
   authentication template); set Meta secrets; flip `OTP_SENDER=meta`.

## Out of scope
- Server-side `trusted_devices` table for remote revoke/audit (local-first now; future).
- Migrating existing Phase-A synthetic-email users to phone-based (they keep number +
  password until they naturally re-onboard).
- Replacing the password entirely (kept as fallback per decision).
