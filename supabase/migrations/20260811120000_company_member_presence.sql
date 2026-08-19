-- ============================================================================
-- Employee Register — company-scoped member presence (P7-30, P7-33, P7-35)
-- ----------------------------------------------------------------------------
-- Prerequisite for promoting the super-admin Employee Register to a screen
-- every company can open for itself.
--
-- THE FINDING. The register renders live presence per person from
-- `profiles.last_seen_at`. The only SELECT policy on `profiles` is
--
--     profiles_select_own   USING (id = auth.uid() OR is_super_admin())
--
-- so a company owner, admin or manager can read exactly one profile row: their
-- own. The screen's read is wrapped in `catch (_) {}`, so it does not fail --
-- it returns nothing, and every colleague renders **offline**. A presence
-- indicator that says "offline" because it was not allowed to look is a
-- fabricated status presented as a real one, which is the one thing the
-- release gate rules out outright. It has been invisible until now only
-- because the screen is super-admin-only, and a super admin passes the policy.
--
-- WHY AN RPC AND NOT A WIDER POLICY. RLS is row-level, not column-level: a
-- policy letting a manager read a colleague's profile row hands over every
-- column on it, and `profiles` carries `platform_role`, `must_change_password`,
-- `metadata`, `email` and `signature_url`. The register needs two facts. So it
-- gets a function that returns two facts, and `profiles` stays shut. Same
-- reasoning as `list_selectable_employers()` in docs/rls-companies-tightening.md.
--
-- WHAT ELSE THE AUDIT CLEARED. Every other table the register reads is already
-- correctly scoped for a company user and needed no change:
--
--   employees               is_company_manager(company_id)  -- owner/admin/mgmt
--   driver_assignments      is_company_staff(company_id)
--   fleet_vehicles          is_company_staff(company_id)
--   compliance_documents    is_company_staff(company_id)
--   trips                   via transactions, all three parties
--   stockpile_transactions  via stockpiles, all three parties
--   stockpiles, routes, pod_uploads, request_dispatches, recon_disputes
--                           all party-scoped
--
-- One caveat carried forward, not introduced here: `transportation_requests`
-- is `is_company_staff(buyer_company_id)`, which is the semantics problem
-- P3-46 describes -- a mine only sees its own requests because it writes
-- itself into `buyer_company_id`. The register's request-count KPI inherits
-- that and will follow its fix.
-- ============================================================================

create or replace function public.list_company_member_presence(
  p_company_id uuid
)
returns table (
  user_id uuid,
  last_seen_at timestamptz,
  has_signature boolean
)
language sql
stable
security definer
set search_path = public
as $$
  select
    p.id,
    p.last_seen_at,
    -- The URL itself is never returned: the register only needs to show WHO
    -- is missing a signature (P7-35). A user without one silently produces a
    -- blank waybill signature line, and today only 3 of 116 profiles have one.
    (p.signature_url is not null and p.signature_url <> '') as has_signature
  from public.employees e
  join public.profiles p on p.id = e.user_id
  where e.company_id = p_company_id
    -- P7-33 enforced in the database, not in the sidebar. `is_company_manager`
    -- is exactly owner + active, non-dismissed admin/management -- the three
    -- audiences the register is for.
    and (
      public.is_company_manager(p_company_id)
      or public.is_platform_admin()
    );
$$;

comment on function public.list_company_member_presence(uuid) is
  'Employee Register presence, company-scoped. Returns last_seen_at and a '
  'has_signature flag for one company''s employees, to a company owner/admin/'
  'management user or the platform admin. Exists because profiles_select_own '
  'restricts profiles to the caller''s own row, so a manager reading the table '
  'directly gets nothing and every colleague renders offline -- a fabricated '
  'status. Deliberately returns two facts rather than widening the profiles '
  'policy, which would expose platform_role, must_change_password, metadata, '
  'email and signature_url along with them.';

-- Match the grant pattern the other 178 definer functions use: never PUBLIC
-- (anon inherits from PUBLIC, which is how 27 functions were callable
-- unauthenticated before migration 20260810161500), and never anon.
revoke execute on function public.list_company_member_presence(uuid) from public;
grant  execute on function public.list_company_member_presence(uuid) to authenticated;
