-- Two "runs as expected" fixes from the 2026-07-12 side-effects audit:
--
-- 1. POD photos had nowhere to live: the driver's camera capture was picked
--    client-side but discarded, and no storage bucket existed for
--    pod_uploads.photo_url to point at. Adds a private `pod_photos` bucket
--    (layout `<company_id>/<uuid>_<name>`, same company-folder RLS as
--    request_docs; select additionally open to platform admins).
-- 2. The Load Controller's "Load complete — ready to release" ping to
--    Security was in-memory only (never crosses devices). record_truck_load
--    (recreated verbatim from 20260712280000) now also fires a best-effort DB
--    notification to the mine's `security` employees after the load records.

begin;

-- 1. POD photo bucket + storage RLS ------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'pod_photos',
  'pod_photos',
  false,
  20971520,
  array['image/png', 'image/jpeg', 'image/webp', 'image/heic']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists pod_photos_select on storage.objects;
drop policy if exists pod_photos_insert_company on storage.objects;
drop policy if exists pod_photos_delete_company on storage.objects;

create policy pod_photos_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'pod_photos'
  and (
    public.is_platform_admin()
    or exists (
      select 1
      from public.companies c
      where c.id::text = (storage.foldername(name))[1]
        and public.is_company_staff(c.id)
    )
  )
);

create policy pod_photos_insert_company
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'pod_photos'
  and exists (
    select 1
    from public.companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.is_company_staff(c.id)
  )
);

create policy pod_photos_delete_company
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'pod_photos'
  and exists (
    select 1
    from public.companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.is_company_staff(c.id)
  )
);

-- 2. record_truck_load + Security "ready to release" notification -------------

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
