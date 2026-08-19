-- 20260815119000_dispatch_notifies_requester.sql
--
-- Second half of 20260815118000. A transportation request can now be raised by
-- a mine with no buyer, so every place `link_and_dispatch_request` said
-- "the buyer" has to mean "whoever asked for this haul".
--
-- Left as it was, dispatching a mine-raised request would have:
--   * named the order stockpile "Chrome Ore - buyer" and labelled it for a
--     buyer that does not exist,
--   * told the mine that "A buyer ordered 500 t", which is nobody, and
--   * called notify_company_role(null, …) for the "Order accepted & dispatched"
--     message, notifying no one — silently, because the whole block sits
--     inside `exception when others then null`.
--
-- The requester is now resolved once and used wherever a buyer was assumed:
--
--   v_order_party_id    coalesce(buyer_company_id, requesting_company_id)
--   v_order_party_name  that company's name
--   v_order_party_type  that company's org_type, so the notification is scoped
--                       to the right kind of organisation rather than always
--                       'buyer'
--
-- For a buyer-raised request the two columns hold the same value, so nothing
-- changes for the six requests already on the system.
--
-- ⚠ The `exception when others then null` around the stockpile + notification
-- block is left exactly as found. It is what hid the notification-vocabulary
-- defect for a month (see 20260815109000) and it deserves attention — but
-- removing it here would mean a failed notification aborts a dispatch that has
-- already written its route, margin ledger and dispatch rows. That is a
-- separate decision, deliberately not taken in a migration about buyers.

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
    -- Whoever asked for the haul: the buyer when there is one, otherwise the
    -- company that raised the request (a mine moving its own product).
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

    -- To the party that asked for it, scoped to the right kind of organisation.
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
