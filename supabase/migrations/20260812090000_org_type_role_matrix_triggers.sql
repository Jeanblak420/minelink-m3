-- P3-51 — roles constrained by org type (client ruling 1, 2026-08-11).
--
--   buyer        -> admin, management                      (and nothing else)
--   mineSupplier -> admin, management, supervisorForeman, security, controllerWB
--   transporter  -> admin, management, driver
--
-- ⚠ CORRECTION TO THE PLAN, recorded here because the next reader will otherwise
-- rebuild what already works. P3-51 states that "assign_employee_role does not
-- check org type either". It does. It has always called
-- is_valid_role_for_org(org_type, role) and raised on failure, and
-- is_valid_role_for_org already implements the client's ruled matrix exactly —
-- character for character, including supervisorForeman being mine-only. The Dart
-- picker (UserRole.getRolesForOrgType) implements the same matrix. So the RPC
-- path and the UI were already to spec before this migration.
--
-- What was genuinely missing, found by asking which functions write a role and
-- which of those validate:
--
--   * super_admin_set_employee_role  — writes employees.role, NO org-type check.
--     The platform admin could set any role on any employee at any org type.
--     This was the real hole.
--   * reassign_seat, super_admin_release_organization_seat, request_company_link,
--     decline_employee_request, remove_company_employee — all touch a role or a
--     seat role column without consulting the matrix.
--   * Any direct INSERT/UPDATE on either table. employees_role_check permits all
--     six roles at any org type and organization_seats' two role checks permit
--     all five, because a CHECK constraint cannot reach companies.org_type from
--     these tables.
--
-- Rather than edit six functions and still leave direct writes open, the rule is
-- enforced once per table in a trigger. A trigger sees every writer — including
-- ones not yet written — which is the property the CHECK constraints cannot have.
-- The existing CHECKs stay: they bound the vocabulary, the triggers bound the
-- combination.
--
-- Verified against live production immediately before applying — the triggers
-- cannot fail on an existing row:
--   employees with a company AND a role : 42, violations 0
--     buyer      admin 3, management 3
--     mine       security 7, admin 6, management 4, controllerWB 4
--     transporter driver 6, admin 5, management 4   (no supervisorForeman anywhere)
--   organization_seats with occupied_by_employee_role : 18, violations 0
--   organization_seats with role_binding              :  0 (P9-09 — never populated)

-- ---------------------------------------------------------------- employees

create or replace function public.enforce_employee_role_org_type()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  org text;
begin
  -- Nothing to check until the employee is both linked and roled. A pending
  -- request (company set, role null) and a removed employee (both null, which is
  -- what remove_company_employee leaves behind) must both still be writable.
  if new.role is null or new.company_id is null then
    return new;
  end if;

  -- Only re-validate when the pair actually changes, so unrelated updates to an
  -- existing row are never blocked by a rule introduced after it was written.
  if tg_op = 'UPDATE'
     and new.role is not distinct from old.role
     and new.company_id is not distinct from old.company_id then
    return new;
  end if;

  select c.org_type into org from public.companies c where c.id = new.company_id;
  if org is null then
    raise exception 'Company % not found for employee %', new.company_id, new.id
      using errcode = '23503';
  end if;

  if not public.is_valid_role_for_org(org, new.role) then
    raise exception 'Role % is not permitted for a % company', new.role, org
      using errcode = '23514',
            hint = 'buyer: admin, management. mineSupplier: admin, management, '
                   'supervisorForeman, security, controllerWB. '
                   'transporter: admin, management, driver.';
  end if;

  return new;
end;
$$;

comment on function public.enforce_employee_role_org_type() is
  'P3-51: rejects any employees row whose role is not permitted for its company''s '
  'org_type. Enforced in a trigger rather than a CHECK because a CHECK cannot read '
  'companies.org_type, and in a trigger rather than per-RPC because '
  'super_admin_set_employee_role and five other writers did not consult the matrix.';

drop trigger if exists employees_role_org_type_check on public.employees;
create trigger employees_role_org_type_check
  before insert or update on public.employees
  for each row execute function public.enforce_employee_role_org_type();

-- -------------------------------------------------------- organization_seats

create or replace function public.enforce_seat_role_org_type()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  org text;
begin
  if new.organization_id is null
     or (new.role_binding is null and new.occupied_by_employee_role is null) then
    return new;
  end if;

  if tg_op = 'UPDATE'
     and new.role_binding is not distinct from old.role_binding
     and new.occupied_by_employee_role is not distinct from old.occupied_by_employee_role
     and new.organization_id is not distinct from old.organization_id then
    return new;
  end if;

  select c.org_type into org from public.companies c where c.id = new.organization_id;
  if org is null then
    return new;  -- FK owns this; do not invent a second failure mode.
  end if;

  if new.role_binding is not null
     and not public.is_valid_role_for_org(org, new.role_binding) then
    raise exception 'Seat role_binding % is not permitted for a % company',
      new.role_binding, org using errcode = '23514';
  end if;

  if new.occupied_by_employee_role is not null
     and not public.is_valid_role_for_org(org, new.occupied_by_employee_role) then
    raise exception 'Seat occupant role % is not permitted for a % company',
      new.occupied_by_employee_role, org using errcode = '23514';
  end if;

  return new;
end;
$$;

comment on function public.enforce_seat_role_org_type() is
  'P3-51: same matrix as enforce_employee_role_org_type, applied to '
  'organization_seats.role_binding and .occupied_by_employee_role.';

drop trigger if exists organization_seats_role_org_type_check on public.organization_seats;
create trigger organization_seats_role_org_type_check
  before insert or update on public.organization_seats
  for each row execute function public.enforce_seat_role_org_type();

-- Record the matrix where somebody reading the schema will meet it.
comment on column public.employees.role is
  'One of security, controllerWB, supervisorForeman, admin, management, driver — '
  'but constrained BY ORG TYPE (client ruling, 2026-08-11), which the column''s '
  'CHECK cannot express: buyer gets admin/management only; supervisorForeman, '
  'security and controllerWB are mine-only; driver is transporter-only. Enforced '
  'by trigger employees_role_org_type_check via is_valid_role_for_org().';
