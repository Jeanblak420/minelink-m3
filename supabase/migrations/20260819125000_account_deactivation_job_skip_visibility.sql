-- Fix round 1 for 20260819120000. One Important, from the coordinator's
-- review: the up-front company-owner exclusion (correctly judged the right
-- call -- catching MLD01 per row would be an unresolvable nightly warning
-- forever) was SILENT. A row excluded before the loop never enters the
-- exception path, so nothing was logged -- the job returned 0 identically
-- whether nothing was due or N rows were quietly passed over.
--
-- That silence compounds with two facts the reviewer verified:
--   - list_account_deactivation_requests defaults to p_status = 'pending',
--     and a stuck row is 'approved' -- invisible under the default filter
--     (Task 10's job to fix the console default; not touched here).
--   - review_account_deactivation_request does NOT block approving an
--     owner's request -- is_company_owner is informational only.
-- So a request can be approved, then orphaned by an ownership transfer, and
-- sit forever with zero log trace and zero notification -- the exact
-- "quietly does nothing" failure this whole backstop exists to prevent, just
-- moved one layer up, onto the backstop itself.
--
-- THE FIX: count the excluded rows once, before the loop, and log that count
-- with a single `raise warning` naming the number -- not one per row. A
-- second migration rather than an edit to 20260819120000: that file is
-- already applied and stamped (CLAUDE.md s6 rule 1).
--
-- WHY ONCE-PER-RUN, NOT PER-ROW -- said explicitly so nobody later "improves"
-- this into the exact spam the original design avoided: the whole reason the
-- owner case is excluded from the loop (rather than left to the per-row
-- exception handler) is that MLD01 recurs identically every night for as
-- long as the row is stuck, and a warning per stuck row per night is noise
-- nobody reads. One line naming the count keeps the run's outcome legible
-- (skip count vs. nothing-was-due) without reproducing that noise -- it
-- reports the STATE once, not the EVENT per row.
--
-- The return value's meaning is unchanged on purpose: it still counts rows
-- actually deactivated, because that is what a caller checking "did real
-- work happen, and how much" wants, and conflating it with a skip count
-- would make a bounded 200-row LIMIT ambiguous about which kind of row
-- filled it. The warning is where the skip count is surfaced.

create or replace function public.apply_due_account_deactivations_job()
returns int
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_row     record;
  v_count   int := 0;
  v_skipped int;
begin
  -- Count once, before the loop -- see file header for why once-per-run and
  -- not per-row. Same due-predicate as the loop below; the only difference
  -- is this counts the ones the loop's WHERE clause excludes for ownership.
  select count(*) into v_skipped
    from public.account_deactivation_requests r
   where (r.status = 'approved'
          or (r.status = 'pending' and r.auto_apply_at <= timezone('utc', now())))
     and exists (select 1 from public.companies co where co.user_id = r.user_id);

  if v_skipped > 0 then
    raise warning
      'apply_due_account_deactivations_job: % request(s) skipped -- requester owns a company; transfer ownership or suspend the company',
      v_skipped;
  end if;

  for v_row in
    select r.user_id
      from public.account_deactivation_requests r
     where (r.status = 'approved'
            or (r.status = 'pending' and r.auto_apply_at <= timezone('utc', now())))
       -- See the MLD01 decision in 20260819120000's file header: a company
       -- owner is skipped up front, not attempted-and-caught, so the row is
       -- never retried into a permanent nightly warning per row. Counted and
       -- logged once above instead, so this exclusion is no longer silent.
       and not exists (
             select 1 from public.companies co where co.user_id = r.user_id
           )
     order by r.requested_at
     -- Bounded. An unbounded nightly loop is the shape that took this instance
     -- down on 2026-08-16; there will never be 200 of these in a night, and if
     -- there are, something is wrong and slower is correct.
     limit 200
  loop
    -- One bad row must not stop the rest. This is the close_due_target_cycles_job
    -- lesson: an exception propagating out of the loop freezes the nightly run
    -- for every other scope. The ordinary MLD01 case (a company owner) is
    -- already excluded and counted by the WHERE clause + count above, so this
    -- handler is a backstop for the genuinely unexpected -- not the expected
    -- steady state.
    begin
      perform public.deactivate_account(v_row.user_id);
      v_count := v_count + 1;
    exception when others then
      raise warning 'apply_due_account_deactivations_job: user % skipped: %',
        v_row.user_id, sqlerrm;
    end;
  end loop;

  return v_count;
end;
$$;

comment on function public.apply_due_account_deactivations_job() is
  'Applies approved deactivation requests, and pending ones 30 days old. Plain '
  'SQL -- no pg_net and no edge function, because deactivation destroys '
  'nothing and needs no storage purge. Company owners are excluded from the '
  'selection query up front (never retried into a permanent nightly warning) '
  '-- see the MLD01 decision in 20260819120000''s file header; a single '
  '`raise warning` naming the count is logged once per run when any are '
  'excluded (fixed 20260819125000: the exclusion used to be silent), and they '
  'stay visible to an admin via '
  'list_account_deactivation_requests.is_company_owner. The return value '
  'counts only rows actually deactivated, not skipped ones. Never '
  'reactivates: that is platform-admin only, deliberately.';

-- No grant/cron change -- same function identity, same signature, same
-- privileges as 20260819120000. Nothing else to repoint here.
