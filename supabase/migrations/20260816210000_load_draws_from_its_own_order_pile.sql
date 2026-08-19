-- A load takes ore from the order it belongs to, not from whichever pile is
-- oldest.
--
-- ============================================================================
-- THE RULING
-- ============================================================================
-- Client, 2026-08-16:
--
--   "it should fully and properly match all accross and make sense logically
--    so obviously the available tons also gets decreased accordingly. so all
--    must just work properly and accordingly accross everything everywhere
--    where relevant and where related"
--
-- ============================================================================
-- WHAT IT DID BEFORE
-- ============================================================================
-- `record_truck_load` decremented the stockpile pool like this:
--
--     for v_sp in select * from public.stockpiles
--       where supplier_company_id = <mine> and balance_tons > 0
--         and (buyer_company_id = <buyer> or <buyer_label name match>)
--       order by created_at            <-- FIFO across EVERY pile for that pair
--
-- It never looked at which ORDER the trip belonged to. `stockpiles` carries
-- `request_id`, `route_id`, `transporter_company_id` and `max_cap_tons` —
-- minted per order by `link_and_dispatch_request` (20260715090000) — and the
-- loop used none of them.
--
-- So a truck collecting for order B, arriving while order A's pile was older,
-- drew A's tonnage down instead. Every downstream number then disagreed with
-- the physical world: A's "ready to collect" fill fell without a truck, B's
-- stayed full after one left loaded, the +30 t collect-ready alert fired
-- against the wrong order, and `max_cap_tons` — the ordered tonnage — stopped
-- meaning anything, because the pile being drained was not the pile being
-- filled for that order.
--
-- ============================================================================
-- THE ORDER OF PREFERENCE, AND WHY THERE IS A FALLBACK AT ALL
-- ============================================================================
--   1. the order's own pile      — stockpiles.request_id = this trip's request
--   2. the route's pile          — stockpiles.route_id  = this trip's route
--   3. the (supplier, buyer) pool — as before, oldest first
--
-- Step 3 is kept deliberately. Three of the piles on production today predate
-- the order-linked model and carry `request_id = null`; removing the fallback
-- would mean a load against one of those could not be recorded at all, which
-- turns a reporting fault into a truck that cannot leave a weighbridge. A
-- wrong number is recoverable; a blocked weighbridge is not.
--
-- **But the fallback heals as it goes.** When a load falls through to step 3
-- it stamps `request_id` / `route_id` onto the pile it used, in the same
-- UPDATE that moves the balance. The pile becomes an order pile, step 1 finds
-- it next time, and the population of unlinked piles shrinks to zero on its
-- own. This mirrors the `buyer_company_id` healing that was already here.
--
-- Stamping in the SAME statement as the decrement is load-bearing, not tidy:
-- `guard_company_active()` reads NEW, so the row it judges already carries the
-- `request_id` that lets an expired mine finish an in-flight load
-- (20260816200000). Split into two UPDATEs, the first would be judged with
-- `request_id` still null and refused.
--
-- ============================================================================
-- HOW THIS WAS FOUND
-- ============================================================================
-- Not by reading. The green walk for 20260816200000 refused a load from an
-- expired mine on an in-flight trip, and the reason was that the FIFO loop had
-- selected a legacy pile with no `request_id`, which the new guard could not
-- resolve to a trip. Ruling 1 and ruling 3 are the same defect approached from
-- two sides: the pool was never the order's, and nothing downstream could tell.
-- ============================================================================

create or replace function public.record_truck_load(
  p_trip_id uuid,
  p_net_tons numeric,
  p_truck_reg text default null::text,
  p_seals jsonb default '[]'::jsonb,
  p_waybill jsonb default '{}'::jsonb
)
returns trips
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_trip public.trips; v_txn public.transactions;
  v_seal_required boolean := false; v_seal_count int := 0;
  v_remaining numeric := coalesce(p_net_tons, 0); v_take numeric; v_sp record;
  v_recon_id uuid; v_pool_balance numeric; v_pool_exists boolean := false;
  v_deducted boolean := false; v_actor_name text; v_actor_sig text; v_wb jsonb;
  v_buyer_name text;
  v_request_id uuid; v_route_id uuid;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then raise exception 'Trip % not found', p_trip_id; end if;
  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  -- Being the mine's staff is never waived (20260816200000).
  if not public.is_company_staff(v_txn.supplier_company_id) then
    raise exception 'Only the mine''s staff can record a load';
  end if;
  -- An expired token is waived only for a truck already on this trip.
  if not public.is_company_active(v_txn.supplier_company_id)
     and not public.is_trip_in_flight(p_trip_id) then
    raise exception
      'TOKEN_EXPIRED: your MineLink token is not active, so this load cannot '
      'be recorded. Trips already under way can still be completed.'
      using errcode = 'check_violation';
  end if;

  v_buyer_name := (select company_name from public.companies where id = v_txn.buyer_company_id);

  -- Which ORDER is this truck collecting for? Dispatch first (the trip is
  -- created by link_and_dispatch_request and carries dispatch_id), then the
  -- route, then the transaction's own dispatch.
  v_route_id := v_trip.route_id;
  select coalesce(
           (select rd.request_id from public.request_dispatches rd where rd.id = v_trip.dispatch_id),
           (select r.request_id  from public.routes r            where r.id  = v_trip.route_id),
           (select rd.request_id from public.request_dispatches rd where rd.id = v_txn.dispatch_id)
         )
    into v_request_id;

  if v_trip.route_id is not null then
    select coalesce(seal_required, false) into v_seal_required
    from public.routes where id = v_trip.route_id;
  end if;
  v_seal_count := coalesce(jsonb_array_length(p_seals), 0);
  if v_seal_required and v_seal_count = 0 then
    raise exception 'This route requires seals: capture each seal number and photo before saving';
  end if;
  if v_seal_required then
    if exists (select 1 from jsonb_array_elements(p_seals) e
      where coalesce(e->>'number','') = '' or coalesce(e->>'photo_url','') = '') then
      raise exception 'Each seal needs both a number and a photo on a seal-required route';
    end if;
  end if;
  insert into public.seal_records (trip_id, transaction_id, seal_number, photo_url, captured_by)
  select p_trip_id, v_trip.transaction_id, e->>'number', e->>'photo_url', auth.uid()
  from jsonb_array_elements(p_seals) e where coalesce(e->>'number','') <> '';
  v_actor_name := coalesce((select display_name from public.profiles where id = auth.uid()), 'Load Controller');
  v_actor_sig := (select signature_url from public.profiles where id = auth.uid());
  v_wb := coalesce(p_waybill, '{}'::jsonb) || jsonb_build_object(
    'waybill_number', v_txn.reference_number,
    'dispatched_by', v_actor_name,
    'dispatch_signature_path', v_actor_sig);
  update public.trips set status = 'loaded', loaded_at = timezone('utc', now()), net_tons = p_net_tons,
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('truck_reg', p_truck_reg, 'waybill', v_wb)
  where id = p_trip_id returning * into v_trip;
  update public.transactions set status = 'in_transit'
  where id = v_trip.transaction_id and status in ('draft','scheduled');
  begin
    perform public.notify_company_role(
      v_txn.supplier_company_id, array['security'], 'Load complete',
      'Truck ' || coalesce(p_truck_reg, v_trip.metadata->>'truck_reg', 'at the weighbridge')
        || ' is loaded (' || coalesce(round(p_net_tons, 2)::text, '?') || ' t) — ready for gate check-out.',
      'truck_loaded', 'mineSupplier', 'normal',
      jsonb_build_object('trip_id', v_trip.id, 'transaction_id', v_trip.transaction_id));
  exception when others then null; end;

  if v_txn.buyer_company_id is not null and v_remaining > 0 then
    -- ORDER FIRST. `ord` ranks the order's own pile ahead of the route's pile
    -- ahead of the rest of the (supplier, buyer) pool; `created_at` keeps the
    -- old FIFO order within each band, so behaviour is unchanged for a mine
    -- that has only ever had one pile per buyer.
    for v_sp in
      select s.*,
             case
               when v_request_id is not null and s.request_id = v_request_id then 0
               when v_route_id   is not null and s.route_id   = v_route_id   then 1
               else 2
             end as ord
      from public.stockpiles s
      where s.supplier_company_id = v_txn.supplier_company_id
        and s.balance_tons > 0
        and (s.buyer_company_id = v_txn.buyer_company_id
             or (s.buyer_company_id is null and v_buyer_name is not null
                 and lower(trim(s.buyer_label)) = lower(trim(v_buyer_name))))
      order by ord, s.created_at
    loop
      exit when v_remaining <= 0;
      v_take := least(v_remaining, v_sp.balance_tons);

      -- One statement: move the balance and heal the links. Two statements
      -- would present the guard a row that still has request_id = null.
      update public.stockpiles
         set balance_tons = balance_tons - v_take,
             buyer_company_id = coalesce(buyer_company_id, v_txn.buyer_company_id),
             request_id = coalesce(request_id, v_request_id),
             route_id   = coalesce(route_id,   v_route_id),
             transporter_company_id =
               coalesce(transporter_company_id, v_txn.transporter_company_id),
             updated_at = timezone('utc', now())
       where id = v_sp.id;

      insert into public.stockpile_transactions (stockpile_id, type, delta_tons, balance_after, truck_reg, trip_id, created_by)
      values (v_sp.id, 'deduction', -v_take, v_sp.balance_tons - v_take, p_truck_reg, p_trip_id, auth.uid());
      v_remaining := v_remaining - v_take; v_deducted := true;
    end loop;

    if v_deducted then
      begin
        -- Depletion is judged on the ORDER's pile when the trip has one, so
        -- "this transaction cycle is complete" means this order is finished
        -- rather than every pile the mine happens to hold for that buyer.
        if v_request_id is not null
           and exists (select 1 from public.stockpiles where request_id = v_request_id) then
          select true, coalesce(sum(balance_tons), 0)
            into v_pool_exists, v_pool_balance
          from public.stockpiles where request_id = v_request_id;
        else
          select exists(select 1 from public.stockpiles
                   where supplier_company_id = v_txn.supplier_company_id and buyer_company_id = v_txn.buyer_company_id),
                 coalesce((select sum(balance_tons) from public.stockpiles
                   where supplier_company_id = v_txn.supplier_company_id and buyer_company_id = v_txn.buyer_company_id), 0)
            into v_pool_exists, v_pool_balance;
        end if;
        if v_pool_exists and v_pool_balance <= 0
           and (v_txn.metadata is null or v_txn.metadata->>'stockpile_depleted_at' is null) then
          update public.transactions set metadata = coalesce(metadata, '{}'::jsonb)
              || jsonb_build_object('stockpile_depleted_at', timezone('utc', now())) where id = v_txn.id;
          perform public.notify_company_role(
            v_txn.supplier_company_id, array['supervisorForeman', 'admin', 'management'],
            'Stockpile reached 0 tons',
            'The stockpile for ' || coalesce(v_buyer_name, 'the buyer')
              || ' has been fully loaded out (0 tons remaining). This transaction cycle is complete.',
            'stockpile_depleted', 'mineSupplier', 'high',
            jsonb_build_object('trip_id', v_trip.id, 'transaction_id', v_txn.id), true);
        end if;
      exception when others then null; end;
    end if;
  end if;

  select id into v_recon_id from public.reconciliations
  where supplier_company_id = v_txn.supplier_company_id
    and buyer_company_id is not distinct from v_txn.buyer_company_id
    and transporter_company_id is not distinct from v_txn.transporter_company_id and status = 'draft' limit 1;
  if v_recon_id is null then
    insert into public.reconciliations (buyer_company_id, supplier_company_id, transporter_company_id, status, metadata)
    values (v_txn.buyer_company_id, v_txn.supplier_company_id, v_txn.transporter_company_id,
       'draft', jsonb_build_object('loaded_tons', p_net_tons, 'loads', 1)) returning id into v_recon_id;
  else
    update public.reconciliations set metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
        'loaded_tons', coalesce((metadata->>'loaded_tons')::numeric,0) + coalesce(p_net_tons,0),
        'loads', coalesce((metadata->>'loads')::int,0) + 1) where id = v_recon_id;
  end if;
  return v_trip;
end;
$function$;

comment on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) is
  'Weighbridge load. Draws from the order''s own stockpile first (request_id, '
  'then route_id, then the supplier/buyer pool), healing request_id/route_id '
  'onto any unlinked pile it uses in the same UPDATE as the decrement. See '
  '20260816210000.';
