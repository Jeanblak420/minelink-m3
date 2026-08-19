-- Fix round 1 for crash_reports (20260819140000). Three findings, all ruled
-- on by the coordinator before this file was written.
--
-- WHY THERE IS NO `anon` INSERT POLICY (considered and rejected)
-- ----------------------------------------------------------------
-- crash_reports_insert_own is `to authenticated` only, so a genuine pre-auth
-- crash (before sign-in, before any session exists) runs as `anon` and is
-- denied by RLS. The obvious fix is an `anon` INSERT policy. That was
-- explicitly rejected: the publishable key ships in every web bundle and
-- every APK, so an `anon` INSERT policy on this table would be an
-- unauthenticated, unmetered write endpoint into a 500 MB free-plan
-- database. CLAUDE.md §10.2 already records a two-hour outage on this exact
-- project caused by write and disk pressure. Widening the write surface to
-- fix a comment is the wrong trade.
--
-- The real answer lives in Task 3: SupabaseReportingSink buffers a failed
-- send in memory and drains the buffer on the next successful send, so a
-- pre-auth crash is held and delivered once the user signs in. The residual
-- gap is real and is written down rather than hidden: a crash on a session
-- that never signs in (uninstall, abandoned onboarding, a device that never
-- reconnects) is never collected. That gap is accepted, not solved.

comment on table public.crash_reports is
  'Uncaught and handled errors shipped off-device by SupabaseReportingSink. '
  'user_id is SET NULL rather than CASCADE so an account deletion (R-1) '
  'de-identifies a report instead of destroying it. '
  'INSERT is `to authenticated` only -- a pre-auth crash cannot write here '
  'directly (RLS denies `anon`, deliberately: see 20260819145000 header, '
  'the publishable key is public and this is a 500 MB free-plan project). '
  'SupabaseReportingSink buffers a failed pre-auth send in memory and drains '
  'it on the next successful send, so most pre-auth crashes arrive once the '
  'user signs in -- but a crash on a session that never signs in is never '
  'collected. That gap is accepted. '
  'Retention: pruned at 90 days by prune_telemetry_job(), added in '
  '20260819150000 -- not yet present as of this migration. '
  'error/stack are truncated client-side (4 kB / 16 kB) and bounded '
  'server-side by CHECK constraints of the same size, added in '
  '20260819145000, because this is a 500 MB free-plan project and an error '
  'loop can generate reports faster than anyone reads them.';

-- Server-side length bounds, matching Task 3's client-side truncation caps
-- (4 kB error / 16 kB stack) exactly -- the server enforces the sink's own
-- contract rather than inventing a second one. `stack` is nullable and
-- `length(null) <= n` evaluates to NULL, which a CHECK treats as passing
-- (not violating) -- so NULL stack traces are correctly allowed through.
-- Do not "fix" this by adding an `or stack is null` clause; it is already
-- correct and redundant would just be noise.
alter table public.crash_reports
  add constraint crash_reports_error_length check (length(error) <= 4096);

alter table public.crash_reports
  add constraint crash_reports_stack_length check (length(stack) <= 16384);
