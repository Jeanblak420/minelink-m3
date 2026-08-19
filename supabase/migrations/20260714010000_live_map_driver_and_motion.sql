-- Live map hover card (CLAUDE.md §4 "Live trip GPS tracking / ETA").
--
-- The super-admin/org live map now reveals a rich info card when a truck marker
-- is hovered. It needs three things the feed did not yet return:
--   * driver_name      — every driver assigned to the trip's truck (comma-joined,
--                        primary first) so the card can name who is behind the wheel.
--   * driver_phone     — the primary (oldest-assigned) driver's WhatsApp number.
--   * stationary_since — the instant the truck last dropped below the ~5 km/h
--                        "moving" threshold, so the card can show how long it has
--                        been standing still. Null while it is still moving.
--
-- Read-side only: this replaces list_live_trip_positions() with the same
-- party-scoping and filters, extended with the three columns. No table or policy
-- changes. speed_kmh (already returned) is what the client uses to decide
-- moving vs stationary; stationary_since supplies the duration.

begin;

drop function if exists public.list_live_trip_positions(uuid);
create function public.list_live_trip_positions(p_company_id uuid default null)
returns table (
  trip_id uuid,
  trip_status text,
  vehicle_id uuid,
  truck_reg text,
  transporter_name text,
  supplier_name text,
  buyer_name text,
  loading_point text,
  offloading_point text,
  lat double precision,
  lng double precision,
  heading double precision,
  speed_kmh double precision,
  recorded_at timestamptz,
  driver_name text,
  driver_phone text,
  stationary_since timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    t.id as trip_id,
    t.status as trip_status,
    t.vehicle_id,
    coalesce(fv.vehicle_registration_number, t.metadata->>'truck_reg') as truck_reg,
    tc.company_name as transporter_name,
    sc.company_name as supplier_name,
    bc.company_name as buyer_name,
    coalesce(r.loading_point, txn.metadata->>'loading_point', t.metadata->>'loading_point') as loading_point,
    coalesce(r.offloading_point, txn.metadata->>'offloading_point', t.metadata->>'offloading_point') as offloading_point,
    vp.lat,
    vp.lng,
    vp.heading,
    vp.speed_kmh,
    vp.recorded_at,
    drv.names as driver_name,
    drv.primary_phone as driver_phone,
    mot.stationary_since
  from public.trips t
  join public.transactions txn on txn.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.request_dispatches d on d.id = t.dispatch_id
  left join public.transportation_requests r on r.id = d.request_id
  left join public.companies tc on tc.id = txn.transporter_company_id
  left join public.companies sc on sc.id = txn.supplier_company_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  left join lateral (
    select p.lat, p.lng, p.heading, p.speed_kmh, p.recorded_at
    from public.vehicle_positions p
    where p.vehicle_id = t.vehicle_id
    order by p.recorded_at desc
    limit 1
  ) vp on true
  -- Assigned driver(s) for the truck (primary = oldest assignment first).
  left join lateral (
    select
      nullif(string_agg(
        nullif(trim(coalesce(e.first_name, '') || ' ' || coalesce(e.last_name, '')), ''),
        ', ' order by da.created_at
      ), '') as names,
      (array_agg(e.whatsapp_number order by da.created_at))[1] as primary_phone
    from public.driver_assignments da
    join public.employees e on e.id = da.driver_employee_id
    where da.vehicle_id = t.vehicle_id
  ) drv on true
  -- When the truck last stopped: the first ping after its most recent "moving"
  -- (>= 5 km/h) sample. Null when it is still moving (no ping after that point).
  left join lateral (
    select min(p.recorded_at) filter (
      where p.recorded_at > coalesce(
        (select max(p2.recorded_at)
         from public.vehicle_positions p2
         where p2.vehicle_id = t.vehicle_id
           and p2.speed_kmh is not null
           and p2.speed_kmh >= 5),
        '-infinity'::timestamptz)
    ) as stationary_since
    from public.vehicle_positions p
    where p.vehicle_id = t.vehicle_id
  ) mot on true
  where t.status not in ('completed', 'cancelled')
    and t.vehicle_id is not null
    and (
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
  order by t.updated_at desc;
$$;

revoke all on function public.list_live_trip_positions(uuid) from public;
revoke all on function public.list_live_trip_positions(uuid) from anon;
grant execute on function public.list_live_trip_positions(uuid) to authenticated;

commit;
