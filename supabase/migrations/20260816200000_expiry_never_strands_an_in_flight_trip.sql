-- Expiry must never strand a truck that is already on the road.
--
-- ============================================================================
-- THE RULING
-- ============================================================================
-- Client, 2026-08-16, asked directly:
--
--   "no, all trucks that's busy should be able to and needs to be able to
--    complete their full trip from collection all the way up to dropoff
--    please. this needs to be fully and properly done, all users and or
--    companies related to this trip still needs to be able to fully and
--    properly track and see everything for this trip."
--
-- Before this migration the opposite was true. `guard_company_active()` is on
-- twenty operational tables and refuses EVERY write from a company whose token
-- has expired, with no exception for work already under way. And
-- `record_truck_load` gated on `is_company_staff_active`, so the single most
-- time-critical action in the product — a loaded truck standing on a
-- weighbridge — failed outright the moment the mine's token lapsed.
--
-- The physical consequence is the point: a sealed truck at a mine gate cannot
-- be un-loaded by a billing state. Someone would have had to move ore without
-- a waybill, which is the exact failure the waybill exists to prevent.
--
-- ============================================================================
-- WHAT "IN FLIGHT" MEANS, AND WHY `scheduled` IS INCLUDED
-- ============================================================================
-- A `scheduled` trip counts as in flight. It reads like "not started yet", but
-- it is an EXISTING COMMITMENT: it only exists because the super-admin linked
-- and dispatched the request while the company was active, and the truck and
-- driver are allocated to it and unavailable for anything else. Excluding it
-- would strand precisely the trips dispatched just before expiry — the ones
-- most likely to be mid-arrangement — which is the stranding this forbids.
--
-- The line this migration actually draws is not started/not-started. It is:
--
--     existing commitments complete · new commitments cannot be created
--
-- which is why INSERTs on `trips` and `transactions` stay refused (see below).
--
-- A completed trip stays in flight for 24 hours. `record_pod` sets
-- `status = 'completed'` and then writes the POD row, the reconciliation and
-- the waybill; without the grace window the trip would stop being in flight
-- half-way through its own completion and the paperwork would be refused.
--
-- ============================================================================
-- THE HOLE THIS DELIBERATELY DOES NOT OPEN
-- ============================================================================
-- The guard resolves the trip FROM THE ROW BEING WRITTEN — not from a session
-- variable. A GUC (`set_config('app.in_flight', ...)`) was considered and
-- rejected: the whole guard would then rest on a value the caller's own
-- transaction sets, and "expired" would become advisory.
--
-- **INSERT on `trips` and `transactions` is still refused.** Those two rows
-- resolve to themselves, so an expired company could otherwise insert a fresh
-- `scheduled` trip, have it vouch for its own in-flight status, and carry on
-- trading. Only UPDATE/DELETE of an already-existing in-flight row is allowed.
-- Their child tables are the opposite case — a POD, a seal, a gate check is
-- exactly the operational record an in-flight trip must be able to write — so
-- INSERT is allowed there.
--
-- Every path additionally requires `is_trip_party()`, so an expired company
-- can only write to trips it is actually on.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. Is this trip still running?
-- ---------------------------------------------------------------------------
create or replace function public.is_trip_in_flight(p_trip_id uuid)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select exists (
    select 1
    from public.trips t
    where t.id = p_trip_id
      and t.status <> 'cancelled'
      and (
        t.status <> 'completed'
        -- The paperwork window. `completed_at` is null on legacy rows that
        -- were completed before the column existed; treat those as closed
        -- rather than permanently in flight.
        or (t.completed_at is not null
            and t.completed_at > now() - interval '24 hours')
      )
  );
$function$;

comment on function public.is_trip_in_flight(uuid) is
  'A trip that is an existing commitment and not yet finished: anything but '
  'cancelled, and completed only within a 24h paperwork window. Includes '
  'scheduled — see 20260816200000. Used by guard_company_active() so an '
  'expired company can finish work already under way but cannot start new.';

-- ---------------------------------------------------------------------------
-- 2. Which trip does this row belong to?
-- ---------------------------------------------------------------------------
-- Returns the id of an in-flight trip that this write belongs to AND that the
-- caller is a party to, or null. Null means "refuse".
--
-- Takes the row as jsonb so one function serves all twenty tables; the trigger
-- has no other way to hand over a record of varying type.
create or replace function public.in_flight_trip_for_write(
  p_table text,
  p_op text,
  p_row jsonb
)
returns uuid
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  v_trip uuid;
begin
  case p_table

    -- Resolve to themselves. INSERT refused: a new row must not be allowed to
    -- vouch for its own in-flight status (see the header).
    when 'trips' then
      if p_op = 'INSERT' then return null; end if;
      v_trip := nullif(p_row->>'id', '')::uuid;

    when 'transactions' then
      if p_op = 'INSERT' then return null; end if;
      select t.id into v_trip
      from public.trips t
      where t.transaction_id = nullif(p_row->>'id', '')::uuid
        and public.is_trip_in_flight(t.id)
      limit 1;

    -- Carry the trip directly.
    when 'pod_uploads', 'seal_records', 'security_confirmations',
         'vehicle_positions', 'stockpile_transactions' then
      v_trip := nullif(p_row->>'trip_id', '')::uuid;

    -- Carry the transaction; find an in-flight trip on it.
    when 'weighbridge_records', 'mineral_loads' then
      select t.id into v_trip
      from public.trips t
      where t.transaction_id = nullif(p_row->>'transaction_id', '')::uuid
        and public.is_trip_in_flight(t.id)
      limit 1;

    -- Carry the vehicle; find the in-flight trip that vehicle is on.
    when 'gate_checks' then
      select t.id into v_trip
      from public.trips t
      where t.vehicle_id = nullif(p_row->>'vehicle_id', '')::uuid
        and public.is_trip_in_flight(t.id)
      limit 1;

    -- The order's stockpile. `record_truck_load` decrements it as part of the
    -- load, so an expired mine must be able to write it — but only the pile
    -- belonging to an order that actually has a truck out.
    when 'stockpiles' then
      select t.id into v_trip
      from public.trips t
      left join public.request_dispatches rd on rd.id = t.dispatch_id
      left join public.routes r on r.id = t.route_id
      where public.is_trip_in_flight(t.id)
        and (
          (nullif(p_row->>'request_id', '') is not null
            and coalesce(rd.request_id, r.request_id)
                = (p_row->>'request_id')::uuid)
          or (nullif(p_row->>'route_id', '') is not null
            and t.route_id = (p_row->>'route_id')::uuid)
        )
      limit 1;

    -- Recon rows carry no trip, only the party triple. Match a trip on the
    -- same three companies.
    when 'reconciliations' then
      select t.id into v_trip
      from public.trips t
      join public.transactions x on x.id = t.transaction_id
      where public.is_trip_in_flight(t.id)
        and x.supplier_company_id
            is not distinct from nullif(p_row->>'supplier_company_id','')::uuid
        and x.buyer_company_id
            is not distinct from nullif(p_row->>'buyer_company_id','')::uuid
        and x.transporter_company_id
            is not distinct from nullif(p_row->>'transporter_company_id','')::uuid
      limit 1;

    -- Everything else the guard covers — company_locations, minerals,
    -- haul_routes, transportation_requests, request_dispatches,
    -- production_entries, load_invoices, mine_locations — is standing data or
    -- new work, not the execution of a trip already under way. No exception.
    else
      return null;

  end case;

  if v_trip is null then return null; end if;
  if not public.is_trip_in_flight(v_trip) then return null; end if;
  -- The caller must actually be on this trip. `is_trip_party` uses
  -- `is_company_staff` (not `_active`), which is what makes it usable here.
  if not public.is_trip_party(v_trip) then return null; end if;

  return v_trip;
end;
$function$;

comment on function public.in_flight_trip_for_write(text, text, jsonb) is
  'Resolves the write to an in-flight trip the caller is a party to, or null. '
  'Trip is resolved from the ROW, never from a session variable, so the guard '
  'cannot be talked out of by the transaction it is guarding.';

-- ---------------------------------------------------------------------------
-- 3. The guard itself
-- ---------------------------------------------------------------------------
create or replace function public.guard_company_active()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_company uuid;
begin
  -- System context: pg_cron jobs and migrations run with no JWT. They must
  -- never be blocked — expire_organizations() itself writes through here.
  if auth.uid() is null then
    return new;
  end if;

  -- Platform admins are never restricted (company-mirror observer mode).
  if public.is_platform_admin() then
    return new;
  end if;

  v_company := public.current_company_id();

  -- No company context at all: not this guard's business.
  if v_company is null then
    return new;
  end if;

  if public.is_company_active(v_company) then
    return new;
  end if;

  -- Expired — but a truck already on the road must still reach the offload
  -- point. See 20260816200000 for the ruling and the boundary.
  if public.in_flight_trip_for_write(tg_table_name, tg_op, to_jsonb(new))
       is not null then
    return new;
  end if;

  -- Message is deliberately specific and actionable — it reaches the user
  -- through friendlyError(), and "permission denied" would tell them nothing.
  raise exception
    'TOKEN_EXPIRED: your MineLink token is not active, so this change cannot '
    'be saved. Trips already under way can still be completed. You can also '
    'view records, message MineLink, request a renewal and log a support '
    'ticket.'
    using errcode = 'check_violation';
end;
$function$;

-- ---------------------------------------------------------------------------
-- 4. The weighbridge, which had its own gate on top of the trigger
-- ---------------------------------------------------------------------------
-- `record_truck_load` checked `is_company_staff_active(supplier)`, so it
-- refused before the trigger was ever reached. Split into the two questions it
-- was conflating: *are you the mine's staff* (always required) and *is your
-- token active* (waived for a trip already under way).
--
-- Only the four lines of the gate change; the body is otherwise the function
-- as it stood at 20260816200000, and ruling 3 rewrites the stockpile loop in
-- the migration immediately after this one.
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
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then raise exception 'Trip % not found', p_trip_id; end if;
  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  -- Being the mine's staff is never waived.
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
    for v_sp in select * from public.stockpiles
      where supplier_company_id = v_txn.supplier_company_id and balance_tons > 0
        and (buyer_company_id = v_txn.buyer_company_id
             or (buyer_company_id is null and v_buyer_name is not null
                 and lower(trim(buyer_label)) = lower(trim(v_buyer_name))))
      order by created_at
    loop
      exit when v_remaining <= 0;
      if v_sp.buyer_company_id is null then
        update public.stockpiles set buyer_company_id = v_txn.buyer_company_id where id = v_sp.id;
      end if;
      v_take := least(v_remaining, v_sp.balance_tons);
      update public.stockpiles set balance_tons = balance_tons - v_take where id = v_sp.id;
      insert into public.stockpile_transactions (stockpile_id, type, delta_tons, balance_after, truck_reg, trip_id, created_by)
      values (v_sp.id, 'deduction', -v_take, v_sp.balance_tons - v_take, p_truck_reg, p_trip_id, auth.uid());
      v_remaining := v_remaining - v_take; v_deducted := true;
    end loop;
    if v_deducted then
      begin
        select exists(select 1 from public.stockpiles
                 where supplier_company_id = v_txn.supplier_company_id and buyer_company_id = v_txn.buyer_company_id),
               coalesce((select sum(balance_tons) from public.stockpiles
                 where supplier_company_id = v_txn.supplier_company_id and buyer_company_id = v_txn.buyer_company_id), 0)
          into v_pool_exists, v_pool_balance;
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
