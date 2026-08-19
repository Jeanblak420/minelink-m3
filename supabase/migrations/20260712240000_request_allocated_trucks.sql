-- Buyer-visible truck allocation (CLAUDE.md §4: "The linked buyer can see the
-- trucks the transporter allocated to fulfil their request").
--
-- Per request: every trip created when a transporter accepted the dispatch,
-- with the truck registration, its assigned drivers, the transporter and the
-- live trip status. Scoped to the request's parties (buyer, mine, dispatched
-- transporters) or the platform admin.

begin;

create or replace function public.list_request_allocated_trucks(p_request_id uuid)
returns table (
  trip_id uuid,
  truck_reg text,
  transporter_name text,
  drivers text,
  trip_status text,
  created_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    t.id,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    tc.company_name,
    drv.names,
    t.status,
    t.created_at
  from public.request_dispatches d
  join public.transportation_requests r on r.id = d.request_id
  join public.trips t on t.dispatch_id = d.id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.companies tc on tc.id = d.transporter_company_id
  left join lateral (
    select string_agg(
      nullif(trim(coalesce(e.first_name, '') || ' ' || coalesce(e.last_name, '')), ''),
      ', ' order by da.created_at
    ) as names
    from public.driver_assignments da
    join public.employees e on e.id = da.driver_employee_id
    where da.vehicle_id = t.vehicle_id
  ) drv on true
  where d.request_id = p_request_id
    and (
      public.is_platform_admin()
      or public.is_company_staff(r.buyer_company_id)
      or public.is_company_staff(r.supplier_company_id)
      or public.is_company_staff(d.transporter_company_id)
    )
  order by tc.company_name, 2;
$function$;

revoke all on function public.list_request_allocated_trucks(uuid) from public;
revoke all on function public.list_request_allocated_trucks(uuid) from anon;
grant execute on function public.list_request_allocated_trucks(uuid) to authenticated;

commit;
