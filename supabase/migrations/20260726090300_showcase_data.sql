-- ============================================================================
-- Showcase / demo data for the tutorial system.
-- Ported/adapted from ML/supabase/migrations/000017_showcase_data.sql
--
-- Adaptations from the ML donor schema to WT-live:
--   * Seeds made idempotent: a unique index on (category, json_data->>'id')
--     + ON CONFLICT DO NOTHING (ML re-inserted duplicates on every run).
--   * Guard note: the seed payloads are self-contained fictional JSONB demo
--     entities with NO foreign keys into live companies/fleet/trips, so no
--     existence guard on live rows is required (mirrors the WT demo-seed
--     "skip if missing" style only where a dependency actually exists).
--   * Platform-admin management policies added via public.is_platform_admin()
--     (ML had read-only RLS and seeded as the migration role only).
-- ============================================================================

create table if not exists public.showcase_data (
  id         uuid primary key default gen_random_uuid(),
  category   text not null,
  json_data  jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

comment on table public.showcase_data
  is 'Demo/example data for the showcase tutorial system';
comment on column public.showcase_data.category
  is 'Category: mine, buyer, transporter, truck, driver, trip, stockpile, road_request';
comment on column public.showcase_data.json_data
  is 'Structured payload for the demo entity';

-- Idempotency key for seeds (every seed payload carries a demo "id").
create unique index if not exists showcase_data_category_demo_id_key
  on public.showcase_data (category, (json_data ->> 'id'));

-- ── RLS ──────────────────────────────────────────────────────────────────────

alter table public.showcase_data enable row level security;

drop policy if exists showcase_data_select_all on public.showcase_data;
create policy showcase_data_select_all on public.showcase_data
for select to authenticated
using (true);

drop policy if exists showcase_data_write_admin on public.showcase_data;
create policy showcase_data_write_admin on public.showcase_data
for all to authenticated
using (public.is_platform_admin())
with check (public.is_platform_admin());

grant select on public.showcase_data to authenticated;
grant insert, update, delete on public.showcase_data to authenticated;  -- rows gated by admin policy

-- ── Idempotent seed rows (fictional demo content; no live FKs) ───────────────

insert into public.showcase_data (category, json_data) values
('mine', '{
  "id": "mine-001",
  "name": "Mogalakwena Platinum Mine",
  "location": "Mokopane, Limpopo",
  "org_type": "mine_supplier",
  "products": ["Platinum Concentrate", "Chrome Ore"],
  "active_routes": 3
}'::jsonb),
('mine', '{
  "id": "mine-002",
  "name": "Sishen Iron Ore",
  "location": "Kathu, Northern Cape",
  "org_type": "mine_supplier",
  "products": ["Iron Ore (62% Fe)", "Iron Ore (58% Fe)"],
  "active_routes": 5
}'::jsonb),
('buyer', '{
  "id": "buyer-001",
  "name": "ArcelorMittal SA",
  "location": "Vanderbijlpark, Gauteng",
  "org_type": "buyer",
  "commodities": ["Iron Ore", "Coking Coal"]
}'::jsonb),
('buyer', '{
  "id": "buyer-002",
  "name": "Glencore Alloys",
  "location": "Rustenburg, North West",
  "org_type": "buyer",
  "commodities": ["Chrome Ore", "Manganese"]
}'::jsonb),
('transporter', '{
  "id": "transporter-001",
  "name": "Barloworld Transport",
  "location": "Johannesburg, Gauteng",
  "org_type": "transporter",
  "fleet_size": 120,
  "active_trucks": 87
}'::jsonb),
('transporter', '{
  "id": "transporter-002",
  "name": "Unitrans",
  "location": "Pretoria, Gauteng",
  "org_type": "transporter",
  "fleet_size": 95,
  "active_trucks": 72
}'::jsonb),
('truck', '{
  "id": "truck-001",
  "registration": "HMV 847 GP",
  "type": "Side Tipper",
  "make": "Volvo FH16",
  "capacity_tons": 34,
  "transporter_id": "transporter-001",
  "transporter_name": "Barloworld Transport",
  "status": "active"
}'::jsonb),
('truck', '{
  "id": "truck-002",
  "registration": "HMV 291 NW",
  "type": "Side Tipper",
  "make": "Scania R580",
  "capacity_tons": 34,
  "transporter_id": "transporter-001",
  "transporter_name": "Barloworld Transport",
  "status": "active"
}'::jsonb),
('truck', '{
  "id": "truck-003",
  "registration": "HMV 563 FS",
  "type": "Flatbed",
  "make": "MAN TGS 27.480",
  "capacity_tons": 30,
  "transporter_id": "transporter-002",
  "transporter_name": "Unitrans",
  "status": "maintenance"
}'::jsonb),
('driver', '{
  "id": "driver-001",
  "name": "Sipho Ndlovu",
  "license": "EC 12345678",
  "phone": "+27 82 111 2233",
  "transporter_id": "transporter-001",
  "transporter_name": "Barloworld Transport",
  "years_experience": 12
}'::jsonb),
('driver', '{
  "id": "driver-002",
  "name": "Thabo Molefe",
  "license": "EC 87654321",
  "phone": "+27 79 444 5566",
  "transporter_id": "transporter-001",
  "transporter_name": "Barloworld Transport",
  "years_experience": 8
}'::jsonb),
('trip', '{
  "id": "demo-trip-001",
  "origin_mine": "Sishen Iron Ore",
  "destination_buyer": "ArcelorMittal SA",
  "product": "Iron Ore (62% Fe)",
  "tons": 34,
  "status": "loaded",
  "truck_registration": "HMV 847 GP",
  "driver_name": "Sipho Ndlovu",
  "transporter_name": "Barloworld Transport",
  "departure_time": "2026-07-17T06:30:00Z",
  "eta": "2026-07-17T14:00:00Z",
  "distance_km": 680
}'::jsonb),
('stockpile', '{
  "id": "demo-stockpile-001",
  "mine_name": "Sishen Iron Ore",
  "product": "Iron Ore (62% Fe)",
  "current_tons": 217,
  "capacity_tons": 500,
  "fill_percent": 43.4,
  "buyer_name": "ArcelorMittal SA",
  "last_updated": "2026-07-17T09:15:00Z"
}'::jsonb),
('road_request', '{
  "id": "demo-road-001",
  "mine_name": "Mogalakwena Platinum Mine",
  "status": "requested",
  "requested_at": "2026-07-14T10:00:00Z",
  "description": "Internal haul roads — north pit to crusher, 4.2 km",
  "file_format": "DXF",
  "requested_by": "Mine Supervisor"
}'::jsonb)
on conflict (category, (json_data ->> 'id')) do nothing;
