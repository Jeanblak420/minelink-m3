-- Bring the RLS policies the FILES build into line with the ones production
-- ENFORCES.
--
-- The 2026-08-18 cold replay showed the two disagreeing on 8 tables, in both
-- directions, because 70 migration files in this repo have no ledger row and a
-- replay runs them all. Jean's call, 2026-08-18: adopt production, retire the
-- rest. Production is the system that works and the more restrictive side on
-- every write policy, so it is the reference.
--
-- 🚨 THE REASON THIS MATTERED. Restoring from git BEFORE this file existed
-- produced a platform that **could not issue or revoke a serial token** —
-- `serial_tokens` had no INSERT and no UPDATE policy, and token issuance is how
-- companies get access at all. A restore would not have been a degraded system;
-- it would have been one that could not onboard anyone.
--
-- WHAT CHANGES, and why each one:
--
-- ADOPTED — production grants these and no file created them:
--   organization_seats  "Company users can read own org seats"   SELECT
--   organization_seats  "Super admins can manage seats"          ALL
--   serial_tokens       "Super admins can create serial tokens"  INSERT
--   serial_tokens       "Super admins can update serial tokens"  UPDATE
--   token_requests      "Company users can read own seat requests" SELECT
--   token_requests      "Super admins can update seat requests"  UPDATE
--   audit_logs          "Super admins can read audit logs"       SELECT
--
-- RETIRED — the files grant these and production does not. Every one is a
-- widening of access that has never been live:
--   companies   companies_update_company_manager_or_platform_admin  UPDATE
--   employees   employees_update_company_manager_or_platform_admin  UPDATE
--     Production has NO update policy on either table: every write goes through
--     a SECURITY DEFINER RPC, which is where the business rules live. These two
--     would let a company manager write the row directly, around all of them.
--   profiles    profiles_select_platform_admin, profiles_select_self
--     Both redundant: `profiles_select_own` is already
--     `id = auth.uid() OR is_super_admin()`, which covers each of them exactly.
--     Retiring these removes no access at all.
--   audit_logs  audit_logs_insert_platform_admin
--     A second insert path into the audit trail. One is enough, and production
--     has one.
--
-- RENAMED to production's names — same access, different identifier, and
-- keeping both spellings would leave the two databases permanently unequal for
-- no reason:
--   audit_logs_select_allowed                     -> "Super admins can read audit logs"
--   organization_seats_select_platform_admin      -> "Super admins can manage seats" (ALL, which subsumes it)
--   serial_tokens_select_platform_admin           -> "Super admins can read all serial tokens"
--   platform_admin_settings_select_platform_admin -> "Super admins can read admin settings"
--   platform_admin_settings_update_main_only      -> "Main super admin can update settings"
--
--   Note `is_platform_admin()` is literally `select public.is_super_admin()`,
--   so those two predicates are the same test under two names.
--
--   ⚠️ One of these is NOT a pure rename and is worth stating plainly:
--   `platform_admin_settings_update_main_only` carries `with check
--   (is_main_super_admin())` and production's equivalent does not. Dropping the
--   WITH CHECK is a small LOOSENING — it stops re-checking the predicate against
--   the row's new values. It is adopted anyway because production is the
--   reference and this file's whole purpose is to stop the two drifting; it is
--   flagged here so that if anyone decides the stricter form is wanted, they add
--   it to BOTH sides deliberately rather than rediscovering it as a diff.
--
-- NOT APPLIED TO PRODUCTION, on purpose. Production already holds exactly this
-- state, so running it there would drop and recreate live security policies to
-- reach the place it already is. The ledger row is recorded the way `supabase
-- migration repair --status applied` does, and the proof is the replay: after
-- this file, the rebuilt `policies` fingerprint must equal production's.

begin;

-- ---------------------------------------------------------------- audit_logs
drop policy if exists audit_logs_insert_platform_admin on public.audit_logs;
drop policy if exists audit_logs_select_allowed on public.audit_logs;
drop policy if exists "Super admins can read audit logs" on public.audit_logs;
create policy "Super admins can read audit logs" on public.audit_logs
  for select to authenticated using (is_super_admin());

-- ----------------------------------------------------------------- companies
drop policy if exists companies_update_company_manager_or_platform_admin
  on public.companies;

-- ----------------------------------------------------------------- employees
drop policy if exists employees_update_company_manager_or_platform_admin
  on public.employees;

-- -------------------------------------------------------- organization_seats
drop policy if exists organization_seats_select_platform_admin
  on public.organization_seats;
drop policy if exists "Company users can read own org seats"
  on public.organization_seats;
create policy "Company users can read own org seats" on public.organization_seats
  for select to authenticated
  using (organization_id = get_user_company_id());
drop policy if exists "Super admins can manage seats" on public.organization_seats;
create policy "Super admins can manage seats" on public.organization_seats
  for all to authenticated using (is_super_admin());

-- --------------------------------------------------- platform_admin_settings
drop policy if exists platform_admin_settings_select_platform_admin
  on public.platform_admin_settings;
drop policy if exists platform_admin_settings_update_main_only
  on public.platform_admin_settings;
drop policy if exists "Super admins can read admin settings"
  on public.platform_admin_settings;
create policy "Super admins can read admin settings"
  on public.platform_admin_settings
  for select to authenticated using (is_super_admin());
drop policy if exists "Main super admin can update settings"
  on public.platform_admin_settings;
create policy "Main super admin can update settings"
  on public.platform_admin_settings
  for update to authenticated using (is_main_super_admin());

-- ------------------------------------------------------------------ profiles
drop policy if exists profiles_select_platform_admin on public.profiles;
drop policy if exists profiles_select_self on public.profiles;

-- ------------------------------------------------------------- serial_tokens
drop policy if exists serial_tokens_select_platform_admin on public.serial_tokens;
drop policy if exists "Super admins can read all serial tokens" on public.serial_tokens;
create policy "Super admins can read all serial tokens" on public.serial_tokens
  for select to authenticated using (is_super_admin());
drop policy if exists "Super admins can create serial tokens" on public.serial_tokens;
create policy "Super admins can create serial tokens" on public.serial_tokens
  for insert to authenticated with check (is_super_admin());
drop policy if exists "Super admins can update serial tokens" on public.serial_tokens;
create policy "Super admins can update serial tokens" on public.serial_tokens
  for update to authenticated using (is_super_admin());

-- ------------------------------------------------------------ token_requests
drop policy if exists "Company users can read own seat requests"
  on public.token_requests;
create policy "Company users can read own seat requests" on public.token_requests
  for select to authenticated
  using (organization_id = get_user_company_id());
drop policy if exists "Super admins can update seat requests"
  on public.token_requests;
create policy "Super admins can update seat requests" on public.token_requests
  for update to authenticated using (is_super_admin());

commit;
