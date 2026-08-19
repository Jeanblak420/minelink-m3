-- 20260815112000_employee_seat_limit_gate.sql
--
-- The seat gate. Client ruling 2026-08-15: BLOCK at the limit, and offer the
-- company a way to request more seats.
--
-- Until now nothing enforced a seat limit anywhere. Proven, not inferred:
-- Vis Mine carries seat_limit 0, seats_available 0 and 0 seats minted, already
-- had 2 active employees, and `create_company_managed_employee` created a third
-- with no refusal and no seat consumed. Neither of the two functions that
-- create an employee referenced `organization_seats` or `seat_limit`, and no
-- edge function mentions "seat" at all. Live shape: 87 active employees against
-- 18 occupied seats -- 69 people working with no seat.
--
-- WHY A TRIGGER RATHER THAN AN EDIT TO THE RPCs
--
-- A seat is consumed when an employee becomes ACTIVE, and two functions do
-- that: `create_company_managed_employee` (inserts 'active' outright) and
-- `assign_employee_role` (the pending_role -> active step of self-signup).
-- Editing both would mean retyping two long bodies into a migration, which is
-- how bodies silently drift from their files -- MIGRATION_HYGIENE already
-- warns about exactly that. A trigger adds one object, touches neither, and
-- catches every other path that could make somebody active, including
-- `super_admin_set_employee_status` and any direct write.
--
-- WHAT COUNTS AS A USED SEAT
--
-- Active, non-dismissed employees of the company. NOT `companies.seats_used`
-- and NOT `organization_seats.status = 'occupied'`: both were measured against
-- reality and both are unreliable. Land Rover has 2 active employees and 0
-- occupied seats; ABC Mine carries seats_used = 3 with 0 employees and 0 seats
-- minted; Roadhaul has 4 active employees against 3 occupied seats. The
-- employee rows are the only count that matches who can actually sign in.
--
-- seat_limit NULL or 0 therefore means NO seats, and the company is blocked
-- until it is issued some. That is the commercial model working as intended --
-- `create_serial_token` is what sets a seat limit - but it does bite today on
-- 6 companies that hold active employees with seat_limit 0 (Vis Mine, Probe
-- Mine, Chat Debug Mine and the three Test Live orgs). All 6 are test/debug
-- companies and none holds a token. No existing employee is touched: the
-- trigger fires only on INSERT and UPDATE, so everyone already active stays
-- active. A company that is over its limit simply cannot add another.
--
-- SECURITY DEFINER is load-bearing. The count has to be taken as the owner --
-- a count taken under the caller's RLS is a count of what that caller may see,
-- which has already produced two false zeros on this project.
--
-- The platform admin is exempt. They are the party that sells seats and has to
-- be able to correct data; a company manager is the party the limit is for.
--
-- The error carries SQLSTATE 'MLS01' so the app can tell this refusal apart
-- from every other failure and open the "request more seats" dialog, rather
-- than matching on message text.

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

  -- Already active before this write: a rename or a role change, not a new seat.
  if tg_op = 'UPDATE'
     and old.status = 'active'
     and coalesce(old.is_dismissed, false) = false then
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

comment on function public.enforce_employee_seat_limit() is
  'Blocks an employee becoming active once the company has no free seat. '
  'Raises SQLSTATE MLS01 so the client can offer "request extra seats". '
  'Counts active non-dismissed employees, not companies.seats_used or '
  'organization_seats - both were measured unreliable. See 20260815112000.';

drop trigger if exists employees_seat_limit on public.employees;

create trigger employees_seat_limit
  before insert or update on public.employees
  for each row
  execute function public.enforce_employee_seat_limit();
