-- Phase 3 — Mine field screens on real trips (§2 wiring).
-- A read RPC that returns the trips inbound to a mine (where the mine is the
-- supplier party), joined with the display fields the Security check-in and
-- Load Controller screens need. SECURITY DEFINER with an explicit staff check
-- so the joins are reliable regardless of per-table RLS nuance. Additive.

create or replace function public.list_mine_inbound_trips(p_supplier_company_id uuid)
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
  updated_at timestamptz
)
language sql security definer set search_path = public as $$
  select
    t.id,
    t.status,
    t.vehicle_id,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    t.route_id,
    coalesce(hr.seal_required, false),
    t.net_tons,
    tx.id,
    tx.buyer_company_id,
    bc.company_name,
    tc.company_name,
    coalesce(nullif(tx.metadata->>'commodity', ''), m.name),
    t.updated_at
  from public.trips t
  join public.transactions tx on tx.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.haul_routes hr on hr.id = t.route_id
  left join public.companies bc on bc.id = tx.buyer_company_id
  left join public.companies tc on tc.id = tx.transporter_company_id
  left join public.minerals m on m.id = tx.mineral_id
  where tx.supplier_company_id = p_supplier_company_id
    and public.is_company_staff(p_supplier_company_id)
  order by t.updated_at desc
  limit 200;
$$;

grant execute on function public.list_mine_inbound_trips(uuid) to authenticated;
