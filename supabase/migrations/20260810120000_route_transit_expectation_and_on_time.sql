-- Route transit expectation, and the on-time measure that stands on it.
--
-- The transporters leaderboard ranks hauliers with an ON-TIME column. Nothing
-- in this schema could answer it: `trips` records only what happened
-- (arrived_at, loading_at, loaded_at, left_at, offloaded_at, completed_at) and
-- `routes` records where and under what terms, never by when. A percentage
-- with no promise behind it is not a late delivery being reported — it is a
-- number invented to fill a column, which is exactly what the drop's
-- hardcoded "96%" was.
--
-- So the promise gets recorded.
--
-- THE CONTRACT
--   due_at  = trips.left_at + routes.expected_transit_hours
--   on time = trips.offloaded_at <= due_at
--
-- Measured from GATE-OUT, not from dispatch or from arrival at the mine. Time
-- a truck spends queueing and loading at the mine belongs to the mine, and is
-- already measured separately as turnaround (time-in → time-out on the recon
-- rows). What a transporter answers for is the haul: wheels rolling off the
-- weighbridge to tipping at the offloading point. Judging them on the mine's
-- queue would rank whichever hauler happened to draw the quieter loading bay.
--
-- UNSET IS UNDEFINED, NEVER ZERO. A route with no expectation, a trip that has
-- not left, and a trip that has not offloaded are all unjudgeable, and every
-- reader must render them as "no measure yet" rather than as a miss. The
-- bundle therefore returns the numerator AND the denominator per company
-- (on_time_trips / due_trips) instead of a percentage: only the caller holding
-- both can tell 0-of-0 apart from 0-of-9. Same discipline as
-- monthly_targets.target_tons = 0 meaning "not set".

-- ---------------------------------------------------------------------------
-- 1. The expectation itself
-- ---------------------------------------------------------------------------

alter table public.routes
  add column if not exists expected_transit_hours numeric;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'routes_expected_transit_hours_sane'
  ) then
    alter table public.routes
      add constraint routes_expected_transit_hours_sane
      check (
        expected_transit_hours is null
        or (expected_transit_hours > 0 and expected_transit_hours <= 720)
      );
  end if;
end $$;

comment on column public.routes.expected_transit_hours is
  'Agreed gate-out-to-offload transit time for this route, in hours. NULL means '
  'no expectation has been agreed, and every trip on the route is unjudgeable '
  'for on-time — read as "no measure", never as late. Set only by a platform '
  'admin via set_route_transit_expectation(): it is the yardstick a transporter '
  'is ranked by, so a party to the haul must not be able to move it. Capped at '
  '720h (30 days) to catch a minutes-entered-as-hours slip.';

-- ---------------------------------------------------------------------------
-- 2. Setting it
-- ---------------------------------------------------------------------------

create or replace function public.set_route_transit_expectation(
  p_route_id uuid,
  p_hours numeric
) returns void
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  if not public.is_super_admin() then
    raise exception 'forbidden' using errcode = 'insufficient_privilege';
  end if;
  if not exists (select 1 from public.routes where id = p_route_id) then
    raise exception 'unknown route %', p_route_id;
  end if;
  -- NULL clears the expectation, which returns the route's trips to
  -- unjudgeable. That is a legitimate action (an agreement lapsed), not an
  -- error, so it is allowed rather than forced through a delete.
  if p_hours is not null and (p_hours <= 0 or p_hours > 720) then
    raise exception 'transit expectation must be between 0 and 720 hours';
  end if;

  update public.routes set expected_transit_hours = p_hours where id = p_route_id;
end $function$;

grant execute on function public.set_route_transit_expectation(uuid, numeric)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Reading it — one trip's verdict, in one place
-- ---------------------------------------------------------------------------

-- Every reader must agree on what "on time" means, so the rule lives here and
-- nowhere else. Returns NULL for unjudgeable, which is what keeps a route with
-- no agreed transit time out of the denominator.
create or replace function public.trip_is_on_time(
  p_left_at timestamptz,
  p_offloaded_at timestamptz,
  p_expected_transit_hours numeric
) returns boolean
language sql
immutable
as $function$
  select case
    when p_expected_transit_hours is null then null
    when p_left_at is null then null
    when p_offloaded_at is null then null
    else p_offloaded_at <= p_left_at + make_interval(secs => p_expected_transit_hours * 3600)
  end;
$function$;

comment on function public.trip_is_on_time(timestamptz, timestamptz, numeric) is
  'The single definition of on-time: offloaded no later than gate-out plus the '
  'route''s agreed transit hours. NULL = unjudgeable (no expectation agreed, '
  'not yet departed, or not yet offloaded) and must never be counted as late.';

-- ---------------------------------------------------------------------------
-- 4. The insights bundle carries it, so every column shares one window
-- ---------------------------------------------------------------------------
--
-- Recreated verbatim from the live definition with exactly one addition per
-- company (on_time_trips / due_trips) and their aggregate sums. Adding it here
-- rather than in a second RPC is deliberate: the leaderboard's on-time column
-- has to be scoped by the SAME range as its tons, trips and waybill columns,
-- and two round trips against two windows is how a table starts disagreeing
-- with itself.

create or replace function public.super_admin_monthly_insights_bundle(
  p_org_type text,
  p_range_start timestamptz,
  p_range_end timestamptz
) returns jsonb
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  companies_json jsonb := '[]'::jsonb;
  agg jsonb;
  r record;
  cid uuid;
  emp_n int;
  drv_n int;
  fleet_n int;
  loads_n int;
  tons_n numeric;
  comp_wb int;
  pend_wb int;
  trips_n int;
  routes_n int;
  ontime_n int;
  due_n int;
  company_row jsonb;
  sum_trips bigint := 0;
  sum_fleet bigint := 0;
  sum_tons numeric := 0;
  sum_loads bigint := 0;
  sum_comp bigint := 0;
  sum_pend bigint := 0;
  sum_ontime bigint := 0;
  sum_due bigint := 0;
begin
  if not public.is_super_admin() then
    raise exception 'forbidden';
  end if;

  if p_org_type is null or p_org_type !~ '^(transporter|buyer|mineSupplier)$' then
    raise exception 'invalid org type';
  end if;

  for r in
    select id, company_name, org_type
    from public.companies
    where org_type = p_org_type
    order by company_name
  loop
    cid := r.id;

    select count(*)::int into emp_n from public.employees where company_id = cid;
    select count(*)::int into drv_n from public.employees where company_id = cid and role = 'driver';
    select count(*)::int into fleet_n from public.fleet_vehicles where company_id = cid;

    -- Loads / waybill status counts stay on transactions (unchanged).
    if p_org_type = 'transporter' then
      select
        count(*)::int,
        count(*) filter (where lower(trim(coalesce(status, ''))) = 'completed')::int,
        count(*) filter (where lower(trim(coalesce(status, ''))) is distinct from 'completed')::int
      into loads_n, comp_wb, pend_wb
      from public.transactions
      where updated_at >= p_range_start
        and updated_at <= p_range_end
        and transporter_company_id = cid;
    elsif p_org_type = 'buyer' then
      select
        count(*)::int,
        count(*) filter (where lower(trim(coalesce(status, ''))) = 'completed')::int,
        count(*) filter (where lower(trim(coalesce(status, ''))) is distinct from 'completed')::int
      into loads_n, comp_wb, pend_wb
      from public.transactions
      where updated_at >= p_range_start
        and updated_at <= p_range_end
        and buyer_company_id = cid;
    else
      select
        count(*)::int,
        count(*) filter (where lower(trim(coalesce(status, ''))) = 'completed')::int,
        count(*) filter (where lower(trim(coalesce(status, ''))) is distinct from 'completed')::int
      into loads_n, comp_wb, pend_wb
      from public.transactions
      where updated_at >= p_range_start
        and updated_at <= p_range_end
        and supplier_company_id = cid;
    end if;

    -- Trips count AND real tons moved (weighbridge net mass) come from trips.
    -- net_tons is null until the Load Controller records the load, so unloaded
    -- trips contribute 0 via coalesce.
    select
      count(*)::int,
      coalesce(sum(t.net_tons), 0)::numeric
    into trips_n, tons_n
    from public.trips t
    join public.transactions x on x.id = t.transaction_id
    where t.updated_at >= p_range_start
      and t.updated_at <= p_range_end
      and (
        (p_org_type = 'transporter' and x.transporter_company_id = cid)
        or (p_org_type = 'buyer' and x.buyer_company_id = cid)
        or (p_org_type = 'mineSupplier' and x.supplier_company_id = cid)
      );

    select coalesce(count(distinct t.route_id) filter (where t.route_id is not null), 0)::int into routes_n
    from public.trips t
    join public.transactions x on x.id = t.transaction_id
    where t.updated_at >= p_range_start
      and t.updated_at <= p_range_end
      and (
        (p_org_type = 'transporter' and x.transporter_company_id = cid)
        or (p_org_type = 'buyer' and x.buyer_company_id = cid)
        or (p_org_type = 'mineSupplier' and x.supplier_company_id = cid)
      );

    -- On-time. `due_n` counts only the judgeable trips — route expectation
    -- agreed, departed, and offloaded — so a company with no agreed transit
    -- times reports 0 of 0 and its reader shows a dash, not 0%.
    select
      count(*) filter (
        where public.trip_is_on_time(t.left_at, t.offloaded_at, rt.expected_transit_hours))::int,
      count(*) filter (
        where public.trip_is_on_time(t.left_at, t.offloaded_at, rt.expected_transit_hours) is not null)::int
    into ontime_n, due_n
    from public.trips t
    join public.transactions x on x.id = t.transaction_id
    left join public.routes rt on rt.id = t.route_id
    where t.updated_at >= p_range_start
      and t.updated_at <= p_range_end
      and (
        (p_org_type = 'transporter' and x.transporter_company_id = cid)
        or (p_org_type = 'buyer' and x.buyer_company_id = cid)
        or (p_org_type = 'mineSupplier' and x.supplier_company_id = cid)
      );

    company_row := jsonb_build_object(
      'company_id', cid,
      'company_name', r.company_name,
      'org_type', r.org_type,
      'fleet_vehicles', fleet_n,
      'drivers', drv_n,
      'employees', emp_n,
      'routes_distinct', routes_n,
      'trips', trips_n,
      'loads_count', loads_n,
      'tons_moved', tons_n,
      'completed_waybills', comp_wb,
      'pending_waybills', pend_wb,
      'on_time_trips', ontime_n,
      'due_trips', due_n
    );

    companies_json := companies_json || jsonb_build_array(company_row);

    sum_trips := sum_trips + trips_n;
    sum_fleet := sum_fleet + fleet_n;
    sum_tons := sum_tons + tons_n;
    sum_loads := sum_loads + loads_n;
    sum_comp := sum_comp + comp_wb;
    sum_pend := sum_pend + pend_wb;
    sum_ontime := sum_ontime + ontime_n;
    sum_due := sum_due + due_n;
  end loop;

  agg := jsonb_build_object(
    'org_type', p_org_type,
    'company_count', jsonb_array_length(companies_json),
    'active_trips_approx', sum_trips,
    'fleet_vehicles_total', sum_fleet,
    'tons_moved', sum_tons,
    'transactions_total', sum_loads,
    'completed_waybills', sum_comp,
    'pending_waybills', sum_pend,
    'on_time_trips', sum_ontime,
    'due_trips', sum_due
  );

  return jsonb_build_object(
    'companies', companies_json,
    'aggregate', agg,
    'range_start', to_jsonb(p_range_start),
    'range_end', to_jsonb(p_range_end)
  );
end;
$function$;
