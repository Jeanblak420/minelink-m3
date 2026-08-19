# Environment Setup

## Flutter defines

The app no longer embeds a default remote Supabase project configuration in Dart source, but this repo is set up to target the live project only.

Use one of these supported setup paths:

1. Use the committed `config/supabase.live.json` file.
2. Run the app with one of the repo scripts or VS Code launch config, which already pass that file.
3. Or pass `--dart-define-from-file=config/supabase.live.json` yourself.

Direct `dart-define` values still work if you intentionally need to override the live project.

```bash
flutter run ^
  --dart-define=SUPABASE_URL=https://yftazblpmicqtamyiwyb.supabase.co ^
  --dart-define=SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

Legacy `SUPABASE_ANON_KEY` still works as a fallback, but new setups should prefer `SUPABASE_PUBLISHABLE_KEY`.

## Canonical backend

- Project ref: `yftazblpmicqtamyiwyb`
- Primary migration: [supabase/migrations/20260327000100_canonical_platform_reset.sql](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/supabase/migrations/20260327000100_canonical_platform_reset.sql)
- Required buckets:
  - `company_assets`
  - `employee_assets`
  - `chat_files`
- Required realtime publication:
  - `supabase_realtime`

## Supported deployment model

- Core onboarding, workflow, and notification writes are database-owned RPCs.
- CRUD sync uses Postgres Changes.
- Chat collaboration can use Presence and Broadcast.
- Database webhooks are retired for the canonical platform.

## Verification checklist

1. Confirm the `public` schema tables exist from the canonical migration.
2. Confirm RLS is enabled on exposed tables.
3. Confirm storage buckets exist with their path-based policies.
4. Confirm `supabase_realtime` includes the business tables.
5. Run `flutter analyze`.
6. Run `flutter test`.
7. Run Supabase security and performance advisors.
