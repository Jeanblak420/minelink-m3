-- one-clock-exempt: this migration is what rewrites current_date away
--
-- The last four functions still asking UTC what day it is.
--
-- `20260817250000` moved targets and the two bucket helpers onto `ml_today()`.
-- These were not in that list and are the rest of it. All four decide a
-- **business day**, which is what the ruling of 2026-08-17 is about.
--
--   * `guard_monthly_target` -- the lock that makes a closed month's target
--     immutable. It compares the target's period against
--     `date_trunc('month', current_date)`. Between 00:00 and 02:00 SAST on the
--     1st of a month, UTC is still on the last day of the previous month, so
--     the month that has just closed reads as the *current* one and the guard
--     does not fire. A two-hour window, every month, in which a closed target
--     can still be edited or created -- and immutability is the whole feature.
--
--   * `list_compliance_documents` -- `days_to_expiry`, and the
--     expired/expiring/valid classification a company manages renewals by. A
--     licence expiring today reads as `expired` for the first two hours of the
--     day it is actually still valid.
--
--   * `_profile_setup_payload` -- the same classification again, on the
--     Account setup screen, plus `days_to_expiry`.
--
--   * `notify_expiring_documents_job` -- the nightly cron. It both selects the
--     rows to warn about (`expires_at <= current_date + 30`) and decides the
--     wording ("EXPIRED on" vs "expires"). Getting the day wrong here sends a
--     person a notification saying their valid document has expired.
--
-- HOW: bodies rewritten from `pg_get_functiondef` rather than retyped, the
-- pattern established by 20260816120000 and reused by 20260817250000. The
-- replacement is word-boundary anchored (`\m...\M`) so an identifier that
-- merely contains the token is left alone, and each function must actually
-- change or the migration says so.

do $migrate$
declare
  v_fn text;
  v_sig text;
  v_src text;
  v_new text;
  v_left int;
begin
  for v_fn, v_sig in
    select p.proname, pg_get_function_identity_arguments(p.oid)
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('guard_monthly_target', 'list_compliance_documents',
                        '_profile_setup_payload', 'notify_expiring_documents_job')
  loop
    select pg_get_functiondef(p.oid) into v_src
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = v_fn
      and pg_get_function_identity_arguments(p.oid) = v_sig;

    if position('current_date' in v_src) = 0 then
      raise exception '%(%): expected current_date, found none', v_fn, v_sig;
    end if;

    v_new := regexp_replace(v_src, '\mcurrent_date\M', 'public.ml_today()', 'g');
    execute v_new;
    raise notice 'rebased %(%)', v_fn, v_sig;
  end loop;

  -- Nothing in the schema may still be deciding a business day on the UTC
  -- calendar. `now()` on its own is an instant and is fine; `current_date` is
  -- a calendar day and is not.
  select count(*) into v_left
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.prosrc ~ '\mcurrent_date\M';
  if v_left <> 0 then
    raise exception 'still % function(s) reckoning on current_date', v_left;
  end if;
  raise notice 'no function in public decides a day on the UTC calendar any more';
end
$migrate$;

comment on function public.guard_monthly_target() is
  'Refuses a write to a target for a month that has already closed. Closed is '
  'measured on the South African calendar (ml_today): on the UTC one the guard '
  'did not fire between 00:00 and 02:00 SAST on the 1st, leaving a just-closed '
  'target editable for two hours every month (20260817260000).';

comment on function public.list_compliance_documents(uuid) is
  'Compliance documents with days_to_expiry and an expired/expiring/valid '
  'status, reckoned on the day at the mine (ml_today). A document expiring '
  'today used to read as expired for the first two hours of that day.';
