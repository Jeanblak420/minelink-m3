-- Auto-connect orgs that do business so chat contacts are individual per org.
--
-- Root cause (Jean, 2026-07-13): the chat "Contacts" list a non-admin sees comes
-- from get_chat_contacts, which unions three groups — MY COMPANY (coworkers),
-- MINE-LINK (the platform admins), and CONNECTED (companies joined via
-- public.org_connections). Nothing ever populated org_connections except a manual
-- super-admin action, so that table was empty. With no connections, every
-- non-admin collapsed to the SAME list (own company + the two MineLink admins) —
-- which is why "all chats look the same except the super admin". The parties of a
-- transaction (mine ↔ buyer ↔ transporter) are genuine business partners and
-- should be able to message each other like any WhatsApp/Messenger contact.
--
-- Fix: connect the three parties automatically the moment they are tied together
-- (a dispatch is created, and again when a transaction/trip is created), via
-- AFTER INSERT triggers so every code path is covered, plus a one-time backfill
-- of all existing business. Idempotent and non-destructive: an existing row
-- (including a super-admin's manual 'revoked') is never overwritten.

-- ---------------------------------------------------------------------------
-- Helper: connect two companies (idempotent, ordered low<high, granted).
-- ---------------------------------------------------------------------------
create or replace function public.chat_connect_orgs(
  p_a uuid,
  p_b uuid,
  p_by uuid default null
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_low uuid;
  v_high uuid;
begin
  -- Skip nulls and self-pairs; the table's CHECK requires low < high.
  if p_a is null or p_b is null or p_a = p_b then
    return;
  end if;
  if p_a < p_b then
    v_low := p_a; v_high := p_b;
  else
    v_low := p_b; v_high := p_a;
  end if;
  insert into public.org_connections (
    company_low_id, company_high_id, status, granted_by, granted_at
  )
  values (v_low, v_high, 'granted', p_by, now())
  -- Never override an existing pair (respects a manual revoke).
  on conflict (company_low_id, company_high_id) do nothing;
end;
$$;

-- Internal helper — not a public API.
revoke all on function public.chat_connect_orgs(uuid, uuid, uuid) from public;

-- ---------------------------------------------------------------------------
-- Trigger: a transaction ties supplier ↔ buyer ↔ transporter together.
-- ---------------------------------------------------------------------------
create or replace function public.trg_connect_transaction_parties()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  perform public.chat_connect_orgs(new.supplier_company_id, new.buyer_company_id, new.created_by);
  perform public.chat_connect_orgs(new.supplier_company_id, new.transporter_company_id, new.created_by);
  perform public.chat_connect_orgs(new.buyer_company_id, new.transporter_company_id, new.created_by);
  return new;
exception when others then
  -- Chat wiring must never block the core transaction insert.
  return new;
end;
$$;

drop trigger if exists connect_transaction_parties on public.transactions;
create trigger connect_transaction_parties
  after insert on public.transactions
  for each row execute function public.trg_connect_transaction_parties();

-- Trigger function only — must not be a callable REST endpoint.
revoke all on function public.trg_connect_transaction_parties() from public;

-- ---------------------------------------------------------------------------
-- Trigger: a dispatch puts a transporter into a request's buyer/supplier loop
-- (fires at link_and_dispatch_request time, before the transporter accepts).
-- ---------------------------------------------------------------------------
create or replace function public.trg_connect_dispatch_parties()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_buyer uuid;
  v_supplier uuid;
begin
  select r.buyer_company_id, r.supplier_company_id
    into v_buyer, v_supplier
    from public.transportation_requests r
    where r.id = new.request_id;
  -- Supplier is often only finalised on the route at link time.
  if v_supplier is null and new.route_id is not null then
    select ro.supplier_company_id into v_supplier
      from public.routes ro where ro.id = new.route_id;
  end if;
  perform public.chat_connect_orgs(new.transporter_company_id, v_buyer, new.dispatched_by);
  perform public.chat_connect_orgs(new.transporter_company_id, v_supplier, new.dispatched_by);
  perform public.chat_connect_orgs(v_buyer, v_supplier, new.dispatched_by);
  return new;
exception when others then
  return new;
end;
$$;

drop trigger if exists connect_dispatch_parties on public.request_dispatches;
create trigger connect_dispatch_parties
  after insert on public.request_dispatches
  for each row execute function public.trg_connect_dispatch_parties();

-- Trigger function only — must not be a callable REST endpoint.
revoke all on function public.trg_connect_dispatch_parties() from public;

-- ---------------------------------------------------------------------------
-- Backfill: connect every pair implied by existing business.
-- ---------------------------------------------------------------------------
insert into public.org_connections (company_low_id, company_high_id, status)
select least(a, b), greatest(a, b), 'granted'
from (
  -- transactions: all three parties
  select supplier_company_id as a, buyer_company_id as b from public.transactions
  union all
  select supplier_company_id, transporter_company_id from public.transactions
  union all
  select buyer_company_id, transporter_company_id from public.transactions
  -- routes: mine ↔ buyer
  union all
  select supplier_company_id, buyer_company_id from public.routes
  -- dispatches: transporter ↔ the request's buyer/supplier
  union all
  select d.transporter_company_id, r.buyer_company_id
    from public.request_dispatches d
    join public.transportation_requests r on r.id = d.request_id
  union all
  select d.transporter_company_id, r.supplier_company_id
    from public.request_dispatches d
    join public.transportation_requests r on r.id = d.request_id
) pairs(a, b)
where a is not null and b is not null and a <> b
on conflict (company_low_id, company_high_id) do nothing;
