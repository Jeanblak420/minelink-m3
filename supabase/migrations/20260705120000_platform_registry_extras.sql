-- Live "extras" for the super-admin Platform Registry tiles:
--   active_users_now — distinct users signed in within the last 5 minutes
--                      (auth.users.last_sign_in_at), powering the design's
--                      "Active users right now · signed-in · last 5m · ● Live" tile.
--   tons_24h         — net tons on trips created in the last 24 hours, used for
--                      the "Total tons managed" ▲%·24h growth delta.
-- Guarded with is_platform_admin() exactly like platform_logistics_totals so
-- only platform admins receive real values (everyone else gets zeros).
create or replace function public.platform_registry_extras()
returns table(active_users_now integer, tons_24h numeric)
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not public.is_platform_admin() then
    active_users_now := 0;
    tons_24h := 0;
    return next;
    return;
  end if;

  select count(*)::int into active_users_now
  from auth.users
  where last_sign_in_at > now() - interval '5 minutes';

  select coalesce(sum(net_tons), 0) into tons_24h
  from public.trips
  where created_at > now() - interval '24 hours';

  return next;
end;
$$;

grant execute on function public.platform_registry_extras() to authenticated;
