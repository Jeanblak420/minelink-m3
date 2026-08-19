-- 20260815114000_seat_limit_on_company_change.sql
--
-- A hole in the seat gate shipped two migrations ago (20260815112000), found
-- while preparing to move company-less employees onto companies.
--
-- The trigger returned early whenever the row was ALREADY active before the
-- write, on the reasoning that a rename or a role change consumes no new seat.
-- That is true only while the employee stays at the same company. Moving an
-- active employee from company A to company B — or from no company at all onto
-- one — takes a seat at B, and the early return skipped the check entirely. So
-- the limit could be exceeded simply by transferring somebody in.
--
-- The fix is one added condition: the early return now also requires the
-- company to be unchanged. A transfer is charged a seat at its destination,
-- which is what a seat means.
--
-- Everything else is as 20260815112000 left it.

create or replace function public.enforce_employee_seat_limit()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_limit int;
  v_used int;
  v_company text;
begin
  -- Only a row that is (becoming) an active, non-dismissed employee takes a seat.
  if new.status is distinct from 'active' or coalesce(new.is_dismissed, false) then
    return new;
  end if;

  -- Already active AT THE SAME COMPANY before this write: a rename or a role
  -- change, not a new seat. A move to a different company IS a new seat, so it
  -- falls through to the check below.
  if tg_op = 'UPDATE'
     and old.status = 'active'
     and coalesce(old.is_dismissed, false) = false
     and old.company_id is not distinct from new.company_id then
    return new;
  end if;

  -- A self-signup row has no company yet; nothing to charge a seat against.
  if new.company_id is null then
    return new;
  end if;

  -- The vendor can always act; the limit is a control on the company.
  if public.is_platform_admin() then
    return new;
  end if;

  select c.seat_limit, c.company_name
    into v_limit, v_company
    from public.companies c
   where c.id = new.company_id;

  select count(*)
    into v_used
    from public.employees e
   where e.company_id = new.company_id
     and e.status = 'active'
     and coalesce(e.is_dismissed, false) = false
     and e.id is distinct from new.id;

  if v_used >= coalesce(v_limit, 0) then
    raise exception using
      errcode = 'MLS01',
      message = case
        when coalesce(v_limit, 0) = 0 then
          format('%s has no user seats yet, so nobody can be added. '
                 || 'Request seats from the platform team to continue.',
                 coalesce(v_company, 'This company'))
        else
          format('All %s seat(s) at %s are in use. '
                 || 'Request extra seats to add another person.',
                 v_limit, coalesce(v_company, 'this company'))
      end,
      hint = 'seat_limit_reached';
  end if;

  return new;
end;
$function$;
