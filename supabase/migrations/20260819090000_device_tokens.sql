-- POST_NOTIFICATIONS was declared in AndroidManifest.xml with nothing behind
-- it. Notifications reached a user only while the app was open, which on a
-- logistics platform means a driver learns a load is ready when they next
-- happen to look -- and Play asks why a permission is declared but unused.

create table if not exists public.device_tokens (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles(id) on delete cascade,
  token       text not null unique,
  platform    text not null check (platform in ('android','ios','web')),
  app_version text,
  created_at  timestamptz not null default timezone('utc', now()),
  last_seen_at timestamptz not null default timezone('utc', now()),
  disabled_at timestamptz
);

comment on table public.device_tokens is
  'FCM registration tokens. UNIQUE on token, and register_device_token '
  're-points user_id on conflict: a shared depot tablet really does change '
  'hands, and a stale row would send one driver''s dispatch to another. '
  'Idle tokens are removed at 180 days by prune_telemetry_job().';

create index if not exists device_tokens_live_idx
  on public.device_tokens (user_id) where disabled_at is null;

alter table public.device_tokens enable row level security;

drop policy if exists device_tokens_select_own on public.device_tokens;
create policy device_tokens_select_own on public.device_tokens
  for select to authenticated using (user_id = auth.uid());

grant select on public.device_tokens to authenticated;

create or replace function public.register_device_token(
  p_token text, p_platform text, p_app_version text default null
)
returns uuid
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare v_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Not signed in' using errcode = '42501';
  end if;
  if nullif(btrim(coalesce(p_token,'')),'') is null then
    raise exception 'A device token is required' using errcode = '22023';
  end if;

  insert into public.device_tokens (user_id, token, platform, app_version)
  values (auth.uid(), p_token, p_platform, p_app_version)
  on conflict (token) do update
    set user_id      = auth.uid(),   -- the device changed hands
        platform     = excluded.platform,
        app_version  = excluded.app_version,
        last_seen_at = timezone('utc', now()),
        disabled_at  = null          -- it is demonstrably alive again
  returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.unregister_device_token(p_token text)
returns void
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
begin
  delete from public.device_tokens
   where token = p_token and user_id = auth.uid();
end;
$$;

revoke execute on function public.register_device_token(text, text, text) from public, anon;
revoke execute on function public.unregister_device_token(text) from public, anon;
grant execute on function public.register_device_token(text, text, text) to authenticated;
grant execute on function public.unregister_device_token(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Fan-out: trigger + pg_net, NOT an outbox drained by cron.
--
-- Cron's minimum useful period is a minute, and the case this feature exists
-- for is telling a driver a load is ready. A minute of latency on dispatch is
-- the difference between the feature working and it being a slower version of
-- the bell they already have.
--
-- pg_net is async and fire-and-forget, which is the property that makes it
-- safe to hang off the write path at all: the trigger cannot slow down or
-- fail a notification insert.
--
-- CONTROLLER RULING 12 (2026-08-19), overriding the original brief here:
-- production has `app.settings.supabase_url` NULL, `app.settings.
-- service_role_key` unset, and an empty `vault.decrypted_secrets` -- so a
-- naive `'Bearer ' || current_setting('app.settings.service_role_key', true)`
-- concatenation would mint a useless "Bearer " header and every push POST
-- would 401, silently, forever, because the outer handler swallows it. That
-- is worse than not shipping the feature: it looks like it works.
--
-- A service-role key must never be committed into a migration, and none is
-- available in this environment to configure either mechanism. So this
-- function resolves its key from Vault first (`supabase_vault`, already
-- installed on this project), falls back to `app.settings.service_role_key`,
-- and if NEITHER yields a key it returns immediately -- no POST, no warning,
-- no exception. That is the known, expected, documented state until Jean
-- wires one of the two up. It mirrors PlaceIndexConfig's contract for the
-- paused extras project: a capability that can be legitimately missing must
-- degrade quietly, not raise a warning on every single notification insert
-- and train people to ignore warnings.
--
-- TO TURN THIS ON: either
--   select vault.create_secret('<service-role-key>', 'push_fanout_service_role_key');
-- or
--   alter database postgres set app.settings.service_role_key = '<key>';
-- (and optionally app.settings.supabase_url, which otherwise falls back to
-- the literal project URL below -- not a secret, already all over this repo).
-- ---------------------------------------------------------------------------
create or replace function public.notifications_push_fanout()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_key text;
  v_url text;
begin
  -- Outermost safety net: nothing in this function may ever propagate an
  -- exception back to the INSERT that fired it. Every step below already has
  -- its own narrower handler; this one exists only to catch something none
  -- of them anticipated.
  begin
    v_key := null;

    -- Vault first. A missing extension, a missing secret, or no SELECT
    -- privilege on vault.decrypted_secrets are all the same case here: no
    -- key from this mechanism, try the fallback.
    begin
      select decrypted_secret
        into v_key
        from vault.decrypted_secrets
       where name = 'push_fanout_service_role_key'
       limit 1;
    exception when others then
      v_key := null;
    end;

    if v_key is null or btrim(v_key) = '' then
      v_key := nullif(current_setting('app.settings.service_role_key', true), '');
    end if;

    if v_key is null or btrim(v_key) = '' then
      -- Absence is the expected, documented state -- see the header comment.
      -- No POST, no warning: a warning on every notification insert is noise
      -- that trains people to ignore warnings.
      return new;
    end if;

    v_url := coalesce(
      nullif(current_setting('app.settings.supabase_url', true), ''),
      'https://yftazblpmicqtamyiwyb.supabase.co'
    );

    begin
      perform net.http_post(
        url     => v_url || '/functions/v1/push-fanout',
        body    => jsonb_build_object('notification_id', new.id),
        headers => jsonb_build_object(
                     'Content-Type', 'application/json',
                     'Authorization', 'Bearer ' || v_key
                   ),
        timeout_milliseconds => 10000
      );
    exception when others then
      -- A push that cannot be dispatched must never cost the in-app
      -- notification that is already written. Warn and carry on.
      raise warning 'push fanout failed for notification %: %', new.id, sqlerrm;
    end;
  exception when others then
    -- Belt and braces: see the comment above the outer `begin`.
    raise warning 'push fanout trigger errored for notification %: %', new.id, sqlerrm;
  end;

  return new;
end;
$$;

drop trigger if exists notifications_push_fanout on public.notifications;
create trigger notifications_push_fanout
  after insert on public.notifications
  for each row execute function public.notifications_push_fanout();
