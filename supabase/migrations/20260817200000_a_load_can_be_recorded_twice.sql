-- The weighbridge could record the same load twice.
--
-- `record_truck_load` had no idempotency guard of any kind. Driven and measured
-- on a real trip, 2026-08-17:
--
--     first call   40.0 -> 6.3   (-33.7 t, 4 seal records)
--     second call   6.3 -> 0.0   (-6.3 t, another seal record)
--
-- for ONE physical load. The second call also re-stamped `loaded_at`, rebuilt
-- the waybill and ran the reconciliation roll-up again, so `loaded_tons` was
-- double-counted too.
--
-- A load controller double-tapping "Confirm load & deduct from stockpile" on a
-- slow connection is all it takes. And it is unrecoverable: `seal_records` and
-- `stockpile_transactions` both have no DELETE policy -- correct for evidence,
-- fatal for a duplicate -- so nothing can clean up afterwards. (Verified: a
-- delete against `seal_records` removes zero rows even through the management
-- API.)
--
-- The lifecycle is already forward-only for `set_trip_status` (20260817130000).
-- This closes the same door on the cascade that actually writes the tonnage.

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

  -- A LOAD IS RECORDED ONCE.
  --
  -- Nothing stopped this function running twice for the same trip. Measured on
  -- a real trip 2026-08-17: the first call deducted 33.7 t (40 -> 6.3), a
  -- second identical call inserted the seal records again, wrote a SECOND
  -- deduction, and took the remaining 6.3 t to zero -- for one physical load.
  -- It also re-stamped `loaded_at` and rebuilt the waybill, and ran the
  -- reconciliation roll-up again, double-counting `loaded_tons`.
  --
  -- One impatient second tap on "Confirm load" is all that takes, and it cannot
  -- be undone: neither `seal_records` nor `stockpile_transactions` has a DELETE
  -- policy -- correctly, they are evidence -- so the duplicate rows are
  -- permanent.
  if v_trip.status in ('loaded', 'left_mine', 'en_route_to_offload',
                       'offloaded', 'completed') then
    raise exception
      'This load has already been recorded for %. A load is captured once; '
      'raise a dispute if the tonnage is wrong.',
      coalesce(p_truck_reg, v_trip.metadata->>'truck_reg', 'this truck')
      using errcode = 'unique_violation';
  end if;
  if v_trip.status = 'cancelled' then
    raise exception 'This trip was cancelled - it cannot be loaded';
  end if;


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

  if v_remaining > 0 then
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
        and (
              -- THE ORDER'S OWN PILE NEEDS NO BUYER TO IDENTIFY IT. This trip's
              -- request/route names exactly one stockpile, which is why `ord`
              -- ranks it first. Requiring a buyer match here as well is what
              -- made a no-buyer haul draw from nothing at all.
              (v_request_id is not null and s.request_id = v_request_id)
           or (v_route_id   is not null and s.route_id   = v_route_id)
              -- The legacy (supplier, buyer) pool genuinely does need a buyer
              -- to scope by, so it stays behind one.
           or (v_txn.buyer_company_id is not null
               and (s.buyer_company_id = v_txn.buyer_company_id
                    or (s.buyer_company_id is null and v_buyer_name is not null
                        and lower(trim(s.buyer_label)) = lower(trim(v_buyer_name)))))
            )
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
  'Weighbridge load, recorded ONCE per trip. Draws from the order''s own '
  'stockpile first (request_id, then route_id, then the supplier/buyer pool), '
  'healing request_id/route_id onto any unlinked pile it uses in the same '
  'UPDATE as the decrement. The order''s own pile is identified by the trip''s '
  'request/route and needs no buyer (20260817190000). Refuses a trip already '
  'at or past `loaded`: a second call used to deduct the stockpile again and '
  'duplicate the seal records, which no DELETE policy can undo (20260817200000).';
