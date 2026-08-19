# Supabase Dashboard Verification Guide

Use this guide after applying the canonical migration to the project `yftazblpmicqtamyiwyb`.

## Dashboard checks

1. Open the project dashboard for `yftazblpmicqtamyiwyb`.
2. In Table Editor, confirm the canonical public tables exist.
3. In Database, confirm row level security is enabled on exposed public tables.
4. In Storage, confirm these buckets exist:
   - `company_assets`
   - `employee_assets`
   - `chat_files`
5. In Database Publications, confirm `supabase_realtime` includes the business tables.
6. In Auth, confirm new signups create rows in `profiles`.
7. In Advisors, confirm security warnings are empty.

## App-side checks

1. Start the app with `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY`.
2. Create a company account and confirm the company row exists.
3. Create an employee account and confirm the employee row exists.
4. Request a company link and confirm status history plus notifications appear.
5. Approve, assign a role, and confirm the employee updates through realtime.

## Legacy note

This guide replaces the older webhook-based dashboard flow. The canonical platform should not require manual database webhooks for normal app operation.
