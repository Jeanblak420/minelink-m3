-- P3-43 — narrow the `companies` SELECT policy (client ruling 2, 2026-08-11;
-- standing order wave 1.5, 2026-08-12). Applies docs/rls-companies-tightening.md.
--
-- Before this, the ONLY select policy on companies was:
--     companies_select_authenticated  FOR SELECT  USING (true)
--
-- Every authenticated user — a driver, a security guard, anyone — could read
-- every company row on the platform: seat_limit, seats_used, token_expires_at,
-- current_token_id, whatsapp_number, registration_number, vat_number,
-- physical_address, CEO names, support email. A driver at one transporter could
-- enumerate every competitor's full profile and commercial posture. On a
-- multi-tenant B2B platform that is the leak that matters most.
--
-- ============================================================================
-- THE PREREQUISITES — and the one the prepared document missed
-- ============================================================================
--
-- The document is explicit that a per-tenant predicate cannot satisfy the
-- pickers, and that applying the policy without fixing them first WILL BREAK
-- ONBOARDING. It names two. There are three.
--
--  §2a ✅ The onboarding employer picker — company_service.dart
--         `from('companies').select()` (all rows, ALL columns), reached from
--         company_selection_screen and request_declined_screen. A pre-approval
--         employee legitimately needs to see companies they have no
--         relationship with; they do not need seat, token or VAT data.
--
--  §2b ✅ The operations-hub fetch — operations_service.dart, on EVERY refresh.
--         ⚠ The document guessed this was "dead weight on the refresh path".
--         IT IS NOT. `state.companies` feeds the three counterparty dropdowns
--         in the Operations Hub transaction editor. It could not be deleted,
--         and it could not be narrowed to counterparties either — choosing a
--         counterparty you have NOT yet transacted with is what a picker is for.
--
--  §2d 🔴 NOT IN THE DOCUMENT — EmployeeNotifier.validateCompanyId().
--         `linkToCompany()` calls it before writing the link, and it did
--         `getCompanyById()` — a direct companies read for a company the
--         employee is not yet part of. Under this policy that returns zero rows
--         and reports "Company not found" for EVERY company on the platform.
--         That is precisely the broken onboarding the document warns about,
--         arriving through a call site it does not list. Now validated against
--         the directory RPC instead.
--
--         The read AFTER linking is fine and was left alone: current_company_id()
--         resolves off employees.company_id and does not consult role or status,
--         so a just-linked employee with no role yet still reads their own
--         company. Checked rather than assumed.
--
-- All three are fixed in this same commit. The document's proposed
-- `list_selectable_employers()` is generalised to `list_company_directory()`
-- because §2a and §2b need the identical thing — id, name, org type, logo — and
-- two near-identical definer functions would drift apart.
--
-- ⚠ Company.fromJson could not simply be fed fewer columns: it REQUIRES
-- whatsappNumber and userId (non-nullable). A contact number is not optional in
-- that model, so any query feeding it must return one. Hence the new
-- CompanyDirectoryEntry type in Dart — the columns a picker may see are a
-- smaller set than the columns a company profile is made of.

-- ---------------------------------------------------------------- directory
-- Deliberately platform-wide, and that is not a hole: someone not yet approved
-- by any employer must still be able to find their employer in a list. What
-- they can no longer see is anything commercial about it.
create or replace function public.list_company_directory()
returns table (id uuid, company_name text, org_type text, logo_url text)
language sql
stable
security definer
set search_path = public
as $function$
  select c.id, c.company_name, c.org_type, c.logo_url
  from public.companies c
  where c.status is distinct from 'suspended'
  order by c.company_name;
$function$;

comment on function public.list_company_directory() is
  'Name, org type and logo of every non-suspended company -- the four fields a '
  'picker renders, and nothing else. Exists because the onboarding employer '
  'picker and the operations counterparty dropdowns need a WIDER row set than '
  'companies_select_scoped allows and a far NARROWER column set than the table '
  'holds (P3-43). Never add a commercial column here: seat counts, token '
  'expiry, VAT/registration numbers, addresses and contact numbers are exactly '
  'what the scoped policy exists to stop leaking.';

revoke execute on function public.list_company_directory() from public;
grant  execute on function public.list_company_directory() to authenticated;

-- ---------------------------------------------------------------- counterparty
-- Who counts as a counterparty: anyone this company has actually transacted
-- with, been dispatched alongside, or been explicitly chat-connected to by the
-- platform admin. SECURITY DEFINER so it does not re-enter the companies policy.
create or replace function public.is_company_counterparty(p_target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $function$
  with me as (select public.current_company_id() as id)
  select exists (
    -- a shared transaction in any role combination
    select 1 from public.transactions t, me
    where me.id in (t.supplier_company_id, t.buyer_company_id, t.transporter_company_id)
      and p_target in (t.supplier_company_id, t.buyer_company_id, t.transporter_company_id)
  ) or exists (
    -- a dispatch links a transporter to the requester/supplier BEFORE any
    -- transaction exists (transactions are only created on accept), so without
    -- this a transporter cannot see who dispatched them a route.
    select 1 from public.request_dispatches d
    join public.transportation_requests r on r.id = d.request_id, me
    where (d.transporter_company_id = me.id
             and p_target in (r.buyer_company_id, r.supplier_company_id))
       or (me.id in (r.buyer_company_id, r.supplier_company_id)
             and p_target = d.transporter_company_id)
  ) or exists (
    -- an active platform-granted chat connection
    select 1 from public.org_connections oc, me
    where oc.status = 'granted'
      and ((oc.company_low_id = me.id  and oc.company_high_id = p_target)
        or (oc.company_high_id = me.id and oc.company_low_id  = p_target))
  );
$function$;

comment on function public.is_company_counterparty(uuid) is
  'True when the caller''s company and p_target share a transaction, a request '
  'dispatch, or a granted org_connection. Backs companies_select_scoped '
  '(P3-43). The dispatch clause is load-bearing: transactions are only created '
  'on accept, so without it a transporter cannot read the name of the company '
  'that just dispatched them a route.';

revoke execute on function public.is_company_counterparty(uuid) from public;
grant  execute on function public.is_company_counterparty(uuid) to authenticated;

-- ---------------------------------------------------------------- the policy
drop policy if exists companies_select_authenticated on public.companies;

create policy companies_select_scoped
  on public.companies
  for select
  to authenticated
  using (
    -- Each helper is wrapped in a scalar subquery so Postgres evaluates it ONCE
    -- per statement instead of once per row (the same initplan issue as
    -- auth.uid(), and the reason P3-63 exists).
    (select public.is_platform_admin())
    or user_id = (select auth.uid())
    or id = (select public.current_company_id())
    or public.is_company_counterparty(id)
  );

comment on policy companies_select_scoped on public.companies is
  'P3-43. Replaced companies_select_authenticated USING (true), which let any '
  'authenticated user read every company row incl. seat limits, token expiry, '
  'VAT/registration numbers, addresses and contact details. Pickers that must '
  'span the whole platform go through list_company_directory() instead, which '
  'returns four non-commercial columns.';

-- No write-path impact: there are no reachable direct writes to companies --
-- every legitimate mutation already goes through an RPC
-- (update_my_company_profile, the super-admin token/org functions). The one
-- direct write, company_repository.updateLogo, has no callers.
