-- 20260815118000_request_requesting_company.sql
--
-- A mine could not raise a transportation request. CLAUDE.md §4 marks the
-- feature 🟢 Built — "mine/supplier **and** buyer (identical fields)", with a
-- dedicated super-admin inbox split into Mine/Supplier vs Buyer transportation
-- requests — and **nothing could ever land in it**. Two things stopped it:
--
--   transportation_requests_insert   with check (is_company_staff_active(buyer_company_id))
--   buyer_company_id                 NOT NULL
--
-- so the request table had no way to express "raised by a mine". Confirmed
-- against the data as well as the policy: of 6 requests, 6 have a buyer and 0
-- were raised by a non-buyer company. It had never happened because it had
-- never been possible.
--
-- THE MODEL, per the client 2026-08-15
--
-- A mine raising one "will basically work the same as when a buyer requests
-- transport". It has product it wants moved — to a washplant, on behalf of
-- somebody else, or product it is itself buying from another mine. So the
-- party that matters is the one who RAISED it, and a buyer is optional
-- information, not the identity of the request.
--
--   requesting_company_id   who asked. Always present. Drives every policy.
--   buyer_company_id        who receives it, when that is known. Now nullable.
--
-- Existing rows backfill `requesting_company_id = buyer_company_id`, which is
-- exactly right: every request on the system to date was raised by its buyer.
-- Nothing changes for them, and no policy result changes for a buyer-raised
-- request — the two columns hold the same value.
--
-- `routes.buyer_company_id` and `stockpiles.buyer_company_id` were already
-- nullable, so a request with no buyer flows through dispatch without further
-- schema change. The notification half is 20260815119000.
--
-- The buyer, when named, keeps its visibility: a buyer must still see and edit
-- a request raised on its behalf.

alter table public.transportation_requests
  add column if not exists requesting_company_id uuid
    references public.companies(id) on delete cascade;

update public.transportation_requests
   set requesting_company_id = buyer_company_id
 where requesting_company_id is null;

alter table public.transportation_requests
  alter column requesting_company_id set not null;

-- A mine looking for a transporter has no buyer to name.
alter table public.transportation_requests
  alter column buyer_company_id drop not null;

create index if not exists transportation_requests_requesting_company_id_idx
  on public.transportation_requests (requesting_company_id);

-- ---------------------------------------------------------------- policies --
-- Each one moves from buyer_company_id to requesting_company_id, and keeps the
-- named buyer's access alongside it.

drop policy if exists transportation_requests_insert on public.transportation_requests;
create policy transportation_requests_insert
  on public.transportation_requests for insert to authenticated
  with check (public.is_company_staff_active(requesting_company_id));

drop policy if exists transportation_requests_select on public.transportation_requests;
create policy transportation_requests_select
  on public.transportation_requests for select to authenticated
  using (
    public.is_company_staff(requesting_company_id)
    or (buyer_company_id is not null and public.is_company_staff(buyer_company_id))
    or public.is_platform_admin()
  );

drop policy if exists transportation_requests_update on public.transportation_requests;
create policy transportation_requests_update
  on public.transportation_requests for update to authenticated
  using (
    public.is_company_staff(requesting_company_id)
    or (buyer_company_id is not null and public.is_company_staff(buyer_company_id))
    or public.is_platform_admin()
  )
  with check (
    public.is_company_staff_active(requesting_company_id)
    or (buyer_company_id is not null and public.is_company_staff_active(buyer_company_id))
    or public.is_platform_admin()
  );

drop policy if exists transportation_requests_delete on public.transportation_requests;
create policy transportation_requests_delete
  on public.transportation_requests for delete to authenticated
  using (
    public.is_company_manager(requesting_company_id)
    or public.is_platform_admin()
  );

comment on column public.transportation_requests.requesting_company_id is
  'The company that raised the request - a buyer OR a mine/supplier. Every '
  'policy keys off this. buyer_company_id is who receives the product and is '
  'null when a mine is simply having its own product moved. See 20260815118000.';
