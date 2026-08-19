-- A sealed load needs every seal the rig has, not "at least one".
--
-- Found by driving a seal-required load end to end on 2026-08-17. The Load
-- Controller's sheet is headed
--
--     Seals (2 per trailer · 4 total)
--
-- and renders four numbered slots. `record_truck_load` accepted the load with
-- TWO. Measured on the two seal-required loads in production:
--
--     seals on load | loads
--     --------------+------
--                 2 |     1
--                13 |     1
--
-- Two on a rig with two trailers, and thirteen on another — on routes whose
-- whole purpose is that the load is sealed. The only server rule was "not
-- zero", plus "each seal you DO send needs a number and a photo". Neither
-- bounds the count, so the app states a requirement it does not keep, in both
-- directions.
--
-- The consequence is not cosmetic. The waybill prints TRUCK SEAL SERIAL NO.
-- 1-4 (CLAUDE.md §4), so a load sealed at four points and recorded at two
-- hands the driver a document naming half the seals on the truck. At the
-- receiving end the two that are not on the paper cannot be checked, and a
-- broken one cannot be told from one that was never written down. That is the
-- exact failure sealing exists to prevent.
--
-- THE RULE: two seals per trailer the vehicle actually has.
--
-- Derived from the rig rather than hardcoded, because "4" is only right for a
-- two-trailer interlink. Measured today, all 7 active vehicles carry both
-- `first_trailer_regs` and `second_trailer_regs`, so 4 is correct for the
-- entire current fleet and this blocks nothing that is being done properly —
-- but a rigid or single-trailer truck would have been told to fit four seals
-- to a vehicle with two seal points.
--
-- Floored at 2 and capped at 4:
--   * floor 2  — a vehicle with no trailer registration recorded is a data
--                gap, not an unsealed load; refusing to seal it at all would
--                be worse than requiring the minimum.
--   * cap 4    — the waybill has exactly four serial lines. Accepting a fifth
--                seal means recording one the document cannot carry, which is
--                how thirteen got in.
--
-- ⚠ RAISED WITH JEAN. "Two per trailer" is read from the app's own heading and
-- confirmed against the fleet; it is not a rule anybody has stated to me. If
-- the real operating rule differs — one per trailer door, four per trailer, a
-- number that varies by commodity — this function is the single place to
-- change it, and the client reads the same number rather than repeating it.

begin;

-- How many seals this vehicle must carry. Null vehicle -> the floor, so a trip
-- with no vehicle attached still demands a sealed load rather than none.
create or replace function public.expected_seal_count(p_vehicle_id uuid)
returns int
language sql
stable
as $$
  select greatest(2, least(4,
    2 * coalesce((
      select (case when coalesce(trim(v.first_trailer_regs), '') <> '' then 1 else 0 end)
           + (case when coalesce(trim(v.second_trailer_regs), '') <> '' then 1 else 0 end)
      from public.fleet_vehicles v where v.id = p_vehicle_id
    ), 1)
  ));
$$;

comment on function public.expected_seal_count(uuid) is
  'Seals a sealed load must carry on this vehicle: two per trailer present, '
  'floored at 2 (missing trailer data is a data gap, not an unsealed load) and '
  'capped at 4 (the waybill has four serial lines). The Load Controller''s '
  'sheet renders exactly this many slots and record_truck_load enforces it; '
  'before 2026-08-17 neither did, and loads were recorded with 2 seals and '
  'with 13 on routes that require them.';

grant execute on function public.expected_seal_count(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- The Load Controller's queue carries the number, so the sheet can render the
-- right slots and say the right thing instead of a hardcoded "4 total".
--
-- Adding an OUT column is a return-type change: `create or replace` cannot do
-- it (42P13), so the drop is mandatory and not housekeeping. See CLAUDE.md §6.
-- ---------------------------------------------------------------------------
drop function if exists public.list_mine_inbound_trips(uuid);

create function public.list_mine_inbound_trips(p_supplier_company_id uuid)
returns table (
  trip_id uuid, status text, vehicle_id uuid, truck_reg text, route_id uuid,
  seal_required boolean, expected_seals int, net_tons numeric,
  tare_tons numeric, gross_tons numeric, loading_at timestamptz,
  transaction_id uuid, buyer_company_id uuid, buyer_name text,
  transporter_name text, commodity text, reference text,
  offloading_point text, loading_point text, updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
  select
    t.id, t.status, t.vehicle_id,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    t.route_id, coalesce(rt.seal_required, false),
    public.expected_seal_count(t.vehicle_id),
    t.net_tons,
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
$$;

grant execute on function public.list_mine_inbound_trips(uuid) to authenticated;

commit;
