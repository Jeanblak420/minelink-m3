# Implementation Plan And Ledger

## Completed on March 27, 2026

- Destructively reset the connected Supabase project `yftazblpmicqtamyiwyb`.
- Rebuilt the canonical schema, storage buckets, auth triggers, workflow RPCs, grants, RLS, and realtime publication.
- Replaced hard-coded client Supabase config with `dart-define`-based configuration.
- Removed startup database mutation bootstrapping from app startup.
- Reworked auth state handling around the native Supabase auth stream.
- Added router-level redirects for protected and auth-only routes.
- Moved company, employee, notification, dismissal, and fleet writes to canonical RPCs.
- Replaced employee, company, fleet, notification, and status polling with Postgres Changes subscriptions on the active paths.
- Updated deprecated form and radio APIs to current Flutter patterns.
- Regenerated Mockito mocks and restored clean analysis and test runs.
- Cleared Supabase advisor warnings except for expected unused-index notices on a fresh database.

## Canonical task list

- `done`: reset the canonical Supabase project and recreate the business schema.
- `done`: add core workflow functions for signup, linking, approvals, role assignment, notifications, dismissal, and fleet.
- `done`: recreate storage buckets, RLS, grants, and realtime publication.
- `done`: migrate Flutter auth, company, employee, notification, and fleet services to the new backend contract.
- `done`: modernize major deprecated Flutter widget APIs found during verification.
- `done`: verify with `flutter analyze`, `flutter test`, and Supabase advisors.
- `done`: retire the remaining legacy webhook- and `run_sql`-based helper files that were no longer on the hot path.
- `next`: wire more of the operations domain screens to the already-created tables for minerals, weighbridge, security, and gate flows.

## Remaining follow-ups

- Decide whether employee document storage should move from public URLs to signed private access across the entire UI.
- Add richer automated integration tests for the new RPC-owned onboarding and dismissal workflows.
- Expand the currently placeholder operations tabs onto the canonical tables already present in Supabase.
