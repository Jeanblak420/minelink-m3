-- S2-10 / G4. Client ruling 2026-08-15: **an expired company is read-only.**
--
-- The defect this closes, proven on production as the owner of SteelWorks SA
-- (token expired 2026-04-23): is_company_staff() short-circuits on
-- is_company_owner(...) OR …, and is_company_owner() tests only
-- `c.user_id = auth.uid()` — it never looks at company status. So an expired
-- company's OWNER kept full read AND write access indefinitely, while its
-- employees were correctly blocked (expire_organizations sets them inactive
-- and is_company_staff requires status='active').
--
-- Shape, per the recorded suggestion: is_company_owner() is left alone — it
-- answers "is this person the owner", which stays true after expiry. A new
-- is_company_active() carries the status question, and only the WRITE side
-- consults it.
--
-- THE RENEWAL PATH IS DELIBERATELY EXEMPT. token_requests is how a company
-- asks for a new token. Gating it would mean an expired company could never
-- renew — locking the customer out permanently, which is the opposite of the
-- commercial intent. Note this is not covered by the sibling policy
-- "Company users can create seat requests": that one keys off
-- get_user_company_id(), which reads only `employees`, and a company OWNER has
-- no employees row — so it returns NULL for exactly the account that needs to
-- renew.
--
-- Reads are untouched: 38 SELECT policies keyed on is_company_staff and the 3
-- keyed on is_company_manager all still resolve for an expired owner.
--
-- SCOPE NOTE, broader than the literal ruling and flagged rather than hidden:
-- is_company_active() tests `status = 'active'`, so it also excludes
-- `pendingActivation` (8 companies) and `suspended`. That is the correct
-- reading of "active", and it is safe here — those 8 were created 2026-03-29/30
-- and have **0 transactions** between them, and company/employee signup runs
-- through SECURITY DEFINER RPCs which bypass RLS entirely. Worth the client
-- confirming that a not-yet-activated company should also be read-only.

-- 1. The status question, on its own.
create or replace function public.is_company_active(target_company_id uuid)
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select exists (
    select 1 from public.companies c
    where c.id = target_company_id and c.status = 'active'
  );
$function$;

comment on function public.is_company_active(uuid) is
  'True when the company is active (not expired/suspended/pendingActivation). '
  'Consulted by WRITE policies only — an expired company is read-only by '
  'client ruling 2026-08-15. Deliberately separate from is_company_owner(), '
  'which answers "is this the owner" and stays true after expiry.';

-- 2. The old is_company_manager body, preserved under a new name for the
--    read policies and the renewal path.
create or replace function public.is_company_manager_any_status(target_company_id uuid)
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select public.is_company_owner(target_company_id)
    or exists (
      select 1
      from public.employees e
      where e.company_id = target_company_id
        and e.user_id = auth.uid()
        and e.role in ('admin', 'management')
        and e.status = 'active'
        and e.is_dismissed = false
    );
$function$;

comment on function public.is_company_manager_any_status(uuid) is
  'is_company_manager() without the active-company test. For SELECT policies '
  '(an expired company is read-only, not blind) and for the token_requests '
  'renewal path, which must keep working after expiry.';

-- 3. is_company_manager() gains the active test. 34 write policies consume it,
--    plus can_manage_fleet() and is_company_stockpile_writer(), which delegate
--    to it and are therefore gated too without being edited.
create or replace function public.is_company_manager(target_company_id uuid)
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select public.is_company_manager_any_status(target_company_id)
     and public.is_company_active(target_company_id);
$function$;

-- 4. The staff equivalent, for the 9 write policies keyed on is_company_staff.
create or replace function public.is_company_staff_active(target_company_id uuid)
returns boolean
language sql
stable security definer
set search_path to 'public'
as $function$
  select public.is_company_staff(target_company_id)
     and public.is_company_active(target_company_id);
$function$;

-- 5. Preserve reads that ran through is_company_manager.
drop policy if exists employees_select_self_or_company_managers on public.employees;
create policy employees_select_self_or_company_managers
  on public.employees for select to authenticated
  using ((user_id = (select auth.uid()))
      or public.is_company_manager_any_status(company_id)
      or public.is_super_admin());

drop policy if exists employee_status_history_select_self_or_company_managers
  on public.employee_status_history;
create policy employee_status_history_select_self_or_company_managers
  on public.employee_status_history for select to authenticated
  using (public.is_employee_self(employee_id)
      or public.is_company_manager_any_status(company_id));

drop policy if exists token_requests_select_allowed on public.token_requests;
create policy token_requests_select_allowed
  on public.token_requests for select to authenticated
  using (public.is_platform_admin()
      or public.is_company_manager_any_status(organization_id));

-- 6. Preserve the renewal write.
drop policy if exists token_requests_insert_company_manager on public.token_requests;
create policy token_requests_insert_company_manager
  on public.token_requests for insert to authenticated
  with check ((requested_by_user_id = (select auth.uid()))
          and public.is_company_manager_any_status(organization_id));

-- 7. Gate the 9 staff-keyed writes. WITH CHECK only — the USING clause on an
--    UPDATE selects which rows may be targeted, and narrowing that would hide
--    rows rather than refuse writes. Refusing the write is the ruling.
--    `mineral_loads_company_staff` is deliberately NOT here: it is a cmd=ALL
--    policy whose USING clause serves SELECT, so touching it would remove read
--    access. Its WITH CHECK already runs through is_company_manager and is
--    gated by step 3.
drop policy if exists load_invoices_insert on public.load_invoices;
create policy load_invoices_insert on public.load_invoices for insert to authenticated
  with check (public.is_company_staff_active(buyer_company_id) and exists (
    select 1 from public.trips t join public.transactions txn on txn.id = t.transaction_id
    where t.id = load_invoices.trip_id and txn.buyer_company_id = load_invoices.buyer_company_id));

drop policy if exists load_invoices_update on public.load_invoices;
create policy load_invoices_update on public.load_invoices for update to authenticated
  using (public.is_company_staff(buyer_company_id))
  with check (public.is_company_staff_active(buyer_company_id) and exists (
    select 1 from public.trips t join public.transactions txn on txn.id = t.transaction_id
    where t.id = load_invoices.trip_id and txn.buyer_company_id = load_invoices.buyer_company_id));

drop policy if exists pod_uploads_insert on public.pod_uploads;
create policy pod_uploads_insert on public.pod_uploads for insert to authenticated
  with check (exists (select 1 from public.transactions t
    where t.id = pod_uploads.transaction_id
      and public.is_company_staff_active(t.transporter_company_id)));

drop policy if exists request_dispatches_update on public.request_dispatches;
create policy request_dispatches_update on public.request_dispatches for update to authenticated
  using (public.is_platform_admin() or public.is_company_staff(transporter_company_id))
  with check (public.is_platform_admin() or public.is_company_staff_active(transporter_company_id));

drop policy if exists seal_records_insert on public.seal_records;
create policy seal_records_insert on public.seal_records for insert to authenticated
  with check (exists (select 1 from public.transactions t
    where t.id = seal_records.transaction_id
      and public.is_company_staff_active(t.supplier_company_id)));

drop policy if exists security_confirmations_insert on public.security_confirmations;
create policy security_confirmations_insert on public.security_confirmations for insert to authenticated
  with check (public.is_platform_admin() or public.is_trip_driver(trip_id)
    or public.is_company_staff_active((select x.supplier_company_id
      from public.trips t join public.transactions x on x.id = t.transaction_id
      where t.id = security_confirmations.trip_id)));

drop policy if exists security_confirmations_update on public.security_confirmations;
create policy security_confirmations_update on public.security_confirmations for update to authenticated
  using (public.is_platform_admin() or public.is_trip_driver(trip_id)
    or public.is_company_staff((select x.supplier_company_id
      from public.trips t join public.transactions x on x.id = t.transaction_id
      where t.id = security_confirmations.trip_id)))
  with check (public.is_platform_admin() or public.is_trip_driver(trip_id)
    or public.is_company_staff_active((select x.supplier_company_id
      from public.trips t join public.transactions x on x.id = t.transaction_id
      where t.id = security_confirmations.trip_id)));

drop policy if exists transportation_requests_insert on public.transportation_requests;
create policy transportation_requests_insert on public.transportation_requests for insert to authenticated
  with check (public.is_company_staff_active(buyer_company_id));

drop policy if exists transportation_requests_update on public.transportation_requests;
create policy transportation_requests_update on public.transportation_requests for update to authenticated
  using (public.is_company_staff(buyer_company_id) or public.is_platform_admin())
  with check (public.is_company_staff_active(buyer_company_id) or public.is_platform_admin());

-- ---------------------------------------------------------------------------
-- VERIFIED ON PRODUCTION, four walks in rolled-back transactions.
--
-- Expired owner (SteelWorks SA, ttt@cyberhouse.co.za) — READS SURVIVE:
--   is_company_active               false
--   is_company_owner                true   (unchanged by design)
--   is_company_manager  (write)     false  ← the gate
--   is_company_manager_any_status   true   ← the read path
--   transactions readable           10     (unchanged)
--   trips readable                  12     (unchanged)
--   employees readable               3     (unchanged)
--
-- Expired owner — WRITES REFUSED:
--   UPDATE transactions             REFUSED (0 rows updatable)
--   INSERT transportation_requests  REFUSED (new row violates RLS policy)
--
-- Expired owner — RENEWAL PRESERVED:
--   INSERT token_requests (request_kind='token_renewal')   ALLOWED
--
-- ACTIVE company owner (Cyberhouse Mine Supplier) — NO REGRESSION:
--   is_company_active               true
--   is_company_manager  (write)     true
--   UPDATE minerals                 ALLOWED, 1 row
--
-- ---------------------------------------------------------------------------
-- WHAT THIS DOES **NOT** COVER, stated so it is not read as complete.
--
-- SECURITY DEFINER functions bypass RLS. There are **90 mutating RPCs**
-- executable by `authenticated`, and **0** of them consult company status. The
-- expired owner above was able to enter one (`set_notification_read` ran to its
-- own "Notification not found", i.e. it was refused by data, not by
-- authorisation). Since CLAUDE.md §6 requires lifecycle mutations to go through
-- the cascade RPCs, that is the larger half of G4 and it is still open.
--
-- Nor does this redirect anyone: `/expired-access` exists in app_router.dart
-- and nothing navigates to it. The block is currently silent — an expired
-- owner sees writes fail rather than a notice explaining why.
