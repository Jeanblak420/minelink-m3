-- Audit fix round (2026-07-13). Closes the server-side half of the 13 findings
-- from the full adversarial audit. Each section is idempotent.

begin;

-- =====================================================================
-- 1 (CRITICAL). trips.route_id foreign key pointed at the OLD haul_routes
--    table, but link_and_dispatch_request / accept_request_dispatch stamp a
--    routes.id on it — so the first real route acceptance would violate the FK
--    and roll the whole accept back. Re-point the FK to public.routes.
-- =====================================================================

-- Null any value that doesn't resolve in either table (0 in prod), so the new
-- constraint validates cleanly.
update public.trips t
set route_id = null
where t.route_id is not null
  and not exists (select 1 from public.routes rt where rt.id = t.route_id);

alter table public.trips drop constraint if exists trips_route_id_fkey;
alter table public.trips
  add constraint trips_route_id_fkey
  foreign key (route_id) references public.routes(id) on delete set null;

-- 2. Seal requirement now lives on the route the trip actually has. Add the
--    flag to routes (default false; the request form has no seal input yet, so
--    it stays false until one is added — but the lookup is now consistent).
alter table public.routes
  add column if not exists seal_required boolean not null default false;

-- =====================================================================
-- 3. list_mine_inbound_trips: read seal_required from routes (not haul_routes,
--    which dispatched trips never have), surface the reference number and
--    offloading point for the waybill, and stop ancient completed trips from
--    crowding active ones out of the window.
-- =====================================================================

-- Return type gains `reference` + `offloading_point`, so drop-then-create.
drop function if exists public.list_mine_inbound_trips(uuid);
create function public.list_mine_inbound_trips(p_supplier_company_id uuid)
returns table (
  trip_id uuid,
  status text,
  vehicle_id uuid,
  truck_reg text,
  route_id uuid,
  seal_required boolean,
  net_tons numeric,
  transaction_id uuid,
  buyer_company_id uuid,
  buyer_name text,
  transporter_name text,
  commodity text,
  reference text,
  offloading_point text,
  updated_at timestamptz
)
language sql security definer set search_path = public as $$
  select
    t.id,
    t.status,
    t.vehicle_id,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    t.route_id,
    coalesce(rt.seal_required, false),
    t.net_tons,
    tx.id,
    tx.buyer_company_id,
    bc.company_name,
    tc.company_name,
    coalesce(nullif(tx.metadata->>'commodity', ''), m.name),
    tx.reference_number,
    coalesce(rt.offloading_point, tx.metadata->>'offloading_point'),
    t.updated_at
  from public.trips t
  join public.transactions tx on tx.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.routes rt on rt.id = t.route_id
  left join public.companies bc on bc.id = tx.buyer_company_id
  left join public.companies tc on tc.id = tx.transporter_company_id
  left join public.minerals m on m.id = tx.mineral_id
  where tx.supplier_company_id = p_supplier_company_id
    and public.is_company_staff(p_supplier_company_id)
    -- Active trips, plus anything touched in the last 2 days (so the Security
    -- screen's "departed today" / recent lists still populate) — keeps stale
    -- completed trips from filling the 200-row window.
    and (
      t.status not in ('completed', 'cancelled')
      or t.updated_at > timezone('utc', now()) - interval '2 days'
    )
  order by t.updated_at desc
  limit 200;
$$;

grant execute on function public.list_mine_inbound_trips(uuid) to authenticated;

-- =====================================================================
-- 4. record_truck_load — recreated with:
--    * seal lookup from routes (finding 1 knock-on),
--    * waybill number forced to the transaction reference (finding 5: the
--      printed number now equals the recon WAYBILL NUMBER column) + dispatch
--      block (controller name + signature path) stored for later regeneration
--      (finding 6),
--    * the 0-tons completion notification only when THIS load actually
--      deducted from the pool (finding 11: no spurious duplicate on later
--      loads against an already-empty pool),
--    * the Security "load complete" notification (kept from 20260712290000).
-- =====================================================================

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
  v_deducted boolean := false;
  v_actor_name text;
  v_actor_sig text;
  v_wb jsonb;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then raise exception 'Trip % not found', p_trip_id; end if;
  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  -- Only the loading mine's staff may record a load.
  if not public.is_company_staff(v_txn.supplier_company_id) then
    raise exception 'Only the mine''s staff can record a load';
  end if;

  -- Seal enforcement (§2 Step 1/6) — from the trip's route.
  if v_trip.route_id is not null then
    select coalesce(seal_required, false) into v_seal_required
    from public.routes where id = v_trip.route_id;
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

  -- Persist seals (number + optional photo path).
  insert into public.seal_records (trip_id, transaction_id, seal_number, photo_url, captured_by)
  select p_trip_id, v_trip.transaction_id, e->>'number', e->>'photo_url', auth.uid()
  from jsonb_array_elements(p_seals) e
  where coalesce(e->>'number','') <> '';

  -- Dispatch-block identity for the waybill (the Load Controller = auth.uid()).
  v_actor_name := coalesce(
    (select display_name from public.profiles where id = auth.uid()),
    'Load Controller');
  v_actor_sig := (select signature_url from public.profiles where id = auth.uid());

  -- Waybill jsonb: force the number to the transaction reference (single shared
  -- identifier), and stamp the dispatch block so the signed copy can be
  -- regenerated at offload.
  v_wb := coalesce(p_waybill, '{}'::jsonb) || jsonb_build_object(
    'waybill_number', v_txn.reference_number,
    'dispatched_by', v_actor_name,
    'dispatch_signature_path', v_actor_sig
  );

  -- Advance the trip.
  update public.trips set
    status = 'loaded',
    loaded_at = timezone('utc', now()),
    net_tons = p_net_tons,
    metadata = coalesce(metadata, '{}'::jsonb)
      || jsonb_build_object('truck_reg', p_truck_reg, 'waybill', v_wb)
  where id = p_trip_id
  returning * into v_trip;

  -- Transaction reflects the shipped load.
  update public.transactions set status = 'in_transit'
  where id = v_trip.transaction_id and status in ('draft','scheduled');

  -- Best-effort: tell the gate the truck is loaded and ready for check-out.
  begin
    perform public.notify_company_role(
      v_txn.supplier_company_id,
      array['security'],
      'Load complete',
      'Truck '
        || coalesce(p_truck_reg, v_trip.metadata->>'truck_reg', 'at the weighbridge')
        || ' is loaded ('
        || coalesce(round(p_net_tons, 2)::text, '?')
        || ' t) — ready for gate check-out.',
      'truck_loaded',
      'mineSupplier',
      'normal',
      jsonb_build_object('trip_id', v_trip.id, 'transaction_id', v_trip.transaction_id)
    );
  exception when others then
    null;
  end;

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
      v_deducted := true;
    end loop;

    -- 0-tons completion: only when THIS load actually deducted and thereby
    -- emptied the (supplier, buyer) pool. Guarding on v_deducted stops a later
    -- load against an already-empty pool from re-firing the notification.
    if v_deducted then
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
            true
          );
        end if;
      exception when others then
        null;
      end;
    end if;
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

grant execute on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) to authenticated;

-- =====================================================================
-- 5 (finding 6). record_pod — store the driver's received block (name +
--    signature path) into the waybill metadata at offload, so the signed
--    waybill can be regenerated with the RECEIVED block filled.
-- =====================================================================

create or replace function public.record_pod(
  p_trip_id uuid,
  p_delivered_tons numeric,
  p_photo_url text default null
)
returns public.trips
language plpgsql security definer set search_path = public as $$
declare
  v_trip public.trips;
  v_txn public.transactions;
  v_recon_id uuid;
  v_driver_name text;
  v_driver_sig text;
begin
  select * into v_trip from public.trips where id = p_trip_id;
  if not found then raise exception 'Trip % not found', p_trip_id; end if;
  select * into v_txn from public.transactions where id = v_trip.transaction_id;

  if not (
    public.is_company_staff(v_txn.transporter_company_id)
    or public.is_company_staff(v_txn.supplier_company_id)
  ) then
    raise exception 'Only the transporter/driver may upload proof of delivery';
  end if;

  insert into public.pod_uploads (trip_id, transaction_id, photo_url, delivered_tons, uploaded_by)
  values (p_trip_id, v_trip.transaction_id, p_photo_url, p_delivered_tons, auth.uid());

  v_driver_name := coalesce(
    (select display_name from public.profiles where id = auth.uid()), 'Driver');
  v_driver_sig := (select signature_url from public.profiles where id = auth.uid());

  update public.trips set
    status = 'completed',
    offloaded_at = coalesce(offloaded_at, timezone('utc', now())),
    completed_at = timezone('utc', now()),
    metadata = coalesce(metadata, '{}'::jsonb) || jsonb_build_object(
      'waybill',
      coalesce(metadata->'waybill', '{}'::jsonb) || jsonb_build_object(
        'received_by', v_driver_name,
        'received_signature_path', v_driver_sig,
        'pod_photo_path', p_photo_url
      )
    )
  where id = p_trip_id
  returning * into v_trip;

  update public.transactions set status = 'completed'
  where id = v_trip.transaction_id;

  select id into v_recon_id from public.reconciliations
  where supplier_company_id = v_txn.supplier_company_id
    and buyer_company_id is not distinct from v_txn.buyer_company_id
    and transporter_company_id is not distinct from v_txn.transporter_company_id
    and status = 'draft'
  limit 1;
  if v_recon_id is not null then
    update public.reconciliations set
      metadata = coalesce(metadata,'{}'::jsonb) || jsonb_build_object(
        'delivered_tons', coalesce((metadata->>'delivered_tons')::numeric,0) + coalesce(p_delivered_tons,0))
    where id = v_recon_id;
  end if;

  return v_trip;
end;
$$;

grant execute on function public.record_pod(uuid, numeric, text) to authenticated;

-- =====================================================================
-- 6 (finding 6). get_trip_waybill — assemble a full waybill for a trip
--    (both dispatch and received blocks) so the signed copy can be rendered at
--    offload and by any party later. Party-scoped.
-- =====================================================================

drop function if exists public.get_trip_waybill(uuid);
create function public.get_trip_waybill(p_trip_id uuid)
returns table (
  source_mine text,
  waybill_number text,
  transporter text,
  fleet_reg text,
  destination text,
  product text,
  tons numeric,
  seals text[],
  dispatched_by text,
  dispatch_signature_path text,
  dispatched_at timestamptz,
  received_by text,
  received_signature_path text,
  received_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select
    sc.company_name,
    coalesce(t.metadata->'waybill'->>'waybill_number', tx.reference_number),
    tc.company_name,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    coalesce(rt.offloading_point, tx.metadata->>'offloading_point', t.metadata->'waybill'->>'destination'),
    coalesce(nullif(tx.metadata->>'commodity', ''), m.name),
    t.net_tons,
    coalesce(
      (select array_agg(sr.seal_number)
       from public.seal_records sr
       where sr.trip_id = t.id and coalesce(sr.seal_number,'') <> ''),
      array[]::text[]),
    t.metadata->'waybill'->>'dispatched_by',
    t.metadata->'waybill'->>'dispatch_signature_path',
    t.loaded_at,
    t.metadata->'waybill'->>'received_by',
    t.metadata->'waybill'->>'received_signature_path',
    t.offloaded_at
  from public.trips t
  join public.transactions tx on tx.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.routes rt on rt.id = t.route_id
  left join public.companies sc on sc.id = tx.supplier_company_id
  left join public.companies tc on tc.id = tx.transporter_company_id
  left join public.minerals m on m.id = tx.mineral_id
  where t.id = p_trip_id
    and (
      public.is_platform_admin()
      or public.is_company_staff(tx.supplier_company_id)
      or public.is_company_staff(tx.buyer_company_id)
      or public.is_company_staff(tx.transporter_company_id)
    );
$$;

revoke all on function public.get_trip_waybill(uuid) from public;
revoke all on function public.get_trip_waybill(uuid) from anon;
grant execute on function public.get_trip_waybill(uuid) to authenticated;

-- =====================================================================
-- 7 (finding 10). accept_request_dispatch — recreated (the FK is now valid so
--    the trips insert succeeds) and given a truck-count cap: the transporter
--    cannot accept with MORE trucks than the request's Number of Trucks
--    Required (fewer is allowed — partial fulfilment).
-- =====================================================================

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
  v_required int;
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

  -- Enforce the Number of Trucks Required as an upper bound.
  v_required := nullif(regexp_replace(coalesce(v_req.num_slots, ''), '\D', '', 'g'), '')::int;
  if v_required is not null and v_required > 0
     and array_length(p_vehicle_ids, 1) > v_required then
    raise exception 'This route needs at most % truck(s); you selected %',
      v_required, array_length(p_vehicle_ids, 1);
  end if;

  foreach v_vid in array p_vehicle_ids loop
    select * into v_vehicle from public.fleet_vehicles where id = v_vid;
    if not found or v_vehicle.company_id <> v_dispatch.transporter_company_id then
      raise exception 'Truck % is not in your fleet', v_vid;
    end if;

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

grant execute on function public.accept_request_dispatch(uuid, uuid[]) to authenticated;

-- =====================================================================
-- 8 (finding 4). The Supervisor/Foreman maintains stockpiles, but the write
--    policies required is_company_manager (owner/admin/management only), which
--    a supervisorForeman is not. Add a writer predicate that also admits an
--    active supervisorForeman, and use it for stockpile writes.
-- =====================================================================

create or replace function public.is_company_stockpile_writer(p_company_id uuid)
returns boolean
language sql stable security definer set search_path = public as $$
  select public.is_company_manager(p_company_id)
    or exists (
      select 1 from public.employees e
      where e.company_id = p_company_id
        and e.user_id = auth.uid()
        and e.role = 'supervisorForeman'
        and e.status = 'active'
        and coalesce(e.is_dismissed, false) = false
    );
$$;
grant execute on function public.is_company_stockpile_writer(uuid) to authenticated;

drop policy if exists stockpiles_insert_managers on public.stockpiles;
create policy stockpiles_insert_writers on public.stockpiles
for insert to authenticated
with check (public.is_company_stockpile_writer(supplier_company_id));

drop policy if exists stockpiles_update_managers on public.stockpiles;
create policy stockpiles_update_writers on public.stockpiles
for update to authenticated
using (public.is_company_stockpile_writer(supplier_company_id))
with check (public.is_company_stockpile_writer(supplier_company_id));

drop policy if exists stockpile_txn_insert on public.stockpile_transactions;
create policy stockpile_txn_insert on public.stockpile_transactions
for insert to authenticated
with check (
  exists (
    select 1 from public.stockpiles s
    where s.id = stockpile_transactions.stockpile_id
      and public.is_company_stockpile_writer(s.supplier_company_id)
  )
);

-- =====================================================================
-- 9 (finding 9). Recon two-version edit: tighten save_recon_upload toward the
--    §4 "initiator + super-admin edit, others view" rule. Only a manager of an
--    INITIATING company (one that has submitted a request) — or the platform
--    admin — may write; transporters and other non-initiators are view-only.
--    (Each company still edits only its own private (company_id, side) pair.)
-- =====================================================================

create or replace function public.save_recon_upload(
  p_company_id uuid,
  p_side text,
  p_original_path text,
  p_edited_path text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  pair public.reconciliation_uploads;
begin
  if not (
    public.is_platform_admin()
    or (
      public.is_company_manager(p_company_id)
      and exists (
        select 1 from public.transportation_requests r
        where r.buyer_company_id = p_company_id
      )
    )
  ) then
    raise exception 'Only the initiating org''s admin or the MineLink admin may upload edited reconciliations';
  end if;
  if p_side not in ('A', 'B') then
    raise exception 'Side must be A or B';
  end if;
  if p_edited_path is null or length(trim(p_edited_path)) = 0 then
    raise exception 'An edited file is required';
  end if;

  select * into pair
  from public.reconciliation_uploads
  where company_id = p_company_id and side = p_side;

  if pair.id is null then
    if p_original_path is null or length(trim(p_original_path)) = 0 then
      raise exception 'The original system export must be snapshotted on the first upload';
    end if;
    insert into public.reconciliation_uploads (
      company_id, side, original_path, edited_path, edited_by, edited_uploaded_at
    ) values (
      p_company_id, p_side, p_original_path, p_edited_path, auth.uid(), timezone('utc', now())
    )
    returning * into pair;
  else
    update public.reconciliation_uploads
    set edited_path = p_edited_path,
        edited_by = auth.uid(),
        edited_uploaded_at = timezone('utc', now())
    where id = pair.id
    returning * into pair;
  end if;

  return to_jsonb(pair);
end;
$$;

grant execute on function public.save_recon_upload(uuid, text, text, text) to authenticated;

-- =====================================================================
-- 10 (finding 3). Private bucket for weighbridge scale + seal photos, so the
--     Load Controller's captures are actually stored (folder = supplier
--     company, staff-scoped like request_docs).
-- =====================================================================

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'load_photos', 'load_photos', false, 20971520,
  array['image/png', 'image/jpeg', 'image/webp', 'image/heic']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists load_photos_select on storage.objects;
drop policy if exists load_photos_insert_company on storage.objects;
drop policy if exists load_photos_delete_company on storage.objects;

create policy load_photos_select on storage.objects
for select to authenticated
using (
  bucket_id = 'load_photos'
  and (
    public.is_platform_admin()
    or exists (
      select 1 from public.companies c
      where c.id::text = (storage.foldername(name))[1]
        and public.is_company_staff(c.id)
    )
  )
);
create policy load_photos_insert_company on storage.objects
for insert to authenticated
with check (
  bucket_id = 'load_photos'
  and exists (
    select 1 from public.companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.is_company_staff(c.id)
  )
);
create policy load_photos_delete_company on storage.objects
for delete to authenticated
using (
  bucket_id = 'load_photos'
  and exists (
    select 1 from public.companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.is_company_staff(c.id)
  )
);

-- =====================================================================
-- 11 (finding 8 + 13). Realtime: publish audit_logs (super-admin live audit
--     feed) and trips (live status on the map / dashboards). Guarded so a
--     re-run never errors.
-- =====================================================================

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'audit_logs'
  ) then
    alter publication supabase_realtime add table public.audit_logs;
  end if;
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'trips'
  ) then
    alter publication supabase_realtime add table public.trips;
  end if;
end $$;

-- =====================================================================
-- 12 (finding 13). list_trip_reconciliations — surface the POD photo path so
--     the delivered leg's proof can actually be viewed by the parties.
-- =====================================================================

-- Return type gains `pod_photo_path`, so drop-then-create.
drop function if exists public.list_trip_reconciliations(uuid);
create function public.list_trip_reconciliations(p_company_id uuid)
returns table (
  trip_id uuid,
  reference text,
  truck_reg text,
  commodity text,
  source_name text,
  customer_name text,
  transporter_name text,
  mine_net_tons numeric,
  delivered_tons numeric,
  variance numeric,
  trip_status text,
  pod_photo_path text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    t.id,
    txn.reference_number,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    txn.metadata->>'commodity',
    sc.company_name,
    bc.company_name,
    tc.company_name,
    t.net_tons,
    pod.delivered_tons,
    case
      when t.net_tons is not null and pod.delivered_tons is not null
        then t.net_tons - pod.delivered_tons
      else null
    end as variance,
    t.status,
    pod.photo_url,
    t.updated_at
  from public.trips t
  join public.transactions txn on txn.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.companies sc on sc.id = txn.supplier_company_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  left join public.companies tc on tc.id = txn.transporter_company_id
  left join lateral (
    select p.delivered_tons, p.photo_url
    from public.pod_uploads p
    where p.trip_id = t.id
    order by p.uploaded_at desc
    limit 1
  ) pod on true
  where (
      public.is_platform_admin()
      or public.is_company_staff(txn.supplier_company_id)
      or public.is_company_staff(txn.buyer_company_id)
      or public.is_company_staff(txn.transporter_company_id)
    )
    and (
      p_company_id is null
      or txn.supplier_company_id = p_company_id
      or txn.buyer_company_id = p_company_id
      or txn.transporter_company_id = p_company_id
    )
    and t.net_tons is not null
  order by t.updated_at desc;
$function$;

revoke all on function public.list_trip_reconciliations(uuid) from public;
revoke all on function public.list_trip_reconciliations(uuid) from anon;
grant execute on function public.list_trip_reconciliations(uuid) to authenticated;

commit;
