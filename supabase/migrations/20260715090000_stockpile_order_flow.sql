-- Order-driven stockpile flow (buyer request -> super-admin link+dispatch ->
-- auto-created capped stockpile at the mine -> supervisor fills it on site ->
-- +30t "ready to collect" alerts to buyer + transporter).
--
-- A supervisor may NO LONGER freely create stockpiles: the system creates one,
-- linked to the request, when the super-admin dispatches the order. Everything
-- (request <-> stockpile <-> buyer <-> transporter <-> mine) is linked and the
-- parties are notified so they can all see the same fill level.

-- 1. Link columns + per-request uniqueness -----------------------------------
alter table public.stockpiles
  add column if not exists request_id uuid references public.transportation_requests(id) on delete set null,
  add column if not exists route_id uuid references public.routes(id) on delete set null,
  add column if not exists transporter_company_id uuid references public.companies(id) on delete set null,
  add column if not exists max_cap_tons numeric;

create unique index if not exists stockpiles_request_id_key
  on public.stockpiles(request_id) where request_id is not null;

-- 2. link_and_dispatch_request: auto-create the linked, capped stockpile and
--    notify the mine supervisor (with a stockpile deep-link), the transporter(s)
--    and the buyer. Route/margin/dispatch logic is unchanged.
create or replace function public.link_and_dispatch_request(
  p_id uuid, p_supplier_company_id uuid, p_agreed_price numeric,
  p_admin_margin numeric, p_transporter_ids uuid[])
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

  -- Auto-create the linked, capped stockpile + notify all parties.
  declare
    v_stockpile_id uuid;
    v_buyer_name text;
    v_supplier_name text;
    v_transporter_names text;
    v_cap numeric;
    v_cap_label text;
    v_mine_msg text;
    v_party_msg text;
    v_meta jsonb;
    v_rec record;
  begin
    select company_name into v_supplier_name from public.companies where id = p_supplier_company_id;
    select company_name into v_buyer_name   from public.companies where id = v_row.buyer_company_id;
    select string_agg(company_name, ', ') into v_transporter_names
      from public.companies where id = any(p_transporter_ids);

    v_cap := nullif(regexp_replace(coalesce(v_row.tons_available, ''), '[^0-9.]', '', 'g'), '')::numeric;
    v_cap_label := coalesce(v_cap::text, 'the agreed tonnage');

    -- One stockpile per request (idempotent on re-dispatch).
    select id into v_stockpile_id from public.stockpiles where request_id = p_id;
    if v_stockpile_id is null then
      insert into public.stockpiles (
        supplier_company_id, buyer_company_id, buyer_label, name, mineral, grade,
        balance_tons, request_id, route_id, transporter_company_id, max_cap_tons, created_by
      ) values (
        p_supplier_company_id, v_row.buyer_company_id, v_buyer_name,
        coalesce(v_row.commodity, 'Product') || ' - ' || coalesce(v_buyer_name, 'buyer'),
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
        buyer_label = v_buyer_name
      where id = v_stockpile_id;
    end if;

    v_meta := jsonb_build_object(
      'request_id', p_id, 'route_id', v_route_id, 'stockpile_id', v_stockpile_id);

    -- Mine supervisor(s): clickable -> opens this stockpile.
    v_mine_msg := coalesce(v_buyer_name, 'A buyer') || ' ordered ' || v_cap_label
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

    -- Transporter(s): you have been assigned this order.
    v_party_msg := 'You have been assigned an order: ' || v_cap_label || ' t of '
      || coalesce(v_row.commodity, 'product') || ' from ' || coalesce(v_supplier_name, 'the mine')
      || ' for ' || coalesce(v_buyer_name, 'the buyer')
      || '. You will be alerted each time a full load (30 t) is ready on the stockpile.';
    foreach v_tid in array p_transporter_ids loop
      perform public.notify_company_role(
        v_tid, array['admin', 'management'], 'New order assigned', v_party_msg,
        'order_assigned', 'transporter', 'high', v_meta, true);
    end loop;

    -- Buyer: your order was accepted and dispatched.
    perform public.notify_company_role(
      v_row.buyer_company_id, array['admin', 'management'], 'Order accepted & dispatched',
      'Your order for ' || v_cap_label || ' t of ' || coalesce(v_row.commodity, 'product')
        || ' was accepted. ' || coalesce(v_supplier_name, 'The mine')
        || ' is preparing your stockpile; you will be alerted each time a full load is ready.',
      'order_dispatched', 'buyer', 'high', v_meta, true);
  exception when others then
    null; -- never fail the dispatch because a notification/stockpile insert hiccuped
  end;

  return v_row;
end;
$function$;

-- 3. Capped add-tons RPC with +30t "ready to collect" alerts -----------------
create or replace function public.stockpile_add_tons(p_stockpile_id uuid, p_tons numeric)
 returns numeric
 language plpgsql
 security definer
 set search_path to 'public'
as $function$
declare
  v_sp public.stockpiles;
  v_old numeric;
  v_new numeric;
  v_load numeric := 30;         -- one full trailer load
  v_old_loads int;
  v_new_loads int;
  v_buyer_name text;
  v_supplier_name text;
  v_msg text;
  v_meta jsonb;
  v_rec record;
begin
  if p_tons is null or p_tons <= 0 then
    raise exception 'Enter a tonnage greater than zero';
  end if;

  select * into v_sp from public.stockpiles where id = p_stockpile_id for update;
  if v_sp.id is null then
    raise exception 'Stockpile not found';
  end if;
  if not public.is_company_stockpile_writer(v_sp.supplier_company_id) then
    raise exception 'You are not allowed to add to this stockpile';
  end if;

  v_old := coalesce(v_sp.balance_tons, 0);
  v_new := v_old + p_tons;

  if v_sp.max_cap_tons is not null and v_new > v_sp.max_cap_tons then
    raise exception 'Order cap is % t. Stockpile is at % t, so you can add at most % t more.',
      v_sp.max_cap_tons, v_old, greatest(v_sp.max_cap_tons - v_old, 0);
  end if;

  update public.stockpiles set balance_tons = v_new, updated_at = now()
    where id = p_stockpile_id;
  insert into public.stockpile_transactions (stockpile_id, type, delta_tons, balance_after, created_by)
    values (p_stockpile_id, 'addition', p_tons, v_new, auth.uid());

  -- Full-load threshold alerts to buyer + transporter(s).
  v_old_loads := floor(v_old / v_load)::int;
  v_new_loads := floor(v_new / v_load)::int;
  if v_new_loads > v_old_loads and v_sp.request_id is not null then
    select company_name into v_buyer_name    from public.companies where id = v_sp.buyer_company_id;
    select company_name into v_supplier_name from public.companies where id = v_sp.supplier_company_id;
    v_meta := jsonb_build_object(
      'stockpile_id', p_stockpile_id, 'request_id', v_sp.request_id,
      'balance_tons', v_new, 'loads_ready', v_new_loads);
    v_msg := v_new || ' t of ' || coalesce(v_sp.mineral, 'product')
      || ' is now on the stockpile at ' || coalesce(v_supplier_name, 'the mine')
      || ' - ' || v_new_loads || ' full load(s) ready to collect'
      || case when v_sp.max_cap_tons is not null
              then ' of ' || v_sp.max_cap_tons || ' t ordered' else '' end || '.';

    perform public.notify_company_role(
      v_sp.buyer_company_id, array['admin', 'management'], 'Stockpile ready to collect',
      v_msg, 'stockpile_ready', 'buyer', 'high', v_meta, true);

    for v_rec in
      select distinct transporter_company_id from public.request_dispatches
      where request_id = v_sp.request_id and transporter_company_id is not null
    loop
      perform public.notify_company_role(
        v_rec.transporter_company_id, array['admin', 'management'], 'Stockpile ready to collect',
        v_msg, 'stockpile_ready', 'transporter', 'high', v_meta, true);
    end loop;
  end if;

  return v_new;
end;
$function$;

grant execute on function public.stockpile_add_tons(uuid, numeric) to authenticated;

-- 4. RLS: no free creation; buyer + transporter can see the linked stockpile --
drop policy if exists stockpiles_insert_writers on public.stockpiles;
create policy stockpiles_insert_system_only on public.stockpiles
  for insert with check (false);  -- only the SECURITY DEFINER dispatch fn creates stockpiles

drop policy if exists stockpiles_select on public.stockpiles;
create policy stockpiles_select on public.stockpiles
  for select using (
    is_company_staff(supplier_company_id)
    or is_company_staff(buyer_company_id)
    or exists (
      select 1 from public.request_dispatches d
      where d.request_id = stockpiles.request_id
        and is_company_staff(d.transporter_company_id)
    )
  );

drop policy if exists stockpile_txn_select on public.stockpile_transactions;
create policy stockpile_txn_select on public.stockpile_transactions
  for select using (
    exists (
      select 1 from public.stockpiles s
      where s.id = stockpile_transactions.stockpile_id
        and (
          is_company_staff(s.supplier_company_id)
          or is_company_staff(s.buyer_company_id)
          or exists (
            select 1 from public.request_dispatches d
            where d.request_id = s.request_id and is_company_staff(d.transporter_company_id)
          )
        )
    )
  );
