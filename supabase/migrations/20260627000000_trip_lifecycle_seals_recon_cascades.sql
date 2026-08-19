-- Phase 2 — Trip lifecycle, seal enforcement, persistent stockpiles, and the
-- automatic recon cascades (§2). Additive only: no drops, existing rows keep
-- working. Reuses helpers set_updated_at(), is_company_staff(),
-- is_company_manager() from the canonical platform schema.

------------------------------------------------------------------------------
-- 1. Route seal requirement (§2 Step 1) + lifecycle timestamps on trips.
------------------------------------------------------------------------------
alter table public.haul_routes
  add column if not exists seal_required boolean not null default false;

alter table public.trips
  add column if not exists arrived_at timestamptz,
  add column if not exists loading_at timestamptz,
  add column if not exists loaded_at timestamptz,
  add column if not exists left_at timestamptz,
  add column if not exists offloaded_at timestamptz,
  add column if not exists completed_at timestamptz,
  add column if not exists net_tons numeric;

-- Canonical lifecycle values, validated for new/updated rows only (NOT VALID
-- keeps any legacy status strings intact).
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'trips_status_lifecycle_chk'
  ) then
    alter table public.trips
      add constraint trips_status_lifecycle_chk check (
        status in (
          'scheduled','en_route_to_load','arrived_at_mine','loading','loaded',
          'left_mine','en_route_to_offload','offloaded','completed','cancelled',
          -- legacy values still observed in existing rows:
          'in_transit','en_route','inbound','active','delivered','draft'
        )
      ) not valid;
  end if;
end $$;

------------------------------------------------------------------------------
-- 2. Seal records (§2 Step 6) — one row per captured seal.
------------------------------------------------------------------------------
create table if not exists public.seal_records (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references public.trips (id) on delete cascade,
  transaction_id uuid references public.transactions (id) on delete cascade,
  seal_number text not null,
  photo_url text,
  captured_by uuid references auth.users (id) on delete set null,
  captured_at timestamptz not null default timezone('utc', now())
);
create index if not exists seal_records_trip_idx on public.seal_records (trip_id);
create index if not exists seal_records_txn_idx on public.seal_records (transaction_id);

------------------------------------------------------------------------------
-- 3. Proof-of-delivery uploads (§2 Step 8).
------------------------------------------------------------------------------
create table if not exists public.pod_uploads (
  id uuid primary key default gen_random_uuid(),
  trip_id uuid references public.trips (id) on delete cascade,
  transaction_id uuid references public.transactions (id) on delete cascade,
  photo_url text,
  delivered_tons numeric,
  uploaded_by uuid references auth.users (id) on delete set null,
  uploaded_at timestamptz not null default timezone('utc', now())
);
create index if not exists pod_uploads_trip_idx on public.pod_uploads (trip_id);

------------------------------------------------------------------------------
-- 4. Persistent stockpiles + ledger (replaces the in-memory ledger).
------------------------------------------------------------------------------
create table if not exists public.stockpiles (
  id uuid primary key default gen_random_uuid(),
  supplier_company_id uuid not null references public.companies (id) on delete cascade,
  buyer_company_id uuid references public.companies (id) on delete set null,
  buyer_label text,
  name text not null,
  mineral text,
  grade text,
  balance_tons numeric not null default 0,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);
create index if not exists stockpiles_supplier_idx on public.stockpiles (supplier_company_id);
create index if not exists stockpiles_buyer_idx on public.stockpiles (buyer_company_id);

create table if not exists public.stockpile_transactions (
  id uuid primary key default gen_random_uuid(),
  stockpile_id uuid not null references public.stockpiles (id) on delete cascade,
  type text not null check (type in ('allocation','addition','deduction')),
  delta_tons numeric not null,
  balance_after numeric not null,
  truck_reg text,
  trip_id uuid references public.trips (id) on delete set null,
  created_by uuid references auth.users (id) on delete set null,
  at timestamptz not null default timezone('utc', now())
);
create index if not exists stockpile_txn_stockpile_idx on public.stockpile_transactions (stockpile_id, at desc);

create trigger stockpiles_updated_at
before update on public.stockpiles
for each row execute function public.set_updated_at();

------------------------------------------------------------------------------
-- 5. RLS — mirror the logistics/transaction party-access patterns.
------------------------------------------------------------------------------
alter table public.seal_records enable row level security;
alter table public.pod_uploads enable row level security;
alter table public.stockpiles enable row level security;
alter table public.stockpile_transactions enable row level security;

-- seal_records: visible to any party staff of the parent transaction.
create policy seal_records_select on public.seal_records
for select to authenticated
using (
  exists (
    select 1 from public.transactions t
    where t.id = seal_records.transaction_id
      and (
        public.is_company_staff(t.supplier_company_id)
        or public.is_company_staff(t.buyer_company_id)
        or public.is_company_staff(t.transporter_company_id)
      )
  )
);
create policy seal_records_insert on public.seal_records
for insert to authenticated
with check (
  exists (
    select 1 from public.transactions t
    where t.id = seal_records.transaction_id
      and public.is_company_staff(t.supplier_company_id)
  )
);

-- pod_uploads: party staff read; transporter/driver or supplier staff write.
create policy pod_uploads_select on public.pod_uploads
for select to authenticated
using (
  exists (
    select 1 from public.transactions t
    where t.id = pod_uploads.transaction_id
      and (
        public.is_company_staff(t.supplier_company_id)
        or public.is_company_staff(t.buyer_company_id)
        or public.is_company_staff(t.transporter_company_id)
      )
  )
);
create policy pod_uploads_insert on public.pod_uploads
for insert to authenticated
with check (
  exists (
    select 1 from public.transactions t
    where t.id = pod_uploads.transaction_id
      and (
        public.is_company_staff(t.transporter_company_id)
        or public.is_company_staff(t.supplier_company_id)
      )
  )
);

-- stockpiles: supplier staff read; supplier managers write; buyer staff read.
create policy stockpiles_select on public.stockpiles
for select to authenticated
using (
  public.is_company_staff(supplier_company_id)
  or public.is_company_staff(buyer_company_id)
);
create policy stockpiles_insert_managers on public.stockpiles
for insert to authenticated
with check (public.is_company_manager(supplier_company_id));
create policy stockpiles_update_managers on public.stockpiles
for update to authenticated
using (public.is_company_manager(supplier_company_id))
with check (public.is_company_manager(supplier_company_id));
create policy stockpiles_delete_managers on public.stockpiles
for delete to authenticated
using (public.is_company_manager(supplier_company_id));

create policy stockpile_txn_select on public.stockpile_transactions
for select to authenticated
using (
  exists (
    select 1 from public.stockpiles s
    where s.id = stockpile_transactions.stockpile_id
      and (public.is_company_staff(s.supplier_company_id)
        or public.is_company_staff(s.buyer_company_id))
  )
);
create policy stockpile_txn_insert on public.stockpile_transactions
for insert to authenticated
with check (
  exists (
    select 1 from public.stockpiles s
    where s.id = stockpile_transactions.stockpile_id
      and public.is_company_staff(s.supplier_company_id)
  )
);

grant select, insert, update, delete on public.seal_records to authenticated;
grant select, insert, update, delete on public.pod_uploads to authenticated;
grant select, insert, update, delete on public.stockpiles to authenticated;
grant select, insert, update, delete on public.stockpile_transactions to authenticated;

------------------------------------------------------------------------------
-- 6. Cascade RPCs.
------------------------------------------------------------------------------

-- Advance a trip's status for gate/driver steps (arrived, left, en_route…).
-- Stamps the matching lifecycle timestamp. Authorised for any party staff.
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
  return v_trip;
end;
$$;

-- Record a confirmed truck load (§2 Step 6) and fire the cascade:
--   trip -> loaded, seal records, stockpile deduction (FIFO for the buyer),
--   ensure a draft reconciliation for the parties, transaction -> in_transit.
-- p_seals: jsonb array of {"number": "...", "photo_url": "..."}.
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

-- Record proof of delivery (§2 Step 8/9) and finalise the cascade.
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

  update public.trips set
    status = 'completed',
    offloaded_at = coalesce(offloaded_at, timezone('utc', now())),
    completed_at = timezone('utc', now())
  where id = p_trip_id
  returning * into v_trip;

  update public.transactions set status = 'completed'
  where id = v_trip.transaction_id;

  -- Roll delivered tons into the open reconciliation.
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

grant execute on function public.set_trip_status(uuid, text) to authenticated;
grant execute on function public.record_truck_load(uuid, numeric, text, jsonb, jsonb) to authenticated;
grant execute on function public.record_pod(uuid, numeric, text) to authenticated;
