-- 20260815124000_token_request_renewal_and_attribution.sql
--
-- S2-12, two findings from reading all 152 RLS policies.
--
-- ============================================================================
-- F1 (SEVERE) — an expired company CANNOT RENEW through the path the app uses.
-- ============================================================================
-- The read-only ruling on S2-10 deliberately preserved the renewal request:
-- gating it would lock a lapsed customer out permanently. `20260815094000`
-- verified that by INSERTing into `token_requests` directly, and the INSERT
-- policy does allow it.
--
-- But the app never inserts directly. `super_admin_repository.dart:735` calls
-- `create_company_token_request`, and that RPC opens with
-- `is_company_manager(p_organization_id)` — which since `20260815094000`
-- means manager **AND company active**. So the protection was verified on a
-- path the product does not take, and the path it does take is shut.
--
-- Walked before this change, as the Iron Hills owner with the company flipped
-- to `expired` in a rolled-back transaction:
--   is_company_manager            -> false
--   create_company_token_request  -> REFUSED
--     'Not permitted to create token requests for this organization'
--
-- The fix is `is_company_manager_any_status()`: still a manager or the owner,
-- no longer conditional on the licence they are trying to pay for. Renewal is
-- the one operation that must outlive expiry.
do $$
declare
  v_def text;
  v_new text;
  v_anchor text := 'if not public.is_company_manager(p_organization_id) then';
  v_hits int;
begin
  select pg_get_functiondef(p.oid) into v_def
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'create_company_token_request';

  if v_def is null then
    raise exception 'create_company_token_request not found';
  end if;

  v_hits := (length(v_def) - length(replace(v_def, v_anchor, ''))) / length(v_anchor);
  if v_hits <> 1 then
    raise exception 'expected exactly 1 manager gate, found %', v_hits;
  end if;

  v_new := replace(
    v_def, v_anchor,
    'if not public.is_company_manager_any_status(p_organization_id) then');
  execute v_new;
end
$$;

comment on function public.create_company_token_request(uuid, text, text, integer, integer, integer, uuid) is
  'Raises a seat-expansion / token-renewal / new-token request. Gated on is_company_manager_any_status() rather than is_company_manager() since S2-12 (2026-08-15): renewal is the one operation that must outlive expiry, and the active-gated predicate had shut the only path the app takes. requested_by_user_id is set from auth.uid() here, never from the caller.';

-- ============================================================================
-- F2 — the INSERT policy let any active employee raise a commercial request
--      AND forge who it came from.
-- ============================================================================
-- `token_requests` carried two PERMISSIVE insert policies, and permissive
-- policies OR: the weaker one decided the outcome.
--
--   token_requests_insert_company_manager
--     requested_by_user_id = auth.uid() AND is_company_manager_any_status(org)
--   "Company users can create seat requests"
--     organization_id = get_user_company_id()          <-- no actor test at all
--
-- Walked as a real `security` guard at Iron Hills, is_company_manager_any_status
-- false, in a rolled-back transaction: the INSERT was **ALLOWED**, with
-- `requested_by_user_id` set to a DIFFERENT employee. So a guard could raise a
-- seat expansion on the company's behalf and put a colleague's name on it —
-- the platform admin's inbox would show a request from somebody who never made
-- one. Audit integrity on the commercial path S4 has just finished hardening.
--
-- Not a break to the product: nothing in `lib/` inserts into this table. The
-- app goes through the RPC above, which sets `auth.uid()` itself.
--
-- The replacement keeps the wider *company* reach the weak policy had — an
-- expired company's owner has no `employees` row, so `get_user_company_id()`
-- returns NULL for exactly the account that needs to renew, which is why the
-- manager policy alone was not enough — while making attribution unforgeable.
-- `is_company_staff`, not `is_company_staff_active`: renewal must survive
-- expiry, same reason as F1.
drop policy if exists "Company users can create seat requests" on public.token_requests;

create policy token_requests_insert_own_attribution
  on public.token_requests
  for insert
  to authenticated
  with check (
    requested_by_user_id = (select auth.uid())
    and public.is_company_staff(organization_id)
  );

comment on policy token_requests_insert_own_attribution on public.token_requests is
  'Direct-insert path. Any active staff member of the organisation may raise a request, but only in their own name (S2-12, 2026-08-15) - the policy this replaced had no actor test, so a non-manager could file one under a colleague''s id. Deliberately is_company_staff and not _active: renewal must outlive expiry.';
