-- S9-6 — the live map's `stationary_since` read every position a truck ever
-- recorded, once per active trip, on every refresh.
--
-- `list_live_trip_positions` has two laterals over `vehicle_positions`. The
-- first one, `vp`, asks for the newest position and is O(1) — `order by
-- recorded_at desc limit 1` walks straight down the existing
-- `vehicle_positions_vehicle_id_idx (vehicle_id, recorded_at desc)` index.
--
-- The second one, `mot`, computed `stationary_since` as
--
--     min(p.recorded_at) FILTER (where p.recorded_at > <last moving ping>)
--     from vehicle_positions p where p.vehicle_id = t.vehicle_id
--
-- A `FILTER` clause is applied per row *after* the rows are read, so the
-- predicate is not a range bound the index can use: the aggregate has to read
-- every row the vehicle has ever recorded. The driver app pings every 30s, so
-- one truck accumulates 2,880 rows a day and nothing on this platform deletes
-- them (there is no retention job — see the S9-9 retention note). The lateral
-- then runs once per active trip, on a screen that is realtime-refreshed.
--
-- Measured on the live project 2026-08-15, in a rolled-back transaction, with
-- 100,000 pings for one vehicle (= 34.7 days at the real 30s cadence):
--
--   scenario                       current        this migration
--   ---------------------------    ------------   --------------
--   moving every ~20 min           1,435 buffers  9 buffers
--                                  25.3 ms        0.050 ms
--   parked ~34 days (see below)    (seq scan)     9 buffers / 0.070 ms
--
-- Both changes below are needed, and each was measured separately rather than
-- added on principle:
--
-- 1. MOVE THE PREDICATE FROM `FILTER` INTO `WHERE`. This is what makes it an
--    index range scan instead of a full read: 1,435 buffers -> 10, 25.3 ms ->
--    0.061 ms. `min(x) FILTER (WHERE c)` and `min(x) ... WHERE c` return the
--    same value — including NULL when nothing matches — so this is a
--    behaviour-preserving rewrite, and it was verified as one: the old and new
--    expressions returned the identical timestamp under both fixtures.
--
-- 2. ADD A PARTIAL INDEX FOR THE "last moving ping" LOOKUP. The rewrite alone
--    is not enough for a truck that has been parked a long time: the inner
--    `max(recorded_at) where speed_kmh >= 5` has to walk back over every
--    stationary row before it finds a moving one, because `speed_kmh` is not
--    in the existing index. With the truck last moving ~34 days ago the
--    rewrite still cost 2,922 buffers / 25.0 ms; with this index, 9 buffers /
--    0.070 ms. Under the first fixture the index was worth almost nothing
--    (10 -> 9 buffers), so it is included on the strength of the second
--    measurement only.
--
--    It is partial (`where speed_kmh >= 5`) rather than a plain composite so
--    that stationary pings — the large majority of rows for a parked truck —
--    are not indexed at all, keeping the write cost of a 30s insert cadence
--    proportional to the moving rows it actually has to serve.
--
-- Not addressed here, and deliberately: `vehicle_positions` still has no
-- retention policy, so the table grows without bound at ~2,880 rows per active
-- truck per day. That is a data-lifecycle decision for the client (the
-- retention periods in docs/legal/DATA-RETENTION.placeholder.md are still
-- unfilled), not something to pick unilaterally. This migration makes the read
-- path independent of how large the history gets, which is the part that does
-- not need a ruling.

create index if not exists vehicle_positions_moving_idx
  on public.vehicle_positions (vehicle_id, recorded_at desc)
  where speed_kmh >= 5;

comment on index public.vehicle_positions_moving_idx is
  'S9-6: serves the "when did this truck last move" lookup inside '
  'list_live_trip_positions. Partial so a parked truck''s stationary pings '
  'are not indexed. Without it that lookup walks every stationary row: '
  'measured 2,922 buffers vs 9 for a truck parked ~34 days.';

create or replace function public.list_live_trip_positions(p_company_id uuid default null::uuid)
 returns table(trip_id uuid, trip_status text, vehicle_id uuid, truck_reg text, transporter_name text, supplier_name text, buyer_name text, loading_point text, offloading_point text, lat double precision, lng double precision, heading double precision, speed_kmh double precision, recorded_at timestamp with time zone, driver_name text, driver_phone text, stationary_since timestamp with time zone, trip_created_at timestamp with time zone, arrived_at timestamp with time zone, loading_at timestamp with time zone, loaded_at timestamp with time zone, left_at timestamp with time zone, offloaded_at timestamp with time zone, nav_instruction text, nav_eta timestamp with time zone, nav_original_eta timestamp with time zone, nav_time_left_s integer, nav_distance_left_m integer, nav_speed_kmh double precision, nav_started_at timestamp with time zone, nav_route_polyline text, nav_updated_at timestamp with time zone)
 language sql
 stable security definer
 set search_path to 'public'
as $function$
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
    mot.stationary_since,
    t.created_at as trip_created_at,
    t.arrived_at,
    t.loading_at,
    t.loaded_at,
    t.left_at,
    t.offloaded_at,
    ns.current_instruction as nav_instruction,
    ns.eta as nav_eta,
    ns.original_eta as nav_original_eta,
    ns.time_left_s as nav_time_left_s,
    ns.distance_left_m as nav_distance_left_m,
    ns.speed_kmh as nav_speed_kmh,
    ns.nav_started_at,
    ns.route_polyline as nav_route_polyline,
    ns.updated_at as nav_updated_at
  from public.trips t
  join public.transactions txn on txn.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.request_dispatches d on d.id = t.dispatch_id
  left join public.transportation_requests r on r.id = d.request_id
  left join public.companies tc on tc.id = txn.transporter_company_id
  left join public.companies sc on sc.id = txn.supplier_company_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  left join public.trip_nav_state ns on ns.trip_id = t.id
  left join lateral (
    select p.lat, p.lng, p.heading, p.speed_kmh, p.recorded_at
    from public.vehicle_positions p
    where p.vehicle_id = t.vehicle_id
    order by p.recorded_at desc
    limit 1
  ) vp on true
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
  left join lateral (
    -- The predicate is in WHERE, not in a FILTER on the aggregate, so it is a
    -- range bound the (vehicle_id, recorded_at desc) index can use. As a
    -- FILTER this read every position the vehicle had ever recorded. Same
    -- result either way — verified equal on the live project — but 1,435
    -- buffers became 9. See the header of this migration.
    select min(p.recorded_at) as stationary_since
    from public.vehicle_positions p
    where p.vehicle_id = t.vehicle_id
      and p.recorded_at > coalesce(
        (select max(p2.recorded_at)
         from public.vehicle_positions p2
         where p2.vehicle_id = t.vehicle_id
           and p2.speed_kmh is not null
           and p2.speed_kmh >= 5),
        '-infinity'::timestamptz)
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
$function$;
