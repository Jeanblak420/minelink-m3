-- Targets, target cycles and their actuals move onto the mine's clock.
--
-- Jean's ruling, 2026-08-17. Three things were deciding a day here, and they
-- did not agree with each other or with the pit:
--
--   * `target_scope_daily_tons` bucketed tonnage `at time zone 'UTC'` while its
--     own window edges (`p_from::timestamptz`) used the SESSION zone. Same
--     answer today only because the session is also UTC.
--   * `target_scope_month_counts` bucketed months with a bare `to_char`, i.e.
--     the session zone, so it would have moved on its own if anybody had ever
--     changed that setting.
--   * Every cycle guard read `current_date`, a UTC calendar day. The one that
--     matters most is `lock_target_cycle`: it sets `started_on` to the 1st of
--     the FOLLOWING month, so a cycle locked at 00:30 SAST on 1 September saw
--     `current_date = 2026-08-31` and began on **1 September instead of 1
--     October** -- a whole month of an immutable twelve-month commitment, gone,
--     silently.
--
-- A comment in 20260808120000 argued for UTC on the grounds that recon was also
-- UTC, so "a late-evening load" could never fall on different days on the two
-- screens. Recon later moved to local (`raw_recon_row.dart`), which voided the
-- premise without anybody noticing. Both are now the same thing: the day at the
-- mine.
--
-- Jean accepted the consequence before this ran: historical target actuals move
-- for loads between 00:00 and 02:00 SAST, and closed cycles keep the frozen
-- actuals they were closed with.
--
-- HOW: the bodies are rewritten from `pg_get_functiondef` rather than retyped,
-- the pattern 20260816120000 established. Each replacement asserts its anchor
-- first, so a body that has drifted from what this migration expects fails
-- loudly instead of being silently left alone.

do $migrate$
declare
  v_src text;
  v_new text;
  v_fn text;
  v_sig text;
  v_n int;
begin
  -- 1. The two bucket helpers ------------------------------------------------
  select pg_get_functiondef(p.oid) into v_src
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'target_scope_daily_tons';
  if v_src is null then raise exception 'target_scope_daily_tons not found'; end if;
  if position('at time zone ''UTC''' in v_src) = 0 then
    raise exception 'target_scope_daily_tons: expected UTC bucket not found';
  end if;
  v_new := replace(v_src,
    '(coalesce(t.arrived_at, t.created_at) at time zone ''UTC'')::date',
    'public.ml_day(coalesce(t.arrived_at, t.created_at))');
  v_new := replace(v_new, 'p_from::timestamptz', 'public.ml_day_start(p_from)');
  v_new := replace(v_new, '(p_to + 1)::timestamptz', 'public.ml_day_start(p_to + 1)');
  execute v_new;

  select pg_get_functiondef(p.oid) into v_src
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'target_scope_month_counts';
  if v_src is null then raise exception 'target_scope_month_counts not found'; end if;
  if position('to_char(coalesce(t.arrived_at, t.created_at), ''YYYY-MM'')' in v_src) = 0 then
    raise exception 'target_scope_month_counts: expected trip month bucket not found';
  end if;
  v_new := replace(v_src,
    'to_char(coalesce(t.arrived_at, t.created_at), ''YYYY-MM'')',
    'to_char(public.ml_day(coalesce(t.arrived_at, t.created_at)), ''YYYY-MM'')');
  v_new := replace(v_new,
    'to_char(x.updated_at, ''YYYY-MM'')',
    'to_char(public.ml_day(x.updated_at), ''YYYY-MM'')');
  v_new := replace(v_new, 'p_from::timestamptz', 'public.ml_day_start(p_from)');
  v_new := replace(v_new, '(p_to + 1)::timestamptz', 'public.ml_day_start(p_to + 1)');
  execute v_new;

  -- 2. Everything that asked `current_date` what today is --------------------
  for v_fn, v_sig in
    select p.proname, pg_get_function_identity_arguments(p.oid)
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('get_targets_state', 'lock_target_cycle',
                        'guard_target_cycle', 'close_target_cycle',
                        'start_new_target_cycle', 'close_due_target_cycles_job',
                        'ensure_open_target_cycle', 'set_monthly_target')
  loop
    select pg_get_functiondef(p.oid) into v_src
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = v_fn
      and pg_get_function_identity_arguments(p.oid) = v_sig;

    -- Word-boundary replace so a column or comment containing the token as part
    -- of a longer identifier is left alone.
    v_new := regexp_replace(v_src, '\mcurrent_date\M', 'public.ml_today()', 'g');
    if v_new = v_src then
      -- Not every one of these necessarily reads it; say which, rather than
      -- assuming.
      raise notice 'no current_date in %(%)', v_fn, v_sig;
    else
      execute v_new;
      raise notice 'rebased %(%)', v_fn, v_sig;
    end if;
  end loop;

  select count(*) into v_n
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname in ('get_targets_state', 'lock_target_cycle',
                      'guard_target_cycle', 'close_target_cycle',
                      'start_new_target_cycle', 'close_due_target_cycles_job',
                      'ensure_open_target_cycle', 'set_monthly_target',
                      'target_scope_daily_tons', 'target_scope_month_counts')
    and p.prosrc like '%ml_today()%';
  raise notice 'functions now reckoning on ml_today(): %', v_n;
end
$migrate$;

comment on function public.target_scope_daily_tons(text, text, uuid, date, date) is
  'Daily actual tonnage for a target scope, bucketed on the day at the mine '
  '(ml_day) with window edges to match (ml_day_start). Was UTC-bucketed with '
  'session-zone edges -- the same answer only while the session was also UTC '
  '(20260817250000).';
