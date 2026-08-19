# WhatsApp OTP — enablement runbook

Project ref: `yftazblpmicqtamyiwyb`.

> **STATUS (2026-06-21):**
> - ✅ Steps 1–3 DONE on live (functions deployed; Send-SMS hook enabled in **dev** mode `OTP_SENDER=dev`; phone provider enabled).
> - ✅ Step 4 DONE — backend pipeline verified (OTP request returned HTTP 200; hook signature verified; dev sender ran). Also fixed a `company-user-admin` bug (`email.contains`→`email.includes`).
> - ⛔ **Step 5 NOT DONE — OUTSTANDING.** Real WhatsApp delivery via Meta (Business verification, WABA, phone number, approved auth template) is still required, then set Meta secrets + flip `OTP_SENDER=meta`. Until then OTP codes only appear in the function logs, not on WhatsApp.

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

- **Important:** ensure "Enable phone signups" / auto-confirm is turned **off**
  so that `signInWithOtp` for an unknown number does not silently create a new
  account. Users are created only via the admin flow (Manage Employees). Leaving
  this on risks account enumeration and accidental account creation.

## 4. Dev verification (no real WhatsApp yet)
1. Create a user via the app's Add User form (admin → Manage Employees).
2. On the login screen, enter that WhatsApp number → "Sign in with WhatsApp code".
3. Read the code from the function logs:
   ```bash
   supabase functions logs whatsapp-send-otp --project-ref yftazblpmicqtamyiwyb
   ```
   Look for `[DEV OTP] +27... -> 123456`.
4. Enter the code → you should land on /home. Re-open the app → no code asked
   (device stays verified for `kReverificationInterval`, default 30 days).
   (Optionally) advance the device clock past 30 days → code asked again.

## 5. Go live on WhatsApp (later)
1. Create a Meta Business account, verify the business, create a WhatsApp Business
   Account (WABA), add & verify a sender phone number.
2. Create an **authentication** message template (category: Authentication) with a
   one-time-code body + copy-code button; note its name.
   - The template's language code **must be `en`** to match the edge function's
     `language: { code: "en" }` in `senders.ts`. If you need a different locale,
     update both the Meta template and the `senders.ts` constant together.
3. Set secrets and flip the sender:
   ```bash
   supabase secrets set META_WABA_PHONE_ID="<phone-number-id>" --project-ref yftazblpmicqtamyiwyb
   supabase secrets set META_WABA_TOKEN="<permanent-access-token>" --project-ref yftazblpmicqtamyiwyb
   supabase secrets set META_OTP_TEMPLATE="<template-name>" --project-ref yftazblpmicqtamyiwyb
   supabase secrets set OTP_SENDER="meta" --project-ref yftazblpmicqtamyiwyb
   ```
4. Re-run the step-4 flow with a real number; the code now arrives on WhatsApp.
