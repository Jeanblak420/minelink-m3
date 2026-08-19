-- The backstop. A queue an admin never actions leaves a user unable to leave;
-- this bounds it at 30 days. Under the deletion design the bound mattered
-- because it bounded an irreversible act -- under deactivation it is safer
-- still, since anything applied here can be undone by reactivate_account with
-- nothing lost.
--
-- Plain SQL. No pg_net, no edge function, no service-role key -- deactivation
-- destroys nothing, so there is no storage purge and nothing to reach over
-- HTTP for. deactivate_account (20260819110000/20260819115000) already
-- accepts a no-JWT caller as the cron backstop's own signal (auth.uid() is
-- null), verified live 2026-08-19: called with no JWT inside a rolled-back
-- transaction it succeeded, set banned_until = infinity, and wrote exactly
-- one ACCOUNT_DEACTIVATED audit row with actor_platform_role = 'system'.
--
-- THE MLD01 DECISION -- a company owner is excluded from this job's
-- selection query up front (see the WHERE clause below), NOT left to be
-- attempted and caught every night.
--
-- deactivate_account raises MLD01 for a company owner by design (companies
-- are never left ownerless), and request_account_deactivation already
-- refuses the request at the front door -- but review_account_deactivation_
-- request does not re-check ownership at review time, so a user who becomes
-- a company owner (ownership transfer) after their request was approved, but
-- before this job runs, is a real, reachable path to an 'approved' row that
-- can never legally be applied. Catching that in the per-row exception
-- handler below would "work" in the sense of not crashing the loop, but it
-- would also re-raise the identical warning, for the identical row, every
-- single night forever -- a permanent retry with zero chance of ever
-- succeeding, and log noise nobody reads. Excluding it here instead means:
-- no wasted attempt, no nightly warning spam, and the row stays exactly
-- where a human already has visibility into it --
-- list_account_deactivation_requests already returns is_company_owner as a
-- reviewer-facing chip for precisely this state. Resolution requires a
-- platform admin (transfer ownership again, or suspend the company via
-- super_admin_set_company_status) -- the same two routes
-- request_account_deactivation's own MLD01 message names -- not a nightly
-- cron loop hammering a permanent refusal.
--
-- The per-row exception handler stays anyway, as a backstop for genuinely
-- unexpected failures (this is the close_due_target_cycles_job lesson: an
-- exception escaping the loop freezes the nightly run for every other row) --
-- but with the company-owner case excluded up front, it is no longer
-- expected to fire on MLD01 in the ordinary course of business.

create or replace function public.apply_due_account_deactivations_job()
returns int
language plpgsql
security definer
set search_path = public, extensions, pg_temp
as $$
declare
  v_row   record;
  v_count int := 0;
begin
  for v_row in
    select r.user_id
      from public.account_deactivation_requests r
     where (r.status = 'approved'
            or (r.status = 'pending' and r.auto_apply_at <= timezone('utc', now())))
       -- See the MLD01 decision above: a company owner is skipped up front,
       -- not attempted-and-caught, so the row is never retried into a
       -- permanent nightly warning. It stays visible to a platform admin via
       -- list_account_deactivation_requests.is_company_owner instead.
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
    -- already excluded by the WHERE clause above, so this handler is a
    -- backstop for the genuinely unexpected -- not the expected steady state.
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
  '-- see the MLD01 decision in the file header; they stay visible to an '
  'admin via list_account_deactivation_requests.is_company_owner. Never '
  'reactivates: that is platform-admin only, deliberately.';

revoke execute on function public.apply_due_account_deactivations_job()
  from public, anon, authenticated;

select cron.unschedule('apply-due-account-deactivations')
 where exists (select 1 from cron.job where jobname = 'apply-due-account-deactivations');

-- 03:50 UTC. Checked live against cron.job 2026-08-19 -- the nine existing
-- jobs are at :00, :07 (hourly), 2:15, 2:45, 3:20, 3:40, 4:10, 4:25, 4:40.
-- 03:50 sits 10 minutes clear of the nearest neighbour (prune-vehicle-
-- positions at 3:40) so they do not contend on a shared-CPU free-plan
-- instance.
select cron.schedule(
  'apply-due-account-deactivations',
  '50 3 * * *',
  'select public.apply_due_account_deactivations_job()'
);
