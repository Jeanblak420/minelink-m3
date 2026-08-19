-- Follow-up to 20260815092000, which did not work and whose failure is the
-- point of this file.
--
-- That migration ran `revoke execute ... from anon, authenticated` and
-- succeeded, but re-reading has_function_privilege() afterwards still returned
-- TRUE for both roles. Postgres grants EXECUTE on functions to **PUBLIC** by
-- default, and revoking from a specific role does not remove a privilege held
-- via PUBLIC. Had the result not been re-read, this would have been recorded
-- as closed while the advisor stayed red.
--
-- Revoking from PUBLIC is what actually removes it. Safe for the same reason
-- verified before: trigger functions are invoked by the executor, not through
-- the calling user's EXECUTE privilege.
revoke execute on function public.enforce_employee_role_org_type() from public;
revoke execute on function public.enforce_seat_role_org_type() from public;

-- Verified after applying:
--   has_function_privilege('anon',          …enforce_employee_role_org_type()) = false
--   has_function_privilege('anon',          …enforce_seat_role_org_type())     = false
--   has_function_privilege('authenticated', …enforce_employee_role_org_type()) = false
-- and, in a rolled-back transaction, inserting a `security` employee into a
-- buyer company still raised
--   "Role security is not permitted for a buyer company"
-- so enforcement is intact.
