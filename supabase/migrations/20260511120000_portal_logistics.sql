-- Portal logistics: routes, trips, vehicle positions, reconciliations.
-- RLS mirrors transaction / fleet party access patterns.

create table public.haul_routes (
  id uuid primary key default gen_random_uuid(),
  supplier_company_id uuid references public.companies (id) on delete cascade,
  buyer_company_id uuid references public.companies (id) on delete cascade,
  origin_label text not null,
  destination_label text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  constraint haul_routes_party_chk check (supplier_company_id is not null or buyer_company_id is not null)
);

create index haul_routes_supplier_idx on public.haul_routes (supplier_company_id);
create index haul_routes_buyer_idx on public.haul_routes (buyer_company_id);

create table public.trips (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions (id) on delete cascade,
  vehicle_id uuid references public.fleet_vehicles (id) on delete set null,
  route_id uuid references public.haul_routes (id) on delete set null,
  status text not null default 'scheduled',
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index trips_transaction_id_idx on public.trips (transaction_id);
create index trips_vehicle_id_idx on public.trips (vehicle_id);
create index trips_route_id_idx on public.trips (route_id);
create index trips_updated_at_idx on public.trips (updated_at desc);

create table public.vehicle_positions (
  id uuid primary key default gen_random_uuid(),
  vehicle_id uuid not null references public.fleet_vehicles (id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  heading double precision,
  recorded_at timestamptz not null default timezone('utc', now()),
  source text
);

create index vehicle_positions_vehicle_id_idx on public.vehicle_positions (vehicle_id, recorded_at desc);

create table public.reconciliations (
  id uuid primary key default gen_random_uuid(),
  buyer_company_id uuid references public.companies (id) on delete set null,
  supplier_company_id uuid references public.companies (id) on delete set null,
  transporter_company_id uuid references public.companies (id) on delete set null,
  period_start date,
  period_end date,
  status text not null default 'draft',
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index reconciliations_buyer_idx on public.reconciliations (buyer_company_id);
create index reconciliations_supplier_idx on public.reconciliations (supplier_company_id);
create index reconciliations_transporter_idx on public.reconciliations (transporter_company_id);

create trigger haul_routes_updated_at
before update on public.haul_routes
for each row execute function public.set_updated_at();

create trigger trips_updated_at
before update on public.trips
for each row execute function public.set_updated_at();

create trigger reconciliations_updated_at
before update on public.reconciliations
for each row execute function public.set_updated_at();

alter table public.haul_routes enable row level security;
alter table public.trips enable row level security;
alter table public.vehicle_positions enable row level security;
alter table public.reconciliations enable row level security;

-- haul_routes: staff of supplier or buyer org
create policy haul_routes_select on public.haul_routes
for select to authenticated
using (
  public.is_company_staff(supplier_company_id)
  or public.is_company_staff(buyer_company_id)
);

create policy haul_routes_insert_managers on public.haul_routes
for insert to authenticated
with check (
  public.is_company_manager(supplier_company_id)
  or public.is_company_manager(buyer_company_id)
);

create policy haul_routes_update_managers on public.haul_routes
for update to authenticated
using (
  public.is_company_manager(supplier_company_id)
  or public.is_company_manager(buyer_company_id)
)
with check (
  public.is_company_manager(supplier_company_id)
  or public.is_company_manager(buyer_company_id)
);

create policy haul_routes_delete_managers on public.haul_routes
for delete to authenticated
using (
  public.is_company_manager(supplier_company_id)
  or public.is_company_manager(buyer_company_id)
);

-- trips: visible if user can see parent transaction
create policy trips_select on public.trips
for select to authenticated
using (
  exists (
    select 1 from public.transactions t
    where t.id = trips.transaction_id
      and (
        public.is_company_staff(t.supplier_company_id)
        or public.is_company_staff(t.buyer_company_id)
        or public.is_company_staff(t.transporter_company_id)
      )
  )
);

create policy trips_insert_managers on public.trips
for insert to authenticated
with check (
  exists (
    select 1 from public.transactions t
    where t.id = trips.transaction_id
      and (
        public.is_company_manager(t.supplier_company_id)
        or public.is_company_manager(t.buyer_company_id)
        or public.is_company_manager(t.transporter_company_id)
      )
  )
);

create policy trips_update_managers on public.trips
for update to authenticated
using (
  exists (
    select 1 from public.transactions t
    where t.id = trips.transaction_id
      and (
        public.is_company_manager(t.supplier_company_id)
        or public.is_company_manager(t.buyer_company_id)
        or public.is_company_manager(t.transporter_company_id)
      )
  )
)
with check (
  exists (
    select 1 from public.transactions t
    where t.id = trips.transaction_id
      and (
        public.is_company_manager(t.supplier_company_id)
        or public.is_company_manager(t.buyer_company_id)
        or public.is_company_manager(t.transporter_company_id)
      )
  )
);

create policy trips_delete_managers on public.trips
for delete to authenticated
using (
  exists (
    select 1 from public.transactions t
    where t.id = trips.transaction_id
      and (
        public.is_company_manager(t.supplier_company_id)
        or public.is_company_manager(t.buyer_company_id)
        or public.is_company_manager(t.transporter_company_id)
      )
  )
);

-- vehicle_positions: fleet owner staff
create policy vehicle_positions_select on public.vehicle_positions
for select to authenticated
using (
  exists (
    select 1 from public.fleet_vehicles fv
    where fv.id = vehicle_positions.vehicle_id
      and public.is_company_staff(fv.company_id)
  )
);

create policy vehicle_positions_insert_managers on public.vehicle_positions
for insert to authenticated
with check (
  exists (
    select 1 from public.fleet_vehicles fv
    where fv.id = vehicle_positions.vehicle_id
      and public.is_company_manager(fv.company_id)
  )
);

create policy vehicle_positions_update_managers on public.vehicle_positions
for update to authenticated
using (
  exists (
    select 1 from public.fleet_vehicles fv
    where fv.id = vehicle_positions.vehicle_id
      and public.is_company_manager(fv.company_id)
  )
)
with check (
  exists (
    select 1 from public.fleet_vehicles fv
    where fv.id = vehicle_positions.vehicle_id
      and public.is_company_manager(fv.company_id)
  )
);

create policy vehicle_positions_delete_managers on public.vehicle_positions
for delete to authenticated
using (
  exists (
    select 1 from public.fleet_vehicles fv
    where fv.id = vehicle_positions.vehicle_id
      and public.is_company_manager(fv.company_id)
  )
);

-- reconciliations: party staff read; party managers write
create policy reconciliations_select on public.reconciliations
for select to authenticated
using (
  public.is_company_staff(buyer_company_id)
  or public.is_company_staff(supplier_company_id)
  or public.is_company_staff(transporter_company_id)
);

create policy reconciliations_insert_managers on public.reconciliations
for insert to authenticated
with check (
  public.is_company_manager(buyer_company_id)
  or public.is_company_manager(supplier_company_id)
  or public.is_company_manager(transporter_company_id)
);

create policy reconciliations_update_managers on public.reconciliations
for update to authenticated
using (
  public.is_company_manager(buyer_company_id)
  or public.is_company_manager(supplier_company_id)
  or public.is_company_manager(transporter_company_id)
)
with check (
  public.is_company_manager(buyer_company_id)
  or public.is_company_manager(supplier_company_id)
  or public.is_company_manager(transporter_company_id)
);

create policy reconciliations_delete_managers on public.reconciliations
for delete to authenticated
using (
  public.is_company_manager(buyer_company_id)
  or public.is_company_manager(supplier_company_id)
  or public.is_company_manager(transporter_company_id)
);

grant select, insert, update, delete on public.haul_routes to authenticated;
grant select, insert, update, delete on public.trips to authenticated;
grant select, insert, update, delete on public.vehicle_positions to authenticated;
grant select, insert, update, delete on public.reconciliations to authenticated;
