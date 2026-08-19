-- Route ID as a standalone entity (CLAUDE.md §4 "Linking → Route ID").
--
-- At link time the system now creates a `routes` row — the entity holding all
-- the request info that goes to the transporter (commodity, payment terms,
-- loading/offloading point, operational hours, etc.) EXCEPT price per ton
-- (pricing lives in the margin ledger / dispatch rows). Pricing and dispatches
-- were previously keyed only by request_id; both now carry route_id, and trips
-- inherit route_id from their dispatch (the pre-existing trips.route_id column
-- finally gains meaning). Existing linked requests are backfilled one route
-- each.

begin;

-- 1. The entity -----------------------------------------------------------

create table if not exists public.routes (
  id uuid primary key default gen_random_uuid(),
  route_number text not null unique,
  request_id uuid references public.transportation_requests(id) on delete set null,
  supplier_company_id uuid references public.companies(id) on delete set null,
  buyer_company_id uuid references public.companies(id) on delete set null,
  commodity text,
  payment_terms text,
  loading_point text,
  offloading_point text,
  operating_hours_24h boolean not null default false,
  operating_start text,
  operating_end text,
  tons text,
  num_trucks text,
  transaction_kind text,
  product_specifications text,
  route_notes text,
  created_by uuid,
  created_at timestamptz not null default timezone('utc', now())
);

alter table public.routes enable row level security;

-- 2. Key pricing + dispatches by route (before the policy below, which
--    references request_dispatches.route_id) ---------------------------------

alter table public.request_dispatches
  add column if not exists route_id uuid references public.routes(id) on delete set null;

alter table public.margin_ledger
  add column if not exists route_id uuid references public.routes(id) on delete set null;

drop policy if exists routes_select on public.routes;
create policy routes_select
on public.routes
for select
to authenticated
using (
  public.is_platform_admin()
  or public.is_company_staff(supplier_company_id)
  or public.is_company_staff(buyer_company_id)
  or exists (
    select 1 from public.request_dispatches d
    where d.route_id = routes.id
      and public.is_company_staff(d.transporter_company_id)
  )
);
-- Writes happen only inside link_and_dispatch_request (SECURITY DEFINER).

-- 3. Backfill: one route per already-linked request (from its ledger entry).

insert into public.routes (
  route_number, request_id, supplier_company_id, buyer_company_id,
  commodity, payment_terms, loading_point, offloading_point,
  operating_hours_24h, operating_start, operating_end,
  tons, num_trucks, transaction_kind, product_specifications, route_notes,
  created_by, created_at
)
select distinct on (r.id)
  'RT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
  r.id, l.supplier_company_id, r.buyer_company_id,
  r.commodity, r.payment_terms, r.loading_point, r.offloading_point,
  r.operating_hours_24h, r.operating_start, r.operating_end,
  r.tons_available, r.num_slots, r.transaction_kind, r.product_specifications,
  r.route_notes, l.created_by, l.created_at
from public.margin_ledger l
join public.transportation_requests r on r.id = l.request_id
where not exists (select 1 from public.routes rt where rt.request_id = r.id)
order by r.id, l.created_at desc;

update public.margin_ledger l
set route_id = rt.id
from public.routes rt
where rt.request_id = l.request_id and l.route_id is null;

update public.request_dispatches d
set route_id = rt.id
from public.routes rt
where rt.request_id = d.request_id and d.route_id is null;

-- trips.route_id predates this table; clear values that point nowhere, then
-- stamp from the dispatch.
update public.trips t
set route_id = null
where t.route_id is not null
  and not exists (select 1 from public.routes rt where rt.id = t.route_id);

update public.trips t
set route_id = d.route_id
from public.request_dispatches d
where t.dispatch_id = d.id and d.route_id is not null and t.route_id is null;

-- 4. link_and_dispatch_request now mints the Route ID -------------------------

create or replace function public.link_and_dispatch_request(
  p_id uuid,
  p_supplier_company_id uuid,
  p_agreed_price numeric,
  p_admin_margin numeric,
  p_transporter_ids uuid[]
)
returns transportation_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.transportation_requests;
  v_tid uuid;
  v_transporter_price numeric;
  v_route_id uuid;
begin
  if not public.is_platform_admin() then
    raise exception 'Only the MineLink representative may link and dispatch requests';
  end if;
  if not exists (select 1 from public.transportation_requests where id = p_id) then
    raise exception 'Request % not found', p_id;
  end if;
  if p_supplier_company_id is null then
    raise exception 'Select the supplying mine first';
  end if;
  if p_transporter_ids is null or array_length(p_transporter_ids, 1) is null then
    raise exception 'Select at least one transporter to dispatch to';
  end if;
  if p_agreed_price is null or p_admin_margin is null then
    raise exception 'Enter the agreed price per ton and your margin';
  end if;
  if p_agreed_price < 0 or p_admin_margin < 0 then
    raise exception 'Price and margin must be zero or positive';
  end if;
  if p_admin_margin > p_agreed_price then
    raise exception 'Margin cannot exceed the agreed price';
  end if;

  v_transporter_price := p_agreed_price - p_admin_margin;

  select * into v_row from public.transportation_requests where id = p_id;

  -- The Route ID: everything the transporter gets, except price per ton.
  select id into v_route_id from public.routes where request_id = p_id;
  if v_route_id is null then
    insert into public.routes (
      route_number, request_id, supplier_company_id, buyer_company_id,
      commodity, payment_terms, loading_point, offloading_point,
      operating_hours_24h, operating_start, operating_end,
      tons, num_trucks, transaction_kind, product_specifications, route_notes,
      created_by
    ) values (
      'RT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
      p_id, p_supplier_company_id, v_row.buyer_company_id,
      v_row.commodity, v_row.payment_terms, v_row.loading_point, v_row.offloading_point,
      v_row.operating_hours_24h, v_row.operating_start, v_row.operating_end,
      v_row.tons_available, v_row.num_slots, v_row.transaction_kind,
      v_row.product_specifications, v_row.route_notes,
      auth.uid()
    )
    returning id into v_route_id;
  else
    -- Re-link: refresh the route snapshot from the request + chosen mine.
    update public.routes set
      supplier_company_id = p_supplier_company_id,
      commodity = v_row.commodity,
      payment_terms = v_row.payment_terms,
      loading_point = v_row.loading_point,
      offloading_point = v_row.offloading_point,
      operating_hours_24h = v_row.operating_hours_24h,
      operating_start = v_row.operating_start,
      operating_end = v_row.operating_end,
      tons = v_row.tons_available,
      num_trucks = v_row.num_slots,
      transaction_kind = v_row.transaction_kind,
      product_specifications = v_row.product_specifications,
      route_notes = v_row.route_notes
    where id = v_route_id;
  end if;

  insert into public.margin_ledger (
    request_id, route_id, supplier_company_id, agreed_price_per_ton,
    admin_margin_per_ton, transporter_price_per_ton, currency, created_by
  ) values (
    p_id, v_route_id, p_supplier_company_id, p_agreed_price,
    p_admin_margin, v_transporter_price, 'ZAR', auth.uid()
  );

  foreach v_tid in array p_transporter_ids loop
    insert into public.request_dispatches (
      request_id, route_id, transporter_company_id, dispatched_by, transporter_price_per_ton
    ) values (p_id, v_route_id, v_tid, auth.uid(), v_transporter_price)
    on conflict (request_id, transporter_company_id) do update
      set transporter_price_per_ton = excluded.transporter_price_per_ton,
          route_id = excluded.route_id;
  end loop;

  update public.transportation_requests set
    supplier_company_id = p_supplier_company_id,
    status = 'linked',
    reviewed_by = auth.uid(),
    reviewed_at = timezone('utc', now())
  where id = p_id
  returning * into v_row;

  declare
    v_buyer_name text;
    v_supplier_name text;
    v_transporter_names text;
    v_msg text;
    v_title text := 'New stockpile to prepare';
    v_rec record;
  begin
    select company_name into v_supplier_name
      from public.companies where id = p_supplier_company_id;
    select company_name into v_buyer_name
      from public.companies where id = v_row.buyer_company_id;
    select string_agg(company_name, ', ') into v_transporter_names
      from public.companies where id = any(p_transporter_ids);

    v_msg := coalesce(nullif(v_row.tons_available, ''), 'The agreed tonnage')
      || ' of ' || coalesce(v_row.commodity, 'product')
      || ' for ' || coalesce(v_buyer_name, 'the buyer')
      || ' has been approved by ' || coalesce(v_supplier_name, 'the mine')
      || '. Please start adding it to a stockpile, add it to your stockpile list, '
      || 'and update it every time you add product to the physical stockpile for '
      || coalesce(v_transporter_names, 'the transporter')
      || ' so they know when their trucks can collect.';

    perform public.create_notification_internal(
      (select user_id from public.companies where id = p_supplier_company_id),
      p_supplier_company_id, null, v_title, v_msg, 'stockpile_prepare',
      null, auth.uid(), 'supervisorForeman', 'mineSupplier', 'high',
      jsonb_build_object('request_id', p_id, 'route_id', v_route_id)
    );
    for v_rec in
      select e.user_id, e.role
      from public.employees e
      where e.company_id = p_supplier_company_id
        and e.role in ('supervisorForeman', 'admin', 'management')
        and e.status = 'active'
        and coalesce(e.is_dismissed, false) = false
    loop
      perform public.create_notification_internal(
        v_rec.user_id, p_supplier_company_id, null, v_title, v_msg, 'stockpile_prepare',
        null, auth.uid(), v_rec.role, 'mineSupplier', 'high',
        jsonb_build_object('request_id', p_id, 'route_id', v_route_id)
      );
    end loop;
  exception when others then
    null;
  end;

  return v_row;
end;
$function$;

-- 5. Trips inherit the Route ID from their dispatch ---------------------------
-- (Body is the fleet-availability version plus route_id in the trips insert.)

create or replace function public.accept_request_dispatch(p_dispatch_id uuid, p_vehicle_ids uuid[])
returns request_dispatches
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_dispatch public.request_dispatches;
  v_req public.transportation_requests;
  v_vehicle public.fleet_vehicles;
  v_vid uuid;
  v_txn_id uuid;
  v_ref text;
begin
  select * into v_dispatch from public.request_dispatches where id = p_dispatch_id;
  if not found then raise exception 'Dispatch % not found', p_dispatch_id; end if;

  if not public.is_company_manager(v_dispatch.transporter_company_id) then
    raise exception 'Only the transporter''s admin/management may accept routes';
  end if;
  if v_dispatch.status <> 'dispatched' then
    raise exception 'This route is no longer open to accept';
  end if;
  if p_vehicle_ids is null or array_length(p_vehicle_ids, 1) is null then
    raise exception 'Tick at least one truck to accept this route';
  end if;

  select * into v_req from public.transportation_requests where id = v_dispatch.request_id;
  if not found then raise exception 'Request for dispatch % not found', p_dispatch_id; end if;

  foreach v_vid in array p_vehicle_ids loop
    select * into v_vehicle from public.fleet_vehicles where id = v_vid;
    if not found or v_vehicle.company_id <> v_dispatch.transporter_company_id then
      raise exception 'Truck % is not in your fleet', v_vid;
    end if;

    -- State machine: a truck already on an active trip is On Route and cannot
    -- be assigned again until that trip completes.
    if exists (
      select 1 from public.trips t
      where t.vehicle_id = v_vid
        and t.status not in ('completed', 'cancelled')
    ) then
      raise exception 'Truck % is already on a route and cannot be assigned again',
        v_vehicle.vehicle_registration_number;
    end if;

    v_ref := 'TRP-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 10));
    insert into public.transactions (
      reference_number, supplier_company_id, buyer_company_id, transporter_company_id,
      status, quantity, dispatch_id, created_by, metadata
    ) values (
      v_ref, v_req.supplier_company_id, v_req.buyer_company_id, v_dispatch.transporter_company_id,
      'scheduled', 0, p_dispatch_id, auth.uid(),
      jsonb_build_object(
        'request_id', v_req.id,
        'dispatch_id', p_dispatch_id,
        'commodity', v_req.commodity,
        'loading_point', v_req.loading_point,
        'offloading_point', v_req.offloading_point,
        'rate', v_req.rate,
        'payment_terms', v_req.payment_terms
      )
    ) returning id into v_txn_id;

    insert into public.trips (transaction_id, vehicle_id, status, dispatch_id, route_id, metadata)
    values (
      v_txn_id, v_vid, 'scheduled', p_dispatch_id, v_dispatch.route_id,
      jsonb_build_object('truck_reg', v_vehicle.vehicle_registration_number)
    );
  end loop;

  update public.request_dispatches set status = 'accepted'
  where id = p_dispatch_id
  returning * into v_dispatch;
  return v_dispatch;
end;
$function$;

-- 6. The ledger shows the Route ID (return type changes → drop + recreate).

drop function if exists public.list_margin_ledger();

create function public.list_margin_ledger()
returns table (
  id uuid,
  request_id uuid,
  route_id uuid,
  route_number text,
  supplier_name text,
  agreed_price_per_ton numeric,
  admin_margin_per_ton numeric,
  transporter_price_per_ton numeric,
  currency text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select l.id, l.request_id, l.route_id, rt.route_number, sc.company_name,
    l.agreed_price_per_ton, l.admin_margin_per_ton, l.transporter_price_per_ton,
    l.currency, l.created_at
  from public.margin_ledger l
  left join public.routes rt on rt.id = l.route_id
  left join public.companies sc on sc.id = l.supplier_company_id
  where public.is_platform_admin()
  order by l.created_at desc;
$function$;

revoke all on function public.list_margin_ledger() from public;
revoke all on function public.list_margin_ledger() from anon;
grant execute on function public.list_margin_ledger() to authenticated;

commit;
