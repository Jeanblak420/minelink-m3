-- Move the nightly broadcast-message cleanup server-side (pg_cron), off the
-- client MaintenanceScheduler: the client timer ran as whichever user
-- happened to have the app open at midnight — anonymous sessions got 42501,
-- non-admin sessions silently did nothing, and the cleanup only actually ran
-- if a platform admin left a tab open. The cron job runs nightly regardless.
-- (Applied live via Supabase MCP on 2026-08-03; this file mirrors it for git.)

-- Internal job function (mirrors notify_*_job convention): no admin gate —
-- it is never exposed to clients.
create or replace function public.cleanup_old_broadcast_messages_job()
returns bigint
language plpgsql
security definer
set search_path to 'public'
as $fn$
declare
  deleted_count bigint;
begin
  delete from public.broadcast_messages
  where timestamp < timezone('utc', now()) - interval '30 days';
  get diagnostics deleted_count = row_count;
  return deleted_count;
end;
$fn$;

revoke all on function public.cleanup_old_broadcast_messages_job()
  from public, anon, authenticated;

do $do$
begin
  if exists (
    select 1 from cron.job where jobname = 'cleanup-old-broadcast-messages'
  ) then
    perform cron.unschedule('cleanup-old-broadcast-messages');
  end if;
end
$do$;

select cron.schedule(
  'cleanup-old-broadcast-messages',
  '45 2 * * *',
  'select public.cleanup_old_broadcast_messages_job()'
);
