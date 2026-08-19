-- S2-10 (G4), the last three holes in the RPC half.
--
-- 20260815094000 gated the RLS write policies; 20260815097000 put a
-- `guard_company_active` trigger on 20 tables, which covers the SECURITY
-- DEFINER RPCs regardless of what they check. Re-measuring afterwards found
-- three places that mechanism does not reach.
--
-- 94 mutating RPCs are executable by `authenticated` and every one is
-- SECURITY DEFINER. Measured, not assumed: `can_manage_fleet()` delegates to
-- `is_company_manager()` (active-gated since 094000), which closes the 10
-- fleet / maintenance / driver-limit RPCs; 30 are platform-admin gated; the
-- trigger covers 20 tables. What was left:
--
--   1. `employees` has NO write policy at all -- only a SELECT one. Direct
--      writes are therefore denied, and every employee mutation goes through
--      a SECURITY DEFINER RPC. The trigger is not on `employees` either. So
--      an expired company could still hire, re-role and dismiss, through the
--      one resolver all three RPCs share.
--   2. `is_company_stockpile_writer()` returns TRUE for an expired mine's
--      supervisorForeman. The write dies at the trigger, but the UI reads
--      this predicate to decide whether "Add tons" is enabled -- so the
--      button was live and the failure arrived as a trigger exception.
--   3. `record_truck_load` authorises with `is_company_staff()`, which tests
--      employment and not the licence, then runs a five-table cascade. The
--      trigger stops it, but partway through.
--
-- None of the three is a new *policy* decision; each is the existing
-- read-only ruling reaching somewhere it had not reached.

-- 1. The stockpile writer.
--
--    `is_company_manager()` already carries the active test, but the
--    `supervisorForeman` branch was ORed in beside it with no test of its own
--    -- so the one role §4 puts in charge of the order stockpile was the one
--    role expiry did not reach. Restructured so the active test applies to
--    BOTH branches rather than being inherited by one of them.
create or replace function public.is_company_stockpile_writer(p_company_id uuid)
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select (
      public.is_company_manager_any_status(p_company_id)
      or exists (
        select 1 from public.employees e
        where e.company_id = p_company_id
          and e.user_id = auth.uid()
          and e.role = 'supervisorForeman'
          and e.status = 'active'
          and coalesce(e.is_dismissed, false) = false
      )
    )
    and public.is_company_active(p_company_id);
$function$;

comment on function public.is_company_stockpile_writer(uuid) is
  'May this caller add tons to / record production against this company''s stockpiles? Manager or supervisorForeman, AND the company must be active (S2-10, 2026-08-15). The active test wraps both branches: before this, the manager branch inherited it from is_company_manager() and the supervisor branch had none, so an expired mine''s supervisor could still move ore.';

-- 2. The employee-management resolver.
--
--    It answers "which company may this caller administer", and every caller
--    of it mutates `employees`: create_company_managed_employee,
--    update_company_employee, remove_company_employee.
create or replace function public.get_managed_company_id_for_current_user()
returns uuid
language plpgsql
stable security definer
set search_path to 'public'
as $function$
declare
  managed_company_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select c.id
  into managed_company_id
  from public.companies c
  where c.user_id = auth.uid()
  limit 1;

  if managed_company_id is null then
    select e.company_id
    into managed_company_id
    from public.employees e
    where e.user_id = auth.uid()
      and e.company_id is not null
      and e.status = 'active'
      and e.is_dismissed = false
      and e.role in ('admin', 'management')
    limit 1;
  end if;

  if managed_company_id is null then
    raise exception 'Not authorized to manage company employees';
  end if;

  -- S2-10. Distinct SQLSTATE so the client can tell "your licence lapsed"
  -- from "you are not an admin" -- the two need different words and a
  -- different button, and a shared message sends the wrong person to support.
  if not public.is_company_active(managed_company_id) then
    raise exception
      'This company''s access has lapsed. Renew the licence to manage users.'
      using errcode = 'MLX01';
  end if;

  return managed_company_id;
end;
$function$;

comment on function public.get_managed_company_id_for_current_user() is
  'The company this caller may administer users for. Raises MLX01 when that company is not active (S2-10, 2026-08-15) - expiry stops a company changing its own configuration.';

-- 3. `record_truck_load`.
--
--    Rewritten by substitution rather than retyped. The body is 6,770
--    characters and CLAUDE.md §6 records that retyping SQL into a migration
--    risks silent drift from the source -- so the definition is read back
--    from the catalogue, one exact token is replaced, and the count is
--    asserted. A no-op or a double substitution raises instead of passing
--    quietly. Verified after: body 6,770 -> 6,777 (the seven added
--    characters of `_active`), 1 `is_company_staff_active(`, 0 legacy calls.
do $$
declare
  v_def text;
  v_new text;
  v_hits int;
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'record_truck_load';

  if v_def is null then
    raise exception 'record_truck_load not found';
  end if;

  v_hits := (length(v_def) - length(replace(v_def, 'is_company_staff(', '')))
            / length('is_company_staff(');
  if v_hits <> 1 then
    raise exception
      'record_truck_load: expected exactly 1 is_company_staff( call, found %',
      v_hits;
  end if;

  v_new := replace(v_def, 'is_company_staff(', 'is_company_staff_active(');
  execute v_new;
end
$$;

-- NOTE: the comment this migration originally set on `record_truck_load`
-- claimed that `set_trip_status` and the POD path were "deliberately NOT
-- gated". That was true of those functions and false of the system --
-- 20260815097000's trigger covers `trips` and `pod_uploads`. Corrected in
-- 20260815121000 rather than edited here, so the file matches what was
-- applied.
comment on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) is
  'Weighbridge load capture. Gated on is_company_staff_active() since S2-10 (2026-08-15): a load is the start of a delivery, and an expired company may not start new work. Trips already dispatched can still be completed - set_trip_status and the POD path are deliberately NOT gated.';
