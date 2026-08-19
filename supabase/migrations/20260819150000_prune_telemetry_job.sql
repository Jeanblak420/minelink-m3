-- Retention for the two newest write paths: crash_reports (20260819140000/
-- 20260819145000) and device_tokens (20260819090000). Neither had a prune job
-- when it shipped, and CLAUDE.md §10.2 is explicit about the cost of that
-- gap: vehicle_positions went unpruned and reached 40 MB of index on 55 rows
-- of heap before anyone noticed. One job covers both tables here rather than
-- adding two cron entries for two DELETEs.
--
-- Batched and bounded, same shape as prune_vehicle_positions_job
-- (20260816150000): a p_max_rows cap per run, because an unbounded bulk
-- write on this exact free-plan instance is what locked autovacuum out and
-- took Postgres down for two hours on 2026-08-16. Both tables are new and
-- near-empty, so a single bounded DELETE per table (not a batching loop) is
-- enough headroom for the traffic either one will ever see -- 20,000 rows is
-- already an order of magnitude past plausible daily volume for crash
-- reports or idle device tokens.
--
-- This migration also carries five deferred corrections (brief Rulings 10
-- and 13): four comment corrections on crash_reports/device_tokens that this
-- file is what makes true, and one behavioural fix to
-- notifications_push_fanout. See each section below.

-- ---------------------------------------------------------------------------
-- Correction 1 + 2: crash_reports table comment.
--
-- (1) Both crash-reports migrations justified `user_id ... on delete set
-- null` by naming "an account deletion (R-1)". R-1 is deactivation now, and
-- deactivate_account never deletes a profiles row, so that sentence
-- described a path that does not fire. The column choice is still correct
-- -- SET NULL remains the right defensive choice if a profile is ever
-- deleted by some other route -- only the rationale was stale.
--
-- (2) The retention sentence hedged "added in 20260819150000 -- not yet
-- present as of this migration". This IS 20260819150000. The hedge is
-- dropped; it is now a present-tense fact.
-- ---------------------------------------------------------------------------
comment on table public.crash_reports is
  'Uncaught and handled errors shipped off-device by SupabaseReportingSink. '
  'user_id is SET NULL rather than CASCADE: R-1 is account deactivation, not '
  'deletion, and deactivate_account never deletes a profiles row, so that '
  'path does not fire today. SET NULL is kept anyway because it is still the '
  'right choice defensively -- if a profile is ever deleted by some other '
  'route, a crash report should be de-identified, not destroyed. '
  'INSERT is `to authenticated` only -- a pre-auth crash cannot write here '
  'directly (RLS denies `anon`, deliberately: see 20260819145000 header, '
  'the publishable key is public and this is a 500 MB free-plan project). '
  'SupabaseReportingSink buffers a failed pre-auth send in memory and drains '
  'it on the next successful send, so most pre-auth crashes arrive once the '
  'user signs in -- but a crash on a session that never signs in is never '
  'collected. That gap is accepted. '
  'Retention: pruned at 90 days by prune_telemetry_job(), added in '
  '20260819150000. '
  'error/stack are truncated client-side (4 kB / 16 kB) and bounded '
  'server-side by CHECK constraints of the same size, added in '
  '20260819145000, because this is a 500 MB free-plan project and an error '
  'loop can generate reports faster than anyone reads them.';

-- ---------------------------------------------------------------------------
-- Correction 3 + 4: device_tokens table comment.
--
-- (3) Its retention sentence was already present-tense ("Idle tokens are
-- removed at 180 days by prune_telemetry_job()") with no hedge, which made
-- it a false statement of fact from 20260819090000 until this migration.
-- No wording change is needed -- it becomes true the moment this file
-- applies.
--
-- (4) Records the accepted token-reassignment risk: register_device_token's
-- `on conflict (token) do update set user_id = auth.uid()` lets whoever
-- supplies a raw FCM token claim it. Reviewed and accepted: exploitation
-- requires already holding another user's opaque, high-entropy token (RLS
-- never exposes it), and the impact is denial of push on that one token,
-- not disclosure -- push-fanout selects tokens by the notification's
-- user_id, never by the token's claimed owner.
-- ---------------------------------------------------------------------------
comment on table public.device_tokens is
  'FCM registration tokens. UNIQUE on token, and register_device_token '
  're-points user_id on conflict: a shared depot tablet really does change '
  'hands, and a stale row would send one driver''s dispatch to another. '
  'Accepted risk: that same `on conflict (token) do update set user_id = '
  'auth.uid()` lets whoever supplies a raw FCM token claim it. Reviewed and '
  'accepted -- exploitation requires already holding another user''s '
  'opaque, high-entropy token (RLS never exposes it), and the impact is '
  'denial of push on that one token, not disclosure: push-fanout selects '
  'tokens by the notification''s user_id, never by the token''s claimed '
  'owner. '
  'Idle tokens are removed at 180 days by prune_telemetry_job().';

-- ---------------------------------------------------------------------------
-- Correction 5: notifications_push_fanout() never used the trimmed key.
--
-- The function tests `btrim(v_key) = ''` for emptiness but never reassigns
-- the trimmed value before concatenating it into the Authorization header.
-- A vault secret pasted with a trailing newline or space produces a header
-- that can never match -- and because this trigger swallows its own errors
-- by design, push would silently never work and nothing anywhere would say
-- why. The only change from the deployed 20260819090000 body is the single
-- `v_key := btrim(v_key);` line added below, once a non-blank key has been
-- resolved from either source and before it is used to build the request.
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

    v_key := btrim(v_key);

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

-- ---------------------------------------------------------------------------
-- Primary work: prune_telemetry_job.
-- ---------------------------------------------------------------------------
create or replace function public.prune_telemetry_job(
  p_crash_keep_days int default 90,
  p_token_idle_days int default 180,
  p_max_rows        int default 20000
)
returns int
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare v_n int := 0; v_c int;
begin
  delete from public.crash_reports
   where ctid in (
     select ctid from public.crash_reports
      where created_at < timezone('utc', now()) - make_interval(days => p_crash_keep_days)
      limit p_max_rows
   );
  get diagnostics v_c = row_count; v_n := v_n + v_c;

  delete from public.device_tokens
   where ctid in (
     select ctid from public.device_tokens
      where last_seen_at < timezone('utc', now()) - make_interval(days => p_token_idle_days)
      limit p_max_rows
   );
  get diagnostics v_c = row_count; v_n := v_n + v_c;

  return v_n;
end;
$$;

comment on function public.prune_telemetry_job(int, int, int) is
  'Nightly retention for the telemetry write paths: drops crash_reports '
  'older than p_crash_keep_days (default 90) and device_tokens idle past '
  'p_token_idle_days (default 180, by last_seen_at), each bounded at '
  'p_max_rows (default 20000) per table per run. Added 2026-08-19 so that '
  'neither new write path repeats vehicle_positions'' unbounded growth '
  '(CLAUDE.md §10.2: 40 MB of index on 55 rows before anyone noticed).';

-- Cron-only. This is not an API.
revoke execute on function public.prune_telemetry_job(int, int, int)
  from public, anon, authenticated;

-- 03:55 UTC, after the deactivation backstop (apply-due-account-deactivations,
-- 03:50) and offset from the rest of the nightly jobs so nothing overlaps on
-- a shared-CPU free-plan instance.
select cron.unschedule('prune-telemetry')
 where exists (select 1 from cron.job where jobname = 'prune-telemetry');

select cron.schedule('prune-telemetry', '55 3 * * *',
                     'select public.prune_telemetry_job()');
