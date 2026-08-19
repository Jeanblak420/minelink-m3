-- 20260815115000_seat_role_vocabulary_supervisor.sql
--
-- `organization_seats` could not record a `supervisorForeman`, so that role
-- could never hold a seat — while `employees_role_check` allows it,
-- `UserRole.getRolesForOrgType` gives it to mineSupplier, and
-- `is_valid_role_for_org('mineSupplier','supervisorForeman')` returns true.
-- Three places say the role exists; the seat vocabulary was the one that did
-- not, and the seat is the unit the product sells.
--
-- The seventh CHECK-constraint-as-vocabulary mismatch found on this project,
-- after notifications_type_check, gate_checks_check_type_check, the two on
-- audit_logs, and weighbridge_records_direction_check. Same shape every time:
-- a constraint enumerates a vocabulary, some other part of the system uses a
-- word the constraint never heard of, and nothing reconciles the two.
--
-- It had not bitten yet only because ZERO supervisorForeman employees exist
-- anywhere on the project — which is itself the finding. `is_company_stockpile_writer`
-- has an explicit `role = 'supervisorForeman'` branch that has therefore never
-- been true for anybody: every stockpile write in the system's history went
-- through its `is_company_manager` branch instead. The role that CLAUDE.md §4
-- puts in charge of filling the order stockpile has never once done it.
--
-- Both seat role columns are widened. Nothing is removed.

alter table public.organization_seats
  drop constraint if exists organization_seats_occupied_by_employee_role_check;

alter table public.organization_seats
  add constraint organization_seats_occupied_by_employee_role_check
  check (occupied_by_employee_role is null or occupied_by_employee_role = any (array[
    'management'::text,
    'admin'::text,
    'controllerWB'::text,
    'supervisorForeman'::text,
    'security'::text,
    'driver'::text
  ]));

alter table public.organization_seats
  drop constraint if exists organization_seats_role_binding_check;

alter table public.organization_seats
  add constraint organization_seats_role_binding_check
  check (role_binding is null or role_binding = any (array[
    'management'::text,
    'admin'::text,
    'controllerWB'::text,
    'supervisorForeman'::text,
    'security'::text,
    'driver'::text
  ]));

comment on constraint organization_seats_occupied_by_employee_role_check
  on public.organization_seats is
  'Must cover every role employees_role_check allows and is_valid_role_for_org '
  'admits for the org type. supervisorForeman was missing, so a mine supervisor '
  'could never hold a seat. See 20260815115000.';
