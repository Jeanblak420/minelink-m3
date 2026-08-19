-- Fleet availability state machine (CLAUDE.md §4 "Transporter admin: accept
-- route → allocate fleet & drivers").
--
-- A truck is "On Route" while it has an active (not completed/cancelled) trip,
-- and "Available" otherwise. Availability is DERIVED from `trips` — there is no
-- stored status column to drift, and a truck frees up automatically the moment
-- its trip completes (record_pod) or is cancelled. Its assigned driver follows
-- the same state (one embedded driver per vehicle today; multi-driver 2–5 is a
-- later change).
--
-- This migration:
--   1. Guards accept_request_dispatch so an already-on-route truck can't be
--      double-booked (server-side enforcement of the state machine).
--   2. Adds list_transporter_fleet_status(company) — each truck with an
--      on_route flag + its current route detail. Powers both the "assign
--      available trucks" picker (on_route = false) and the "Trucks On Route"
--      screen (on_route = true).

begin;

-- 1. Re-create accept_request_dispatch with an availability guard. Body is the
--    existing function plus the "already on a route" check inside the loop.
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

  foreach v_vid in array p_vehicle_ids loop
    select * into v_vehicle from public.fleet_vehicles where id = v_vid;
    if not found or v_vehicle.company_id <> v_dispatch.transporter_company_id then
      raise exception 'Truck % is not in your fleet', v_vid;
    end if;

    -- State machine: a truck already on an active trip is On Route and cannot
    -- be assigned again until that trip completes.
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

    insert into public.trips (transaction_id, vehicle_id, status, dispatch_id, metadata)
    values (
      v_txn_id, v_vid, 'scheduled', p_dispatch_id,
      jsonb_build_object('truck_reg', v_vehicle.vehicle_registration_number)
    );
  end loop;

  update public.request_dispatches set status = 'accepted'
  where id = p_dispatch_id
  returning * into v_dispatch;
  return v_dispatch;
end;
$function$;

-- 2. Fleet availability listing. SECURITY DEFINER with an explicit company-staff
--    guard so only the transporter's own staff can read their fleet's status.
create or replace function public.list_transporter_fleet_status(p_company_id uuid)
returns table (
  vehicle_id uuid,
  registration text,
  make text,
  vehicle_type text,
  driver_employee_id uuid,
  driver_name text,
  is_active boolean,
  on_route boolean,
  active_trip_id uuid,
  trip_status text,
  buyer_name text,
  commodity text,
  offloading_point text,
  loading_point text
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    v.id,
    v.vehicle_registration_number,
    v.vehicle_make,
    v.vehicle_type,
    v.assigned_driver_employee_id,
    nullif(trim(coalesce(v.driver_first_name, '') || ' ' || coalesce(v.driver_last_name, '')), ''),
    v.is_active,
    (t.id is not null) as on_route,
    t.id,
    t.status,
    bc.company_name,
    coalesce(txn.metadata->>'commodity', ''),
    coalesce(txn.metadata->>'offloading_point', ''),
    coalesce(txn.metadata->>'loading_point', '')
  from public.fleet_vehicles v
  left join lateral (
    select tr.id, tr.status, tr.transaction_id
    from public.trips tr
    where tr.vehicle_id = v.id
      and tr.status not in ('completed', 'cancelled')
    order by tr.created_at desc
    limit 1
  ) t on true
  left join public.transactions txn on txn.id = t.transaction_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  where v.company_id = p_company_id
    and public.is_company_staff(p_company_id)
  order by (t.id is not null), v.vehicle_registration_number;
$function$;

revoke all on function public.list_transporter_fleet_status(uuid) from public;
revoke all on function public.list_transporter_fleet_status(uuid) from anon;
grant execute on function public.list_transporter_fleet_status(uuid) to authenticated;

commit;
