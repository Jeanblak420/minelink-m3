-- Close the §4 per-role trip side-effect gaps found in the 2026-07-12 audit:
--
-- 1. "Security check-in notifies Load Controller" was only an in-memory
--    session-local push (WorkflowNotificationProvider) that never reaches the
--    controller's device. set_trip_status now fires a real DB notification to
--    the mine's controllerWB employees on arrived_at_mine (best-effort, never
--    fails the status change).
-- 2. "The cycle repeats until that stockpile reaches 0 tons, at which point
--    the transaction/workflow is complete" had no implementation:
--    record_truck_load decremented FIFO but never looked at the balance.
--    It now detects the (supplier, buyer) stockpile pool hitting 0, stamps
--    transactions.metadata.stockpile_depleted_at, and notifies the mine's
--    owner + supervisorForeman/admin/management (best-effort).
--
-- (The other two audit gaps — driver "start route" -> en_route_to_load and
-- Security checkout advancing to en_route_to_offload — are client-side and
-- use the existing set_trip_status RPC unchanged.)
--
-- Both functions are recreated verbatim from
-- 20260627000000_trip_lifecycle_seals_recon_cascades.sql plus the additions.

begin;

-- 1. Internal helper: notify every active employee of given roles at a company
--    (optionally the company owner too). Not callable by clients.

create or replace function public.notify_company_role(
  p_company_id uuid,
  p_roles text[],
  p_title text,
  p_message text,
  p_type text,
  p_org_type text default null,
  p_importance text default 'normal',
  p_metadata jsonb default '{}'::jsonb,
  p_include_owner boolean default false
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  v_rec record;
begin
  if p_company_id is null then
    return;
  end if;
  if p_include_owner then
    perform public.create_notification_internal(
      (select user_id from public.companies where id = p_company_id),
      p_company_id, null, p_title, p_message, p_type,
      null, auth.uid(), null, p_org_type, p_importance, p_metadata
    );
  end if;
  for v_rec in
    select e.user_id, e.role
    from public.employees e
    where e.company_id = p_company_id
      and e.role = any(p_roles)
      and e.status = 'active'
      and coalesce(e.is_dismissed, false) = false
      and e.user_id is not null
  loop
    perform public.create_notification_internal(
      v_rec.user_id, p_company_id, null, p_title, p_message, p_type,
      null, auth.uid(), v_rec.role, p_org_type, p_importance, p_metadata
    );
  end loop;
end;
$$;

revoke all on function public.notify_company_role(uuid, text[], text, text, text, text, text, jsonb, boolean) from public;
revoke all on function public.notify_company_role(uuid, text[], text, text, text, text, text, jsonb, boolean) from anon;
revoke all on function public.notify_company_role(uuid, text[], text, text, text, text, text, jsonb, boolean) from authenticated;

-- 2. set_trip_status: unchanged behaviour + Load Controller notification on
--    arrived_at_mine (§4 Security row: "Notifies Load Controller").

create or replace function public.set_trip_status(p_trip_id uuid, p_status text)
returns public.trips
language plpgsql security definer set search_path = public as $$
declare
  v_trip public.trips;
  v_txn public.transactions;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then raise exception 'Trip % not found', p_trip_id; end if;
  select * into v_txn from public.transactions where id = v_trip.transaction_id;
  if not (
    public.is_company_staff(v_txn.supplier_company_id)
    or public.is_company_staff(v_txn.buyer_company_id)
    or public.is_company_staff(v_txn.transporter_company_id)
  ) then
    raise exception 'Not authorised to update this trip';
  end if;

  update public.trips set
    status = p_status,
    arrived_at = case when p_status = 'arrived_at_mine' then timezone('utc', now()) else arrived_at end,
    loading_at = case when p_status = 'loading' then timezone('utc', now()) else loading_at end,
    left_at = case when p_status = 'left_mine' then timezone('utc', now()) else left_at end,
    offloaded_at = case when p_status = 'offloaded' then timezone('utc', now()) else offloaded_at end,
    completed_at = case when p_status = 'completed' then timezone('utc', now()) else completed_at end
  where id = p_trip_id
  returning * into v_trip;

  -- Best-effort Load Controller notification on Security check-in.
  if p_status = 'arrived_at_mine' then
    begin
      perform public.notify_company_role(
        v_txn.supplier_company_id,
        array['controllerWB'],
        'Truck checked in',
        'Truck '
          || coalesce(
               (select fv.vehicle_registration_number
                from public.fleet_vehicles fv where fv.id = v_trip.vehicle_id),
               v_trip.metadata->>'truck_reg',
               'without a registered plate')
          || ' has arrived at the gate and is ready for the weighbridge (tare weigh).',
        'truck_checked_in',
        'mineSupplier',
        'high',
        jsonb_build_object('trip_id', v_trip.id, 'transaction_id', v_trip.transaction_id)
      );
    exception when others then
      null; -- never fail the status change on a notify error
    end;
  end if;

  return v_trip;
end;
$$;

-- 3. record_truck_load: unchanged behaviour + 0-tons stockpile completion
--    (§4 "Stockpile decrement ... until that stockpile reaches 0 tons, at
--    which point the transaction/workflow is complete").

create or replace function public.record_truck_load(
  p_trip_id uuid,
  p_net_tons numeric,
  p_truck_reg text default null,
  p_seals jsonb default '[]'::jsonb,
  p_waybill jsonb default '{}'::jsonb
)
returns public.trips
language plpgsql security definer set search_path = public as $$
declare
  v_trip public.trips;
  v_txn public.transactions;
  v_seal_required boolean := false;
  v_seal_count int := 0;
  v_remaining numeric := coalesce(p_net_tons, 0);
  v_take numeric;
  v_sp record;
  v_recon_id uuid;
  v_pool_balance numeric;
  v_pool_exists boolean := false;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then raise exception 'Trip % not found', p_trip_id; end if;
  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  -- Only the loading mine's staff may record a load.
  if not public.is_company_staff(v_txn.supplier_company_id) then
    raise exception 'Only the mine''s staff can record a load';
  end if;

  -- Seal enforcement (§2 Step 1/6).
  if v_trip.route_id is not null then
    select coalesce(seal_required, false) into v_seal_required
    from public.haul_routes where id = v_trip.route_id;
  end if;
  v_seal_count := coalesce(jsonb_array_length(p_seals), 0);
  if v_seal_required and v_seal_count = 0 then
    raise exception 'This route requires seals: capture each seal number and photo before saving';
  end if;
  if v_seal_required then
    if exists (
      select 1 from jsonb_array_elements(p_seals) e
      where coalesce(e->>'number','') = '' or coalesce(e->>'photo_url','') = ''
    ) then
      raise exception 'Each seal needs both a number and a photo on a seal-required route';
    end if;
  end if;

  -- Persist seals.
  insert into public.seal_records (trip_id, transaction_id, seal_number, photo_url, captured_by)
  select p_trip_id, v_trip.transaction_id, e->>'number', e->>'photo_url', auth.uid()
  from jsonb_array_elements(p_seals) e
  where coalesce(e->>'number','') <> '';

  -- Advance the trip.
  update public.trips set
    status = 'loaded',
    loaded_at = timezone('utc', now()),
    net_tons = p_net_tons,
    metadata = coalesce(metadata, '{}'::jsonb)
      || jsonb_build_object('truck_reg', p_truck_reg, 'waybill', p_waybill)
  where id = p_trip_id
  returning * into v_trip;

  -- Transaction reflects the shipped load.
  update public.transactions set status = 'in_transit'
  where id = v_trip.transaction_id and status in ('draft','scheduled');

  -- Stockpile deduction (FIFO across the buyer's stockpiles at this supplier).
  if v_txn.buyer_company_id is not null and v_remaining > 0 then
    for v_sp in
      select * from public.stockpiles
      where supplier_company_id = v_txn.supplier_company_id
        and buyer_company_id = v_txn.buyer_company_id
        and balance_tons > 0
      order by created_at
    loop
      exit when v_remaining <= 0;
      v_take := least(v_remaining, v_sp.balance_tons);
      update public.stockpiles set balance_tons = balance_tons - v_take where id = v_sp.id;
      insert into public.stockpile_transactions
        (stockpile_id, type, delta_tons, balance_after, truck_reg, trip_id, created_by)
      values
        (v_sp.id, 'deduction', -v_take, v_sp.balance_tons - v_take, p_truck_reg, p_trip_id, auth.uid());
      v_remaining := v_remaining - v_take;
    end loop;

    -- 0-tons completion: when this load-out empties the (supplier, buyer)
    -- stockpile pool, the physical cycle is complete — stamp it and tell the
    -- mine. Best-effort; never fails the load record.
    begin
      select exists(
               select 1 from public.stockpiles
               where supplier_company_id = v_txn.supplier_company_id
                 and buyer_company_id = v_txn.buyer_company_id),
             coalesce((
               select sum(balance_tons) from public.stockpiles
               where supplier_company_id = v_txn.supplier_company_id
                 and buyer_company_id = v_txn.buyer_company_id), 0)
        into v_pool_exists, v_pool_balance;

      if v_pool_exists and v_pool_balance <= 0
         and (v_txn.metadata is null or v_txn.metadata->>'stockpile_depleted_at' is null) then
        update public.transactions set
          metadata = coalesce(metadata, '{}'::jsonb)
            || jsonb_build_object('stockpile_depleted_at', timezone('utc', now()))
        where id = v_txn.id;

        perform public.notify_company_role(
          v_txn.supplier_company_id,
          array['supervisorForeman', 'admin', 'management'],
          'Stockpile reached 0 tons',
          'The stockpile for '
            || coalesce(
                 (select company_name from public.companies
                  where id = v_txn.buyer_company_id),
                 'the buyer')
            || ' has been fully loaded out (0 tons remaining). This transaction cycle is complete.',
          'stockpile_depleted',
          'mineSupplier',
          'high',
          jsonb_build_object('trip_id', v_trip.id, 'transaction_id', v_txn.id),
          true -- include the company owner
        );
      end if;
    exception when others then
      null;
    end;
  end if;

  -- Ensure a draft reconciliation for the parties (recon cascade).
  select id into v_recon_id from public.reconciliations
  where supplier_company_id = v_txn.supplier_company_id
    and buyer_company_id is not distinct from v_txn.buyer_company_id
    and transporter_company_id is not distinct from v_txn.transporter_company_id
    and status = 'draft'
  limit 1;
  if v_recon_id is null then
    insert into public.reconciliations
      (buyer_company_id, supplier_company_id, transporter_company_id, status, metadata)
    values
      (v_txn.buyer_company_id, v_txn.supplier_company_id, v_txn.transporter_company_id,
       'draft', jsonb_build_object('loaded_tons', p_net_tons, 'loads', 1))
    returning id into v_recon_id;
  else
    update public.reconciliations set
      metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
        'loaded_tons', coalesce((metadata->>'loaded_tons')::numeric,0) + coalesce(p_net_tons,0),
        'loads', coalesce((metadata->>'loads')::int,0) + 1)
    where id = v_recon_id;
  end if;

  return v_trip;
end;
$$;

commit;
