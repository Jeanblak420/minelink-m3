-- "Active users right now" counts people actually using the app.
--
-- It counted auth.users.last_sign_in_at in the last 5 minutes: people who had
-- just typed a password. Someone working in the app all day counted for five
-- minutes after signing in and never again, and a token refresh does not move
-- last_sign_in_at, so the figure read 0 or 1 whatever was happening.
--
-- Every open app now writes profiles.last_seen_at every 45 s
-- (chat_touch_last_seen; the app now runs it for the whole session, not only
-- once the chat panel is opened, plus once on returning to the app). Two
-- minutes allows one missed beat. Return shape unchanged; tons_24h unchanged.
begin;

create or replace function public.platform_registry_extras()
returns table(active_users_now integer, tons_24h numeric)
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not public.is_platform_admin() then
    active_users_now := 0;
    tons_24h := 0;
    return next;
    return;
  end if;

  select count(*)::int into active_users_now
  from public.profiles
  where last_seen_at > now() - interval '2 minutes';

  select coalesce(sum(net_tons), 0) into tons_24h
  from public.trips
  where created_at > now() - interval '24 hours';

  return next;
end;
$function$;

commit;
