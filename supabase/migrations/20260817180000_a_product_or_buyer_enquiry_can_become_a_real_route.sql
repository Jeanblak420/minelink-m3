-- Two faults, one story: what the platform admin does AFTER pressing Approve.
--
-- Found 2026-08-17 by driving all four request types as the real roles.
--
-- 1. APPROVING A `product` OR `buyer` REQUEST DROPPED THE ADMIN INTO THE
--    TRANSPORT FLOW WITH NOTHING TO WORK WITH.
--
--    A mine's "Requested buyers" request is a mine asking to be introduced to
--    buyers. On approval the console showed "Select the mine, set your pricing,
--    then step through the due-diligence gate to dispatch" -- steps
--    1 Supplying mine / 2 Pricing / 3 Dispatch to transporter(s). There was no
--    step to pick a BUYER anywhere in the product, so the one action the
--    request exists for could not be performed. And the request carries no
--    loading point, no offloading point and no truck count, so linking it minted
--    a route missing the terms a haul needs.
--
--    CLAUDE.md 4 is explicit that all four request types ultimately lead to a
--    scheduled trip. This adds the missing hinge: `prepare_request_for_linking`,
--    which lets the admin fill in the parties and route terms an enquiry does
--    not carry, before `link_and_dispatch_request` reads them off the row as it
--    always has. One RPC, no signature change to anything that already exists.
--
-- 2. A MINE-RAISED ORDER TOLD ITSELF IT WAS ITS OWN BUYER.
--
--    `v_order_party_id := coalesce(buyer_company_id, requesting_company_id)`
--    substituted the requester for the missing buyer, so dispatching Iron Hills
--    Mining's own transport request produced, verbatim:
--
--      to the mine:        "Iron Hills Mining ordered 90 t of Chrome Ore..."
--      to the mine:        "Your order ... was accepted. Iron Hills Mining is
--                           preparing your stockpile"
--      to the transporter: "...from Iron Hills Mining for Iron Hills Mining"
--
--    and `stockpiles.buyer_label` was set to the mine's own name. A missing
--    buyer is a real state -- a mine can book a haul before it has sold the
--    load. It should be reported as one, not papered over with the nearest
--    company name. No buyer now means: the buyer notification is not sent (there
--    is nobody to send it to), and the mine and transporter are told plainly
--    that no buyer is linked yet.

-- 1 ---------------------------------------------------------------------------
-- Fill in what an enquiry does not carry, before linking.

create or replace function public.prepare_request_for_linking(
  p_id uuid,
  p_buyer_company_id uuid default null,
  p_loading_point text default null,
  p_offloading_point text default null,
  p_tons text default null,
  p_num_trucks text default null
)
returns public.transportation_requests
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_row public.transportation_requests;
  v_org_type text;
begin
  if not public.is_platform_admin() then
    raise exception 'Only the MineLink representative may prepare a request for linking';
  end if;

  select * into v_row from public.transportation_requests where id = p_id;
  if not found then
    raise exception 'Request % not found', p_id;
  end if;
  if v_row.status = 'linked' then
    raise exception 'This request is already linked - its terms are fixed';
  end if;

  if p_buyer_company_id is not null then
    select org_type into v_org_type from public.companies where id = p_buyer_company_id;
    if v_org_type is null then
      raise exception 'Buying company % not found', p_buyer_company_id;
    end if;
    if v_org_type <> 'buyer' then
      raise exception 'The buying company must be a buyer, not a %', v_org_type;
    end if;
  end if;

  -- Every argument is optional and only a non-null one writes: this is called
  -- from a form where the admin fills the blanks, not one that resubmits the
  -- whole row.
  update public.transportation_requests set
    buyer_company_id = coalesce(p_buyer_company_id, buyer_company_id),
    loading_point    = coalesce(nullif(btrim(p_loading_point), ''), loading_point),
    offloading_point = coalesce(nullif(btrim(p_offloading_point), ''), offloading_point),
    tons_available   = coalesce(nullif(btrim(p_tons), ''), tons_available),
    num_slots        = coalesce(nullif(btrim(p_num_trucks), ''), num_slots)
  where id = p_id
  returning * into v_row;

  return v_row;
end;
$function$;

comment on function public.prepare_request_for_linking(uuid, uuid, text, text, text, text) is
  'Platform admin fills in the parties and route terms a product/buyer enquiry '
  'does not carry, before link_and_dispatch_request reads them off the row. '
  'Added 2026-08-17: approving a product or buyer request used to open the '
  'transport dispatch flow with no way to name a buyer and no route terms to '
  'mint a route from.';

revoke all on function public.prepare_request_for_linking(uuid, uuid, text, text, text, text) from public, anon;
grant execute on function public.prepare_request_for_linking(uuid, uuid, text, text, text, text) to authenticated;

-- 2 ---------------------------------------------------------------------------
-- A route with no buyer says so, instead of naming the mine.

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
      buyer_company_id = v_row.buyer_company_id,
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
    v_buyer_id uuid;
    v_buyer_name text;
    v_buyer_type text;
    v_for_clause text;
    v_supplier_name text;
    v_transporter_names text;
    v_cap numeric;
    v_cap_label text;
    v_mine_msg text;
    v_party_msg text;
    v_meta jsonb;
    v_rec record;
  begin
    -- No coalesce onto the requester. A mine that has booked a haul before it
    -- has sold the load genuinely has no buyer, and saying "Iron Hills Mining
    -- ordered ... for Iron Hills Mining" is not a smaller error than saying
    -- nothing.
    v_buyer_id := v_row.buyer_company_id;

    select company_name into v_supplier_name from public.companies where id = p_supplier_company_id;
    if v_buyer_id is not null then
      select company_name, org_type into v_buyer_name, v_buyer_type
        from public.companies where id = v_buyer_id;
    end if;
    select string_agg(company_name, ', ') into v_transporter_names
      from public.companies where id = any(p_transporter_ids);

    v_cap := nullif(regexp_replace(coalesce(v_row.tons_available, ''), '[^0-9.]', '', 'g'), '')::numeric;
    v_cap_label := coalesce(v_cap::text, 'the agreed tonnage');
    v_for_clause := case when v_buyer_name is null then ''
                         else ' for ' || v_buyer_name end;

    select id into v_stockpile_id from public.stockpiles where request_id = p_id;
    if v_stockpile_id is null then
      insert into public.stockpiles (
        supplier_company_id, buyer_company_id, buyer_label, name, mineral, grade,
        balance_tons, request_id, route_id, transporter_company_id, max_cap_tons, created_by
      ) values (
        p_supplier_company_id, v_buyer_id, coalesce(v_buyer_name, 'No buyer linked yet'),
        coalesce(v_row.commodity, 'Product') || ' - ' || coalesce(v_buyer_name, 'unsold'),
        v_row.commodity, null,
        0, p_id, v_route_id, p_transporter_ids[1], v_cap, auth.uid()
      )
      returning id into v_stockpile_id;
      insert into public.stockpile_transactions (stockpile_id, type, delta_tons, balance_after, created_by)
        values (v_stockpile_id, 'allocation', 0, 0, auth.uid());
    else
      update public.stockpiles set
        route_id = v_route_id,
        buyer_company_id = v_buyer_id,
        transporter_company_id = p_transporter_ids[1],
        max_cap_tons = v_cap,
        mineral = v_row.commodity,
        buyer_label = coalesce(v_buyer_name, 'No buyer linked yet')
      where id = v_stockpile_id;
    end if;

    v_meta := jsonb_build_object(
      'request_id', p_id, 'route_id', v_route_id, 'stockpile_id', v_stockpile_id);

    v_mine_msg := case
      when v_buyer_name is null then
        'A haul of ' || v_cap_label || ' t of ' || coalesce(v_row.commodity, 'product')
        || ' has been dispatched with no buyer linked yet.'
      else
        v_buyer_name || ' ordered ' || v_cap_label || ' t of '
        || coalesce(v_row.commodity, 'product') || '.'
      end
      || ' A stockpile has been created for this order (cap ' || v_cap_label || ' t). '
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
      || case when v_buyer_name is null then ' (no buyer linked yet)' else v_for_clause end
      || '. You will be alerted each time a full load (30 t) is ready on the stockpile.';
    foreach v_tid in array p_transporter_ids loop
      perform public.notify_company_role(
        v_tid, array['admin', 'management'], 'New order assigned', v_party_msg,
        'order_assigned', 'transporter', 'high', v_meta, true);
    end loop;

    -- Only tell a buyer when there is one. There is no honest way to send
    -- "your order was accepted" to nobody.
    if v_buyer_id is not null then
      perform public.notify_company_role(
        v_buyer_id, array['admin', 'management'], 'Order accepted & dispatched',
        'Your order for ' || v_cap_label || ' t of ' || coalesce(v_row.commodity, 'product')
          || ' was accepted. ' || coalesce(v_supplier_name, 'The mine')
          || ' is preparing your stockpile; you will be alerted each time a full load is ready.',
        'order_dispatched', coalesce(v_buyer_type, 'buyer'), 'high', v_meta, true);
    end if;
  exception when others then
    null;
  end;

  return v_row;
end;
$function$;
