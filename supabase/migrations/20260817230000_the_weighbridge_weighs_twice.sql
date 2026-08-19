-- A truck is weighed empty, then loaded, then weighed again.
--
-- Jean, 2026-08-17, asked for the real sequence to be the recorded one: first
-- weigh -> the truck loads at the stockpile -> second weigh. Until now the app
-- captured tare AND gross on ONE sheet, submitted once, so nothing forced two
-- visits to the weighbridge and nothing recorded that they happened. A tare
-- typed at the same moment as the gross is not a measurement, it is an
-- assertion, and the difference between them is the number the whole product
-- bills on.
--
-- Three changes, all in this file so the flow cannot be half-migrated:
--
--   1. `trips.tare_tons` and `trips.gross_tons` -- both weighs are kept, not
--      just their difference. `net_tons` stays exactly as it was (the cargo),
--      because every downstream reader bills on it.
--   2. `record_truck_tare` -- the arrival weigh. Stamps `loading_at`, moves the
--      trip `arrived_at_mine -> loading`, and keeps the scale photo. That
--      status transition is the one CLAUDE.md 4 has always described and which
--      nothing has ever performed.
--   3. `record_truck_load` now takes the GROSS weight and derives the net
--      itself from the stored tare. The arithmetic moves to the server, where
--      the two readings are, instead of being a number the client posts.
--
-- `list_mine_inbound_trips` returns the tare, the gross and the tare time so the
-- Load Controller's sheet can show what was already measured and when.

alter table public.trips
  add column if not exists tare_tons numeric,
  add column if not exists gross_tons numeric;

comment on column public.trips.tare_tons is
  'First weigh: the empty truck and trailer, captured on arrival by the Load '
  'Controller (record_truck_tare) BEFORE loading. Kept, not just differenced, '
  'so the two readings that produced net_tons can both be audited.';
comment on column public.trips.gross_tons is
  'Second weigh: truck plus cargo, captured after loading (record_truck_load). '
  'net_tons = gross_tons - tare_tons, computed server-side.';
comment on column public.trips.loading_at is
  'When the empty (tare) weigh was taken and the truck went to load. Set by '
  'record_truck_tare; the gap to loaded_at is how long the truck spent under '
  'the shovel.';

-- 1 ---------------------------------------------------------------------------
-- The arrival weigh.

create or replace function public.record_truck_tare(
  p_trip_id uuid,
  p_tare_tons numeric,
  p_tare_photo_path text default null
)
returns public.trips
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_trip public.trips;
  v_txn public.transactions;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then raise exception 'Trip % not found', p_trip_id; end if;
  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  if not public.is_company_staff(v_txn.supplier_company_id) then
    raise exception 'Only the mine''s staff can weigh a truck';
  end if;
  if not public.is_company_active(v_txn.supplier_company_id)
     and not public.is_trip_in_flight(p_trip_id) then
    raise exception
      'TOKEN_EXPIRED: your MineLink token is not active, so this weigh cannot '
      'be recorded. Trips already under way can still be completed.'
      using errcode = 'check_violation';
  end if;

  if p_tare_tons is null or p_tare_tons <= 0 then
    raise exception 'Enter the empty (tare) weight in tons';
  end if;

  -- Re-weighing before the load is recorded is legitimate (a bad reading, a
  -- driver who moved off the plate). Re-weighing after it is not.
  if v_trip.status in ('loaded', 'left_mine', 'en_route_to_offload',
                       'offloaded', 'completed') then
    raise exception
      'This load has already been recorded — the tare weight is fixed now.'
      using errcode = 'unique_violation';
  end if;
  if v_trip.status = 'cancelled' then
    raise exception 'This trip was cancelled - it cannot be weighed';
  end if;
  if v_trip.status not in ('arrived_at_mine', 'loading') then
    raise exception
      'This truck has not been checked in at the gate yet, so it cannot be '
      'weighed.';
  end if;

  update public.trips set
    tare_tons = p_tare_tons,
    loading_at = coalesce(loading_at, timezone('utc', now())),
    status = 'loading',
    metadata = coalesce(metadata, '{}'::jsonb)
      || case when nullif(btrim(coalesce(p_tare_photo_path, '')), '') is null
              then '{}'::jsonb
              else jsonb_build_object('tare_photo_path', p_tare_photo_path) end
  where id = p_trip_id
  returning * into v_trip;

  return v_trip;
end;
$function$;

comment on function public.record_truck_tare(uuid, numeric, text) is
  'First weigh: the empty truck on arrival. Moves the trip arrived_at_mine -> '
  'loading and stamps loading_at, so the two weighs are separately timed and '
  'separately evidenced. Added 2026-08-17 (Jean): both weights used to be typed '
  'on one sheet at one moment, which cannot show that two weighs happened.';

revoke all on function public.record_truck_tare(uuid, numeric, text) from public, anon;
grant execute on function public.record_truck_tare(uuid, numeric, text) to authenticated;

-- 2 ---------------------------------------------------------------------------
-- The second weigh. Takes GROSS; the server derives the net from the tare it
-- already holds. Parameter rename requires drop + recreate.

drop function if exists public.record_truck_load(uuid, numeric, text, jsonb, jsonb);

create function public.record_truck_load(
  p_trip_id uuid,
  p_gross_tons numeric,
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
  v_net numeric;
  v_seal_required boolean := false; v_seal_count int := 0;
  v_remaining numeric; v_take numeric; v_sp record;
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

  -- A LOAD IS RECORDED ONCE, AND ONLY AFTER THE EMPTY WEIGH.
  --
  -- Nothing stopped this running twice for the same trip. Measured 2026-08-17:
  -- the first call deducted 33.7 t (40 -> 6.3), a second identical call
  -- inserted the seal records again, wrote a SECOND deduction, and took the
  -- remaining 6.3 t to zero -- for one physical load. Unrecoverable: neither
  -- `seal_records` nor `stockpile_transactions` has a DELETE policy.
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
  if v_trip.status = 'arrived_at_mine' or v_trip.tare_tons is null then
    raise exception
      'Weigh the empty truck first. The truck is weighed empty on arrival, '
      'loaded, and then weighed again - the difference is the load.';
  end if;
  if v_trip.status <> 'loading' then
    raise exception
      'This truck has not been checked in at the gate yet, so it cannot be '
      'loaded.';
  end if;

  -- The net is DERIVED here, from the two weights the server holds. It used to
  -- arrive as a number the client had worked out.
  if p_gross_tons is null or p_gross_tons <= 0 then
    raise exception 'Enter the loaded (gross) weight in tons';
  end if;
  if p_gross_tons <= v_trip.tare_tons then
    raise exception
      'The loaded weight (% t) must be more than the empty weight (% t).',
      p_gross_tons, v_trip.tare_tons;
  end if;
  v_net := p_gross_tons - v_trip.tare_tons;
  v_remaining := v_net;

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
  -- The tare photo was captured at the FIRST weigh, so it comes off the trip
  -- rather than out of this call's payload.
  v_wb := coalesce(p_waybill, '{}'::jsonb) || jsonb_build_object(
    'waybill_number', v_txn.reference_number,
    'dispatched_by', v_actor_name,
    'dispatch_signature_path', v_actor_sig)
    || case when v_trip.metadata->>'tare_photo_path' is null then '{}'::jsonb
            else jsonb_build_object('tare_photo_path', v_trip.metadata->>'tare_photo_path') end;
  update public.trips set status = 'loaded', loaded_at = timezone('utc', now()),
    gross_tons = p_gross_tons, net_tons = v_net,
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object('truck_reg', p_truck_reg, 'waybill', v_wb)
  where id = p_trip_id returning * into v_trip;
  update public.transactions set status = 'in_transit'
  where id = v_trip.transaction_id and status in ('draft','scheduled');
  begin
    perform public.notify_company_role(
      v_txn.supplier_company_id, array['security'], 'Load complete',
      'Truck ' || coalesce(p_truck_reg, v_trip.metadata->>'truck_reg', 'at the weighbridge')
        || ' is loaded (' || coalesce(round(v_net, 2)::text, '?') || ' t) — ready for gate check-out.',
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
              -- THE ORDER'S OWN PILE NEEDS NO BUYER TO IDENTIFY IT.
              (v_request_id is not null and s.request_id = v_request_id)
           or (v_route_id   is not null and s.route_id   = v_route_id)
           or (v_txn.buyer_company_id is not null
               and (s.buyer_company_id = v_txn.buyer_company_id
                    or (s.buyer_company_id is null and v_buyer_name is not null
                        and lower(trim(s.buyer_label)) = lower(trim(v_buyer_name)))))
            )
      order by ord, s.created_at
    loop
      exit when v_remaining <= 0;
      v_take := least(v_remaining, v_sp.balance_tons);

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
       'draft', jsonb_build_object('loaded_tons', v_net, 'loads', 1)) returning id into v_recon_id;
  else
    update public.reconciliations set metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
        'loaded_tons', coalesce((metadata->>'loaded_tons')::numeric,0) + coalesce(v_net,0),
        'loads', coalesce((metadata->>'loads')::int,0) + 1) where id = v_recon_id;
  end if;
  return v_trip;
end;
$function$;

comment on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) is
  'Second weigh. Takes the GROSS weight and derives net_tons from the tare '
  'record_truck_tare already stored, so the arithmetic lives with the two '
  'readings instead of arriving from the client. Recorded ONCE per trip and '
  'only from `loading` (20260817200000, 20260817230000). Draws from the '
  'order''s own stockpile first, which needs no buyer to identify it '
  '(20260817190000).';

revoke all on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) from public, anon;
grant execute on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) to authenticated;

-- 3 ---------------------------------------------------------------------------
-- The queue carries both weighs, so the sheet can show what is already done.

drop function if exists public.list_mine_inbound_trips(uuid);

create function public.list_mine_inbound_trips(p_supplier_company_id uuid)
 returns table(trip_id uuid, status text, vehicle_id uuid, truck_reg text, route_id uuid,
               seal_required boolean, net_tons numeric, tare_tons numeric, gross_tons numeric,
               loading_at timestamp with time zone,
               transaction_id uuid, buyer_company_id uuid, buyer_name text, transporter_name text,
               commodity text, reference text, offloading_point text, loading_point text,
               updated_at timestamp with time zone)
 language sql
 security definer
 set search_path to 'public'
as $function$
  select
    t.id, t.status, t.vehicle_id,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    t.route_id, coalesce(rt.seal_required, false), t.net_tons,
    t.tare_tons, t.gross_tons, t.loading_at,
    tx.id,
    tx.buyer_company_id, bc.company_name, tc.company_name,
    coalesce(nullif(tx.metadata->>'commodity', ''), m.name),
    tx.reference_number,
    coalesce(rt.offloading_point, tx.metadata->>'offloading_point'),
    coalesce(rt.loading_point, tx.metadata->>'loading_point', sc.company_name),
    t.updated_at
  from public.trips t
  join public.transactions tx on tx.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.routes rt on rt.id = t.route_id
  left join public.companies bc on bc.id = tx.buyer_company_id
  left join public.companies tc on tc.id = tx.transporter_company_id
  left join public.companies sc on sc.id = tx.supplier_company_id
  left join public.minerals m on m.id = tx.mineral_id
  where tx.supplier_company_id = p_supplier_company_id
    and public.is_company_staff(p_supplier_company_id)
    and (
      t.status not in ('completed', 'cancelled')
      or t.updated_at > timezone('utc', now()) - interval '2 days'
    )
  order by t.updated_at desc
  limit 200;
$function$;

revoke execute on function public.list_mine_inbound_trips(uuid) from public, anon;
grant execute on function public.list_mine_inbound_trips(uuid) to authenticated;
