-- A daily check-in per device, so a quiet crash table can be read.
--
-- Jean's go-ahead, 2026-10-24. Nothing had reached `crash_reports` since
-- 17 Oct, and nothing could say whether that meant "no crashes" or "nothing
-- can report". Every signed-in install now checks in once a day through the
-- same authenticated write path the crash sink uses; the Crash reports page
-- shows which devices are checking in and which have gone quiet.
--
-- One row per device, updated in place, so the table is bounded by the
-- number of installs, not by how often they run. The server ignores a
-- repeat inside the hour, so a misbehaving client cannot turn the daily
-- update into a stream of writes. Rows not seen for 180 days are pruned
-- nightly (CLAUDE.md §10.2: ship retention with the write path).
--
-- Written only through `record_device_checkin`; read by the platform admin
-- only, through RLS and `list_device_checkins`.
begin;

create table public.device_checkins (
  device_id     text primary key
                check (char_length(device_id) between 8 and 64),
  user_id       uuid references auth.users (id) on delete set null,
  platform      text not null check (char_length(platform) between 1 and 20),
  app_version   text check (char_length(app_version) <= 40),
  first_seen_at timestamptz not null default now(),
  last_seen_at  timestamptz not null default now(),
  checkins      integer not null default 1
);

comment on table public.device_checkins is
  'One row per signed-in install, updated at most hourly by '
  'record_device_checkin. Tells "no crashes" apart from "cannot report". '
  'Pruned after 180 days unseen by prune_device_checkins_job.';

create index device_checkins_last_seen_idx
  on public.device_checkins (last_seen_at desc);

alter table public.device_checkins enable row level security;

revoke all on table public.device_checkins from anon, authenticated;
grant select on table public.device_checkins to authenticated;

create policy device_checkins_select_platform_admin
  on public.device_checkins for select to authenticated
  using (public.is_platform_admin());

create or replace function public.record_device_checkin(
  p_device_id text,
  p_platform text,
  p_app_version text default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if auth.uid() is null then
    raise exception 'record_device_checkin: not signed in'
      using errcode = '42501';
  end if;

  insert into public.device_checkins as d
    (device_id, user_id, platform, app_version)
  values
    (p_device_id, auth.uid(), p_platform, left(p_app_version, 40))
  on conflict (device_id) do update
     set user_id      = excluded.user_id,
         platform     = excluded.platform,
         app_version  = excluded.app_version,
         last_seen_at = now(),
         checkins     = d.checkins + 1
   where d.last_seen_at < now() - interval '1 hour';
end;
$function$;

revoke all on function public.record_device_checkin(text, text, text)
  from public, anon;
grant execute on function public.record_device_checkin(text, text, text)
  to authenticated;

-- The admin's view: each device with the name and address of who last used
-- it. `user_id` points at auth.users, which PostgREST cannot embed, hence a
-- function rather than a select with a join.
create or replace function public.list_device_checkins(p_limit integer default 200)
returns table (
  device_id     text,
  user_id       uuid,
  user_label    text,
  platform      text,
  app_version   text,
  first_seen_at timestamptz,
  last_seen_at  timestamptz,
  checkins      integer
)
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
begin
  if not public.is_platform_admin() then
    return;
  end if;

  return query
    select d.device_id, d.user_id,
           coalesce(nullif(p.display_name, ''), p.email),
           d.platform, d.app_version, d.first_seen_at, d.last_seen_at,
           d.checkins
      from public.device_checkins d
      left join public.profiles p on p.id = d.user_id
     order by d.last_seen_at desc
     limit greatest(1, least(coalesce(p_limit, 200), 1000));
end;
$function$;

revoke all on function public.list_device_checkins(integer) from public, anon;
grant execute on function public.list_device_checkins(integer) to authenticated;

create or replace function public.prune_device_checkins_job()
returns void
language sql
security definer
set search_path to 'public'
as $function$
  delete from public.device_checkins
   where last_seen_at < now() - interval '180 days';
$function$;

revoke all on function public.prune_device_checkins_job()
  from public, anon, authenticated;

select cron.schedule(
  'prune-device-checkins',
  '58 3 * * *',
  'select public.prune_device_checkins_job()'
);

commit;
