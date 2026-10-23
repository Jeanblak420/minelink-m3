-- Seats follow active employees — counted, listed and kept in step.
--
-- Applied from the M3 project on 2026-10-24 with Jean's explicit OK
-- ("This is me giving you my EXPLICIT OK to apply", ADMIN-MOBILE-TODO.md 1.3).
--
-- WHAT WAS WRONG (measured on production 2026-10-23/24)
--
--   * `companies.seats_used` was 0 for every company. AB mine had 4 active
--     employees and AB trans 1; the console said 0 of 10 used for both.
--   * No seat row in `organization_seats` was ever occupied (0 of 30).
--   * Both had been kept up by triggers on `employees`
--     (`sync_company_seats_used_after_employees`, from
--     20260510190000). Production dropped them out of band, and
--     20260712175000 recorded the drop — so nothing has updated either since.
--   * `approve_token_request` (seat expansion) still CALLS
--     `recompute_company_seats_used` and `sync_organization_seats`, both
--     dropped: approving a seat request raised "function does not exist".
--   * `super_admin_release_organization_seat` called the dropped
--     `recompute_company_seats_used` and set a column that does not exist
--     (`occupied_by_employee_id`): "Remove from seat" always failed.
--   * `super_admin_set_employee_status` writes status 'suspended', which
--     `employees_status_check` does not allow: "Suspend user" always failed.
--   * `audit_logs_target_type_check` does not allow 'employee' or 'company',
--     which `super_admin_set_employee_status`, `super_admin_set_employee_role`
--     and `super_admin_set_company_status` (and the app's insights-export log)
--     write. So Suspend / Reactivate user, Change role and Suspend company
--     ALL failed on their own audit entry, after the status fix too. Found by
--     the dry run of this migration, 2026-10-24.
--   * `create_serial_token` checked a new seat limit against OCCUPIED SEAT
--     ROWS (always 0), so a token could be issued with fewer seats than the
--     company had people.
--
-- THE RULE (one, used everywhere)
--
--   A seat is held by every employee with status 'active' who is not
--   dismissed. That is the rule `enforce_employee_seat_limit` has enforced on
--   every insert/update all along; `company_seats_in_use()` is its count, and
--   everything below reads that function.
--
-- WHAT THIS DOES
--
--   1. Allows employee status 'suspended' (the console's Suspend action), and
--      audit entries about an 'employee' or a 'company'.
--   2. `company_seats_in_use(company)` — the count.
--   3. `recompute_company_seats_used(company)` — recreated (same signature
--      approve_token_request calls): seats_used and seats_available.
--   4. `sync_company_seat_holders(company)` — seat rows follow the people:
--      a holder who is no longer active loses the seat; an active person
--      without one gets the lowest free seat (a seat bound to their role
--      first). Serialised per company with an advisory lock, so two changes
--      at once cannot hand out the same seat.
--   5. `sync_organization_seats(company, limit)` — recreated (same signature):
--      seat rows 1..limit exist, holders above a reduced limit move down,
--      free seats above it are disabled, raised limits re-enable them.
--   6. Triggers: on employees (insert/delete/update of the columns that
--      matter) and on companies (update of seat_limit).
--   7. create_serial_token counts people, not seat rows (catalog patch,
--      anchor asserted — its body is not defined in full in any file).
--   8. Remove from seat = suspend that person (the seat frees itself).
--   9. Reassign seat = move the seat from its holder to a company member who
--      has none: the holder is suspended, the new person activated, and the
--      seat number kept. Still limited to 2 per 30 days.
--  10. Backfill every company.
--
-- ROLLBACK (if ever needed)
--
--   drop trigger employees_sync_seats on public.employees;
--   drop trigger companies_sync_seats on public.companies;
--   drop function public.employees_sync_seats(), public.companies_sync_seats(),
--     public.sync_company_seat_holders(uuid), public.company_seats_in_use(uuid);
--   -- recompute_company_seats_used / sync_organization_seats are needed by
--   -- approve_token_request; leave them. create_serial_token, reassign_seat
--   -- and super_admin_release_organization_seat: restore from
--   -- backup/pre-admin-mobile-2026-10-24 notes or the git history of this file.
--   -- The status constraint may keep 'suspended' (widening is harmless).

begin;

-- 1. 'suspended' is a real employee status -------------------------------------
alter table public.employees drop constraint if exists employees_status_check;
alter table public.employees add constraint employees_status_check check (
  status = any (array[
    'pending_company', 'pending_role', 'active', 'rejected',
    'dismissed', 'inactive', 'suspended'
  ])
);

alter table public.audit_logs drop constraint if exists audit_logs_target_type_check;
alter table public.audit_logs add constraint audit_logs_target_type_check check (
  target_type = any (array[
    'organization', 'company', 'user', 'employee', 'serialToken', 'seat',
    'seatRequest', 'tokenRequest', 'childAdmin', 'system'
  ])
);

-- 2. The count -----------------------------------------------------------------
create or replace function public.company_seats_in_use(p_company_id uuid)
returns integer
language sql
stable
security definer
set search_path = public
as $$
  select count(*)::int
    from public.employees e
   where e.company_id = p_company_id
     and e.status = 'active'
     and coalesce(e.is_dismissed, false) = false
$$;

comment on function public.company_seats_in_use(uuid) is
  'Seats a company is using: its active, non-dismissed employees. The same '
  'rule enforce_employee_seat_limit applies; every seat figure reads this.';

-- 3. seats_used / seats_available ---------------------------------------------
create or replace function public.recompute_company_seats_used(target_company_id uuid)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  used_count integer;
begin
  if target_company_id is null then
    return 0;
  end if;

  used_count := public.company_seats_in_use(target_company_id);

  update public.companies c
     set seats_used = used_count,
         seats_available = greatest(c.seat_limit - used_count, 0)
   where c.id = target_company_id
     and (c.seats_used is distinct from used_count
          or c.seats_available is distinct from greatest(c.seat_limit - used_count, 0));

  return used_count;
end;
$$;

-- 4. Seat rows follow the people -----------------------------------------------
create or replace function public.sync_company_seat_holders(p_company_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  emp record;
  v_seat uuid;
  v_now timestamptz := timezone('utc', now());
begin
  if p_company_id is null then
    return;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('company_seats:' || p_company_id::text, 0));

  -- A holder who is no longer an active member of this company frees the seat.
  update public.organization_seats s
     set status = 'available',
         occupied_by_user_id = null,
         occupied_by_name = null,
         occupied_by_email = null,
         occupied_by_employee_role = null,
         assigned_at = null,
         released_at = v_now,
         updated_at = v_now
   where s.organization_id = p_company_id
     and s.status = 'occupied'
     and not exists (
       select 1 from public.employees e
        where e.company_id = p_company_id
          and e.user_id = s.occupied_by_user_id
          and e.status = 'active'
          and coalesce(e.is_dismissed, false) = false);

  -- One seat per person: any second seat held by the same person is freed.
  update public.organization_seats s
     set status = 'available',
         occupied_by_user_id = null,
         occupied_by_name = null,
         occupied_by_email = null,
         occupied_by_employee_role = null,
         assigned_at = null,
         released_at = v_now,
         updated_at = v_now
   where s.organization_id = p_company_id
     and s.status = 'occupied'
     and exists (
       select 1 from public.organization_seats s2
        where s2.organization_id = s.organization_id
          and s2.status = 'occupied'
          and s2.occupied_by_user_id = s.occupied_by_user_id
          and s2.seat_number < s.seat_number);

  -- Holders' names, emails and roles stay current.
  update public.organization_seats s
     set occupied_by_name = nullif(trim(coalesce(e.first_name, '') || ' '
                                        || coalesce(e.last_name, '')), ''),
         occupied_by_email = p.email,
         occupied_by_employee_role = e.role,
         updated_at = v_now
    from public.employees e
    join public.profiles p on p.id = e.user_id
   where s.organization_id = p_company_id
     and s.status = 'occupied'
     and e.company_id = p_company_id
     and e.user_id = s.occupied_by_user_id
     and e.status = 'active'
     and coalesce(e.is_dismissed, false) = false
     and (s.occupied_by_name is distinct from nullif(trim(coalesce(e.first_name, '')
                                   || ' ' || coalesce(e.last_name, '')), '')
          or s.occupied_by_email is distinct from p.email
          or s.occupied_by_employee_role is distinct from e.role);

  -- Everyone active without a seat gets the lowest free one, longest-serving
  -- first; a seat bound to their role is preferred, then an unbound one. A
  -- person with no free seat left stays counted (seats_used) but unseated —
  -- only a platform admin can put a company over its limit.
  for emp in
    select e.user_id, e.role, e.first_name, e.last_name, p.email
      from public.employees e
      join public.profiles p on p.id = e.user_id
     where e.company_id = p_company_id
       and e.status = 'active'
       and coalesce(e.is_dismissed, false) = false
       and not exists (
         select 1 from public.organization_seats s
          where s.organization_id = p_company_id
            and s.status = 'occupied'
            and s.occupied_by_user_id = e.user_id)
     order by e.created_at, e.id
  loop
    v_seat := null;
    select s.id into v_seat
      from public.organization_seats s
     where s.organization_id = p_company_id
       and s.status = 'available'
       and (s.role_binding is null or s.role_binding = emp.role)
     order by (s.role_binding is not distinct from emp.role) desc, s.seat_number
     limit 1
     for update;

    if v_seat is null then
      continue;
    end if;

    update public.organization_seats
       set status = 'occupied',
           occupied_by_user_id = emp.user_id,
           occupied_by_name = nullif(trim(coalesce(emp.first_name, '') || ' '
                                          || coalesce(emp.last_name, '')), ''),
           occupied_by_email = emp.email,
           occupied_by_employee_role = emp.role,
           assigned_at = v_now,
           released_at = null,
           updated_at = v_now
     where id = v_seat;
  end loop;

  perform public.recompute_company_seats_used(p_company_id);
end;
$$;

-- 5. Seat rows follow the limit -------------------------------------------------
create or replace function public.sync_organization_seats(
  p_organization_id uuid,
  p_seat_limit integer
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  lim integer := greatest(coalesce(p_seat_limit, 0), 0);
  above record;
  v_free uuid;
  v_now timestamptz := timezone('utc', now());
begin
  if p_organization_id is null then
    return;
  end if;

  perform pg_advisory_xact_lock(
    hashtextextended('company_seats:' || p_organization_id::text, 0));

  -- Seats 1..limit exist and are usable.
  insert into public.organization_seats (organization_id, seat_number, status, serial_number)
  select p_organization_id, g, 'available', public.generate_seat_serial(null)
    from generate_series(1, lim) g
  on conflict (organization_id, seat_number) do nothing;

  update public.organization_seats
     set status = 'available', updated_at = v_now
   where organization_id = p_organization_id
     and seat_number <= lim
     and status = 'disabled';

  -- Holders above a reduced limit move down into free seats within it.
  for above in
    select * from public.organization_seats
     where organization_id = p_organization_id
       and seat_number > lim
       and status = 'occupied'
     order by seat_number
  loop
    v_free := null;
    select id into v_free
      from public.organization_seats
     where organization_id = p_organization_id
       and seat_number <= lim
       and status = 'available'
     order by seat_number
     limit 1
     for update;
    exit when v_free is null;

    update public.organization_seats
       set status = 'available', occupied_by_user_id = null, occupied_by_name = null,
           occupied_by_email = null, occupied_by_employee_role = null,
           assigned_at = null, released_at = v_now, updated_at = v_now
     where id = above.id;

    update public.organization_seats
       set status = 'occupied',
           occupied_by_user_id = above.occupied_by_user_id,
           occupied_by_name = above.occupied_by_name,
           occupied_by_email = above.occupied_by_email,
           occupied_by_employee_role = above.occupied_by_employee_role,
           assigned_at = coalesce(above.assigned_at, v_now),
           released_at = null,
           updated_at = v_now
     where id = v_free;
  end loop;

  -- Free seats above the limit are switched off, not deleted (their serials
  -- and history stay).
  update public.organization_seats
     set status = 'disabled', updated_at = v_now
   where organization_id = p_organization_id
     and seat_number > lim
     and status = 'available';

  perform public.sync_company_seat_holders(p_organization_id);
end;
$$;

-- 6. Triggers -------------------------------------------------------------------
create or replace function public.employees_sync_seats()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op in ('UPDATE', 'DELETE') and old.company_id is not null then
    perform public.sync_company_seat_holders(old.company_id);
  end if;
  if tg_op in ('INSERT', 'UPDATE') and new.company_id is not null
     and (tg_op = 'INSERT' or new.company_id is distinct from old.company_id) then
    perform public.sync_company_seat_holders(new.company_id);
  end if;
  return null;
end;
$$;

drop trigger if exists employees_sync_seats on public.employees;
create trigger employees_sync_seats
  after insert or delete
     or update of status, is_dismissed, company_id, role, first_name, last_name, user_id
  on public.employees
  for each row execute function public.employees_sync_seats();

create or replace function public.companies_sync_seats()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform public.sync_organization_seats(new.id, new.seat_limit);
  return null;
end;
$$;

-- Fires only when seat_limit is in the UPDATE's SET list and changed; the
-- recompute above sets seats_used/seats_available only, so it cannot recurse.
drop trigger if exists companies_sync_seats on public.companies;
create trigger companies_sync_seats
  after update of seat_limit on public.companies
  for each row
  when (old.seat_limit is distinct from new.seat_limit)
  execute function public.companies_sync_seats();

-- 7. create_serial_token counts people -----------------------------------------
do $patch$
declare
  v_def text;
  v_anchor constant text :=
    E'  select count(*) into v_current_seats_used\n'
    || E'  from public.organization_seats\n'
    || E'  where organization_id = p_organization_id and status = ''occupied'';';
begin
  select pg_get_functiondef(p.oid) into v_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.proname = 'create_serial_token'
     and pg_get_function_identity_arguments(p.oid)
         = 'p_organization_id uuid, p_valid_days integer, p_seat_limit integer';
  if v_def is null then
    raise exception 'create_serial_token not found';
  end if;
  if position(v_anchor in v_def) = 0 then
    raise exception 'create_serial_token: seat-count anchor not found — body drifted, not patching';
  end if;
  execute replace(v_def, v_anchor,
    '  v_current_seats_used := public.company_seats_in_use(p_organization_id);');
end;
$patch$;

-- 8. Remove from seat = suspend ------------------------------------------------
create or replace function public.super_admin_release_organization_seat(
  p_organization_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  n int;
  cname text;
begin
  perform public.require_platform_admin();

  if p_organization_id is null or p_user_id is null then
    raise exception 'Organization and user are required';
  end if;

  select c.company_name into cname from public.companies c where c.id = p_organization_id;
  if cname is null then
    raise exception 'Organization not found';
  end if;

  -- A seat is held by an active employee, so releasing it suspends them; the
  -- employees trigger frees the seat row and the count.
  update public.employees
     set status = 'suspended'
   where company_id = p_organization_id
     and user_id = p_user_id
     and status = 'active';
  get diagnostics n = row_count;

  perform public.insert_audit_log('SEAT_RELEASED', 'user', p_user_id, null, p_organization_id,
    'Seat released by platform admin; the user is suspended until given a seat again.');

  return jsonb_build_object('organization_id', p_organization_id,
                            'user_id', p_user_id, 'rows_updated', n);
end;
$$;

-- 9. Reassign = move the seat to a member who has none ------------------------
create or replace function public.reassign_seat(
  p_seat_id uuid,
  p_new_user_id uuid,
  p_new_user_email text,
  p_new_user_name text,
  p_new_user_role text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_seat record;
  v_new record;
  v_role text;
  v_count int;
  v_landed record;
  v_now timestamptz := timezone('utc', now());
begin
  select * into v_seat from public.organization_seats where id = p_seat_id;
  if not found then
    return jsonb_build_object('success', false, 'error', 'Seat not found');
  end if;

  if not (public.is_platform_admin()
          or public.is_company_manager(v_seat.organization_id)) then
    return jsonb_build_object('success', false,
      'error', 'Not authorized to reassign this seat');
  end if;

  if v_seat.status = 'disabled' then
    return jsonb_build_object('success', false,
      'error', 'This seat is above the company''s seat limit.');
  end if;

  select * into v_new from public.employees
   where company_id = v_seat.organization_id and user_id = p_new_user_id
   order by created_at desc limit 1;
  if not found then
    return jsonb_build_object('success', false,
      'error', 'That person is not a member of this company.');
  end if;
  if v_new.status = 'active' and coalesce(v_new.is_dismissed, false) = false then
    return jsonb_build_object('success', false,
      'error', 'That person already holds a seat.');
  end if;
  if v_new.status in ('rejected', 'dismissed') or coalesce(v_new.is_dismissed, false) then
    return jsonb_build_object('success', false,
      'error', 'That person was declined or dismissed and cannot be given a seat.');
  end if;

  v_role := coalesce(v_new.role, nullif(trim(p_new_user_role), ''));
  if v_role is null then
    return jsonb_build_object('success', false,
      'error', 'Give this person a role before giving them a seat.');
  end if;

  if v_seat.role_binding is not null and v_seat.role_binding <> v_role then
    return jsonb_build_object('success', false,
      'error', format('This seat is bound to role "%s". Cannot assign a "%s" user.',
                      v_seat.role_binding, v_role));
  end if;

  if not public.is_valid_role_for_org(
       (select org_type from public.companies where id = v_seat.organization_id),
       v_role) then
    return jsonb_build_object('success', false,
      'error', format('Role "%s" is not valid for this organisation.', v_role));
  end if;

  if v_seat.occupied_by_user_id is not null then
    select count(*) into v_count
      from public.seat_reassignment_log
     where organization_id = v_seat.organization_id
       and reassigned_at >= (now() - interval '30 days');
    if v_count >= 2 then
      return jsonb_build_object('success', false,
        'error', 'Seat reassignment limit reached (2 per 30 days). Cannot reassign until the window resets.');
    end if;

    insert into public.seat_reassignment_log (
      organization_id, seat_id, previous_user_id, previous_user_email,
      new_user_id, new_user_email, reassigned_by
    ) values (
      v_seat.organization_id, p_seat_id, v_seat.occupied_by_user_id,
      v_seat.occupied_by_email, p_new_user_id, p_new_user_email, auth.uid()
    );

    -- The previous holder gives the seat up.
    update public.employees
       set status = 'suspended'
     where company_id = v_seat.organization_id
       and user_id = v_seat.occupied_by_user_id
       and status = 'active';
  end if;

  -- The new person takes a seat (the seat-limit trigger still applies).
  update public.employees
     set status = 'active', role = v_role
   where id = v_new.id;

  -- Keep the seat NUMBER that was reassigned: if the new holder was seated
  -- elsewhere and this seat is free, move them onto it.
  select * into v_landed from public.organization_seats
   where organization_id = v_seat.organization_id
     and occupied_by_user_id = p_new_user_id
     and status = 'occupied';
  if found and v_landed.id <> p_seat_id
     and (select status from public.organization_seats where id = p_seat_id) = 'available' then
    update public.organization_seats
       set status = 'available', occupied_by_user_id = null, occupied_by_name = null,
           occupied_by_email = null, occupied_by_employee_role = null,
           assigned_at = null, released_at = v_now, updated_at = v_now
     where id = v_landed.id;
    update public.organization_seats
       set status = 'occupied',
           occupied_by_user_id = v_landed.occupied_by_user_id,
           occupied_by_name = v_landed.occupied_by_name,
           occupied_by_email = v_landed.occupied_by_email,
           occupied_by_employee_role = v_landed.occupied_by_employee_role,
           assigned_at = v_now, released_at = null, updated_at = v_now
     where id = p_seat_id;
  end if;

  return jsonb_build_object('success', true);
end;
$$;

-- Internal helpers: called by SECURITY DEFINER functions and triggers only.
revoke all on function public.company_seats_in_use(uuid) from public, anon, authenticated;
revoke all on function public.recompute_company_seats_used(uuid) from public, anon, authenticated;
revoke all on function public.sync_company_seat_holders(uuid) from public, anon, authenticated;
revoke all on function public.sync_organization_seats(uuid, integer) from public, anon, authenticated;
revoke all on function public.employees_sync_seats() from public, anon, authenticated;
revoke all on function public.companies_sync_seats() from public, anon, authenticated;

-- 10. Backfill ------------------------------------------------------------------
select public.sync_organization_seats(c.id, c.seat_limit) from public.companies c;

commit;
