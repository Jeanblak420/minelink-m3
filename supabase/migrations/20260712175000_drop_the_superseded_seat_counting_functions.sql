-- Drop the seat-counting functions production dropped and the files did not.
--
-- Written 2026-08-18 from the schema diff between a database rebuilt from git
-- and production. Four functions exist in a rebuild and NOT in production:
--
--     enforce_company_seat_limit
--     sync_company_seats_used
--     recompute_company_seats_used
--     sync_organization_seats
--
-- All four come from `20260510190000_super_admin_rpcs_and_seat_enforcement.sql`
-- and were superseded — `employees_seat_limit` on production runs
-- `enforce_employee_seat_limit`, and the seat_requests era gave way to
-- token_requests. Production dropped them out of band, so no file records it.
--
-- 🚨 THIS IS NOT COSMETIC. The functions carry TRIGGERS with them:
--
--     enforce_company_seat_limit_on_employees   -> enforce_company_seat_limit()
--     sync_company_seats_used_after_employees   -> sync_company_seats_used()
--
-- both on `public.employees`, and production has neither. A database rebuilt
-- from git would therefore run two extra triggers on every employee insert,
-- update and delete that the live system does not — a behavioural difference,
-- not a difference in a catalogue listing. `cascade` is what removes them, and
-- it is safe precisely because production has nothing depending on these.
--
-- Stamped after `20260712170000_drop_child_admin_completely`, the last file
-- that still references any of them.

begin;

drop function if exists public.enforce_company_seat_limit() cascade;
drop function if exists public.sync_company_seats_used() cascade;
-- SIGNATURES MATTER. `drop function if exists` resolves by name AND argument
-- types: get them wrong and it matches nothing, drops nothing, and reports
-- success. The first version of this file said
-- `sync_organization_seats()` — the function takes (uuid, integer) — so the
-- migration applied, the replay went green, and the function was still there.
-- Only fingerprinting the rebuilt schema against production caught it, and
-- tool/drop_signature_check.py exists so the next one is caught in the repo.
drop function if exists public.sync_organization_seats(uuid, integer) cascade;
drop function if exists public.recompute_company_seats_used(uuid) cascade;

commit;
