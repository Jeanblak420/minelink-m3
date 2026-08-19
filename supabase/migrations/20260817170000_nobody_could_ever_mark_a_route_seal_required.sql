-- Nobody could ever mark a route seal-required.
--
-- `routes.seal_required` has existed since 20260627000000. The Load Controller
-- screen reads it to show a "Seals required" badge and to block the load
-- without a number and a photo for each seal, and `record_truck_load` enforces
-- the same rule server-side ('This route requires seals: capture each seal
-- number and photo before saving').
--
-- None of that has ever run. Measured 2026-08-17 on production:
--
--     select count(*) from public.routes where seal_required;   -->  0
--
-- and not by coincidence -- there was **no writer for the column anywhere in the
-- product**. The transport request form has no seals field; `link_and_dispatch_
-- request` never sets it; a repo-wide search of `lib/` for `seal_required` /
-- `sealRequired` returns reads only (`mine_trip.dart:12,39,73`,
-- `load_controller_screen.dart:636,656`); and no RPC touched it. The column
-- took its `default false` and stayed there. A whole enforcement path, client
-- and server, sat behind a flag no user could turn on.
--
-- This migration gives it two writers, matching how the rest of a route's terms
-- are decided:
--
--   1. **The requester declares it** -- `transportation_requests.seal_required`,
--      set on the request form, carried into `routes.seal_required` when the
--      platform admin links and dispatches. That is where every other route
--      term (commodity, points, hours, payment terms) already comes from.
--   2. **The supplying mine or the platform admin can change it afterwards** --
--      `set_route_seal_requirement`, deliberately shaped like the sibling
--      `set_route_quality_spec` (same authority test, same return). Seals are
--      physically applied at the mine, so the mine has to be able to say so
--      without going back through the admin.
--
-- `record_truck_load` needs no change: its enforcement was correct all along,
-- it simply never had a true value to act on.

-- 1 -------------------------------------------------------------------------
-- The request carries the requirement.

alter table public.transportation_requests
  add column if not exists seal_required boolean not null default false;

comment on column public.transportation_requests.seal_required is
  'Requester declares that every load on this route must be sealed. Carried '
  'into routes.seal_required by link_and_dispatch_request, where the Load '
  'Controller''s capture rule and record_truck_load''s enforcement read it.';

comment on column public.routes.seal_required is
  'Every load on this route needs a seal number AND a seal photo before it can '
  'be recorded -- enforced in record_truck_load, not only in the UI. Written by '
  'link_and_dispatch_request (from the request) and by set_route_seal_requirement '
  '(the supplying mine or the platform admin).';

-- 2 -------------------------------------------------------------------------
-- Carry it through linking. Only the two `routes` statements change; the rest
-- of the function is reproduced verbatim so the definition stays whole.

create or replace function public.link_and_dispatch_request(
  p_id uuid,
  p_supplier_company_id uuid,
  p_agreed_price numeric,
  p_admin_margin numeric,
  p_transporter_ids uuid[]
)
returns public.transportation_requests
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

  select id into v_route_id from public.routes where request_id = p_id;
  if v_route_id is null then
    insert into public.routes (
      route_number, request_id, supplier_company_id, buyer_company_id,
      commodity, payment_terms, loading_point, offloading_point,
      operating_hours_24h, operating_start, operating_end,
      tons, num_trucks, transaction_kind, product_specifications, route_notes,
      seal_required,
      created_by
    ) values (
      'RT-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8)),
      p_id, p_supplier_company_id, v_row.buyer_company_id,
      v_row.commodity, v_row.payment_terms, v_row.loading_point, v_row.offloading_point,
      v_row.operating_hours_24h, v_row.operating_start, v_row.operating_end,
      v_row.tons_available, v_row.num_slots, v_row.transaction_kind,
      v_row.product_specifications, v_row.route_notes,
      coalesce(v_row.seal_required, false),
      auth.uid()
    )
    returning id into v_route_id;
  else
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
      route_notes = v_row.route_notes,
      seal_required = coalesce(v_row.seal_required, false)
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
    v_stockpile_id uuid;
    v_order_party_id uuid;
    v_order_party_name text;
    v_order_party_type text;
    v_supplier_name text;
    v_transporter_names text;
    v_cap numeric;
    v_cap_label text;
    v_mine_msg text;
    v_party_msg text;
    v_meta jsonb;
    v_rec record;
  begin
    v_order_party_id := coalesce(v_row.buyer_company_id, v_row.requesting_company_id);

    select company_name into v_supplier_name from public.companies where id = p_supplier_company_id;
    select company_name, org_type into v_order_party_name, v_order_party_type
      from public.companies where id = v_order_party_id;
    select string_agg(company_name, ', ') into v_transporter_names
      from public.companies where id = any(p_transporter_ids);

    v_cap := nullif(regexp_replace(coalesce(v_row.tons_available, ''), '[^0-9.]', '', 'g'), '')::numeric;
    v_cap_label := coalesce(v_cap::text, 'the agreed tonnage');

    select id into v_stockpile_id from public.stockpiles where request_id = p_id;
    if v_stockpile_id is null then
      insert into public.stockpiles (
        supplier_company_id, buyer_company_id, buyer_label, name, mineral, grade,
        balance_tons, request_id, route_id, transporter_company_id, max_cap_tons, created_by
      ) values (
        p_supplier_company_id, v_row.buyer_company_id, v_order_party_name,
        coalesce(v_row.commodity, 'Product') || ' - ' || coalesce(v_order_party_name, 'order'),
        v_row.commodity, null,
        0, p_id, v_route_id, p_transporter_ids[1], v_cap, auth.uid()
      )
      returning id into v_stockpile_id;
      insert into public.stockpile_transactions (stockpile_id, type, delta_tons, balance_after, created_by)
        values (v_stockpile_id, 'allocation', 0, 0, auth.uid());
    else
      update public.stockpiles set
        route_id = v_route_id,
        transporter_company_id = p_transporter_ids[1],
        max_cap_tons = v_cap,
        mineral = v_row.commodity,
        buyer_label = v_order_party_name
      where id = v_stockpile_id;
    end if;

    v_meta := jsonb_build_object(
      'request_id', p_id, 'route_id', v_route_id, 'stockpile_id', v_stockpile_id);

    v_mine_msg := coalesce(v_order_party_name, 'A buyer') || ' ordered ' || v_cap_label
      || ' t of ' || coalesce(v_row.commodity, 'product')
      || '. A stockpile has been created for this order (cap ' || v_cap_label || ' t). '
      || 'Add product to it on site as it arrives - ' || coalesce(v_transporter_names, 'the transporter')
      || ' will be alerted every full load so their trucks only roll when there is enough to collect.';

    perform public.create_notification_internal(
      (select user_id from public.companies where id = p_supplier_company_id),
      p_supplier_company_id, null, 'New stockpile to prepare', v_mine_msg, 'stockpile_prepare',
      null, auth.uid(), 'supervisorForeman', 'mineSupplier', 'high', v_meta);
    for v_rec in
      select e.user_id, e.role from public.employees e
      where e.company_id = p_supplier_company_id
        and e.role in ('supervisorForeman', 'admin', 'management')
        and e.status = 'active' and coalesce(e.is_dismissed, false) = false
        and e.user_id is not null
    loop
      perform public.create_notification_internal(
        v_rec.user_id, p_supplier_company_id, null, 'New stockpile to prepare', v_mine_msg,
        'stockpile_prepare', null, auth.uid(), v_rec.role, 'mineSupplier', 'high', v_meta);
    end loop;

    v_party_msg := 'You have been assigned an order: ' || v_cap_label || ' t of '
      || coalesce(v_row.commodity, 'product') || ' from ' || coalesce(v_supplier_name, 'the mine')
      || ' for ' || coalesce(v_order_party_name, 'the customer')
      || '. You will be alerted each time a full load (30 t) is ready on the stockpile.';
    foreach v_tid in array p_transporter_ids loop
      perform public.notify_company_role(
        v_tid, array['admin', 'management'], 'New order assigned', v_party_msg,
        'order_assigned', 'transporter', 'high', v_meta, true);
    end loop;

    perform public.notify_company_role(
      v_order_party_id, array['admin', 'management'], 'Order accepted & dispatched',
      'Your order for ' || v_cap_label || ' t of ' || coalesce(v_row.commodity, 'product')
        || ' was accepted. ' || coalesce(v_supplier_name, 'The mine')
        || ' is preparing your stockpile; you will be alerted each time a full load is ready.',
      'order_dispatched', coalesce(v_order_party_type, 'buyer'), 'high', v_meta, true);
  exception when others then
    null;
  end;

  return v_row;
end;
$function$;

-- 3 -------------------------------------------------------------------------
-- The mine (or the platform admin) can change it on a live route.
--
-- Shaped exactly like set_route_quality_spec: same authority test, returns the
-- row, SECURITY DEFINER over a table whose write policies stay closed.

create or replace function public.set_route_seal_requirement(
  p_route_id uuid,
  p_required boolean
)
returns public.routes
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.routes;
begin
  if p_required is null then
    raise exception 'Say whether seals are required (true) or not (false)';
  end if;

  select * into v_row from public.routes where id = p_route_id;
  if not found then
    raise exception 'Route % not found', p_route_id;
  end if;

  -- Seals are physically applied at the mine, so the supplying mine can set
  -- this without going through the platform admin.
  if not (public.is_platform_admin()
          or public.is_company_staff(v_row.supplier_company_id)) then
    raise exception 'Only the supplying mine or the platform admin may change the seal requirement';
  end if;

  update public.routes set seal_required = p_required
  where id = p_route_id
  returning * into v_row;

  return v_row;
end;
$function$;

comment on function public.set_route_seal_requirement(uuid, boolean) is
  'Turn the seal requirement on or off for a live route. Supplying mine or '
  'platform admin only. Until 2026-08-17 routes.seal_required had no writer at '
  'all, so record_truck_load''s seal enforcement could never fire.';

revoke all on function public.set_route_seal_requirement(uuid, boolean) from public, anon;
grant execute on function public.set_route_seal_requirement(uuid, boolean) to authenticated;
