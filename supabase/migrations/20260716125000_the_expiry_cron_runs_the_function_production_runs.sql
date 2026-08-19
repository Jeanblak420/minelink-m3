-- A rebuilt database would have expired organisations with the OLD function.
--
-- Found 2026-08-18 by diffing a database rebuilt from git against production,
-- and it is the most consequential thing that diff turned up, because it is
-- about what runs on a schedule rather than what merely exists.
--
-- `20260510192000_expire_organizations_job.sql` creates
-- `expire_organizations_job()` and schedules it as `expire_organizations_daily`.
-- `20260716120000_fix_expire_organizations_cron.sql` then creates its
-- replacement, `expire_organizations()` — and schedules nothing, and unschedules
-- nothing. So from the files alone a rebuild ends up with:
--
--     function  expire_organizations_job()      (legacy)
--     function  expire_organizations()          (the fix)
--     cron job  expire_organizations_daily  ->  expire_organizations_job()
--
-- while production runs:
--
--     function  expire_organizations()          only
--     cron job  expire-organizations-daily  ->  SELECT public.expire_organizations()
--
-- Production's job was created out of band and no file records it — the same
-- unmirrored-change problem as `seat_reassignment_log`, this time in the
-- scheduler, where nothing about the schema would ever have shown it. A rebuilt
-- database would have quietly run the superseded expiry logic against real
-- companies every night.
--
-- Note the name changes too — underscores to hyphens — so the two jobs do not
-- collide and the old one is not replaced by scheduling the new one. It has to
-- be unscheduled by name.
--
-- Guarded, because pg_cron may legitimately be absent (the extension is created
-- in 20260327000100, but a restore into an environment without it should not
-- fail here — the functions still exist for external scheduling).

begin;

do $expiry_cron$
begin
  if exists (select 1 from pg_namespace where nspname = 'cron') then
    if exists (select 1 from cron.job where jobname = 'expire_organizations_daily') then
      perform cron.unschedule('expire_organizations_daily');
    end if;
    if not exists (select 1 from cron.job where jobname = 'expire-organizations-daily') then
      perform cron.schedule(
        'expire-organizations-daily',
        '5 1 * * *',
        -- Byte-identical to the command production already runs, so a
        -- schema-parity check has nothing cosmetic to report forever.
        $job$SELECT public.expire_organizations()$job$
      );
    end if;
  end if;
exception
  when undefined_table or insufficient_privilege or invalid_schema_name then
    raise notice 'expiry cron not reconciled: %', sqlerrm;
end
$expiry_cron$;

-- The legacy function goes with its job. Production does not have it.
drop function if exists public.expire_organizations_job() cascade;

commit;
