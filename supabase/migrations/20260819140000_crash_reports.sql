-- Crash reports had nowhere to go.
--
-- `lib/core/telemetry/crash_reporter.dart` has been a correct seam since S9-1:
-- FlutterError.onError, PlatformDispatcher.onError, runZonedGuarded and
-- ErrorWidget.builder all route into a ReportingSink. But the only sink kept
-- 50 reports in memory on the device, so on a shipped release there was still
-- no way for anyone to see a crash. Picking the destination was the open ASK;
-- Jean chose a table on this project over a third-party vendor (2026-08-19).
--
-- WHY user_id IS `on delete set null`, NOT CASCADE
-- ------------------------------------------------
-- Account deletion (R-1) must de-identify a crash report, not destroy the
-- engineering record of the crash. This is the one column where the two
-- features touch, and getting it wrong means every bug report from a user who
-- later leaves disappears with them.

create table if not exists public.crash_reports (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid references public.profiles(id) on delete set null,
  at          timestamptz not null,
  platform    text,
  app_version text,
  error       text not null,
  stack       text,
  context     text,
  fatal       boolean not null default false,
  created_at  timestamptz not null default timezone('utc', now())
);

comment on table public.crash_reports is
  'Uncaught and handled errors shipped off-device by SupabaseReportingSink. '
  'user_id is SET NULL rather than CASCADE so an account deletion (R-1) '
  'de-identifies a report instead of destroying it. Pruned at 90 days by '
  'prune_telemetry_job(). error/stack are truncated client-side (4 kB / 16 kB) '
  'because this is a 500 MB free-plan project and an error loop can generate '
  'reports faster than anyone reads them.';

create index if not exists crash_reports_recent_idx
  on public.crash_reports (created_at desc);
create index if not exists crash_reports_fatal_idx
  on public.crash_reports (created_at desc) where fatal;

alter table public.crash_reports enable row level security;

-- INSERT allows user_id IS NULL on purpose. A crash during bootstrap happens
-- before there is a session, and losing precisely the crashes that occur
-- before sign-in would be the worst possible gap in a crash reporter.
drop policy if exists crash_reports_insert_own on public.crash_reports;
create policy crash_reports_insert_own on public.crash_reports
  for insert to authenticated
  with check (user_id = auth.uid() or user_id is null);

drop policy if exists crash_reports_select_platform_admin on public.crash_reports;
create policy crash_reports_select_platform_admin on public.crash_reports
  for select to authenticated
  using (public.is_platform_admin());

-- No UPDATE and no DELETE policy: a crash report is not editable, and it is
-- removed only by prune_telemetry_job(), which is SECURITY DEFINER.
grant select, insert on public.crash_reports to authenticated;
