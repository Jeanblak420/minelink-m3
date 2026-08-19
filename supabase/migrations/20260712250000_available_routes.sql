-- Available routes + transporter route marketplace (CLAUDE.md §4).
--
-- Dispatched routes are already remembered as `routes` rows (the learned
-- Route IDs). This adds:
--   1. `route_assignments` — the super-admin assigns an available route to a
--      requesting org (buyer or mine/supplier), optionally permanently. The
--      org sees it under "Available routes" and can use it to auto-fill the
--      Request Route form.
--   2. Admin RPCs: list all routes with their assignments, assign/unassign.
--   3. `list_my_available_routes` — the org's own assigned routes (definer,
--      because the org may be none of the route's parties).
--   4. `list_route_marketplace` — every route each transporter accepted,
--      with delivery stats. SUPER-ADMIN ONLY for now (the UI carries the
--      "will become public" note).

begin;

create table if not exists public.route_assignments (
  id uuid primary key default gen_random_uuid(),
  route_id uuid not null references public.routes(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete cascade,
  permanent boolean not null default false,
  assigned_by uuid,
  created_at timestamptz not null default timezone('utc', now()),
  unique (route_id, company_id)
);

alter table public.route_assignments enable row level security;

drop policy if exists route_assignments_select on public.route_assignments;
create policy route_assignments_select
on public.route_assignments
for select
to authenticated
using (public.is_company_staff(company_id) or public.is_platform_admin());
-- Writes only via the RPCs below.

-- 1. Admin: every learned route + who it's assigned to.

create or replace function public.list_available_routes()
returns table (
  route_id uuid,
  route_number text,
  commodity text,
  loading_point text,
  offloading_point text,
  payment_terms text,
  tons text,
  num_trucks text,
  supplier_name text,
  buyer_name text,
  created_at timestamptz,
  assigned_companies text
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    rt.id, rt.route_number, rt.commodity, rt.loading_point, rt.offloading_point,
    rt.payment_terms, rt.tons, rt.num_trucks,
    sc.company_name, bc.company_name, rt.created_at,
    (
      select string_agg(
        c.company_name || case when ra.permanent then ' (permanent)' else '' end,
        ', ' order by ra.created_at
      )
      from public.route_assignments ra
      join public.companies c on c.id = ra.company_id
      where ra.route_id = rt.id
    )
  from public.routes rt
  left join public.companies sc on sc.id = rt.supplier_company_id
  left join public.companies bc on bc.id = rt.buyer_company_id
  where public.is_platform_admin()
  order by rt.created_at desc;
$$;

revoke all on function public.list_available_routes() from public;
revoke all on function public.list_available_routes() from anon;
grant execute on function public.list_available_routes() to authenticated;

-- 2. Admin: assign / unassign a route to an org.

create or replace function public.assign_route_to_company(
  p_route_id uuid,
  p_company_id uuid,
  p_permanent boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  assignment public.route_assignments;
  route_record public.routes;
begin
  if not public.is_platform_admin() then
    raise exception 'Only the platform admin may assign available routes';
  end if;
  select * into route_record from public.routes where id = p_route_id;
  if route_record.id is null then
    raise exception 'Route not found';
  end if;
  if not exists (select 1 from public.companies where id = p_company_id) then
    raise exception 'Company not found';
  end if;

  insert into public.route_assignments (route_id, company_id, permanent, assigned_by)
  values (p_route_id, p_company_id, coalesce(p_permanent, false), auth.uid())
  on conflict (route_id, company_id) do update
    set permanent = excluded.permanent
  returning * into assignment;

  -- Best-effort: tell the org an available route landed on their dashboard.
  begin
    perform public.notify_company_management(
      p_company_id,
      'New available route',
      'Route ' || route_record.route_number || ' ('
        || coalesce(route_record.loading_point, '—') || ' → '
        || coalesce(route_record.offloading_point, '—')
        || ') is now available to you. Select it under Available routes to '
        || 'pre-fill a transportation request.',
      'availableRouteAssigned',
      null,
      auth.uid(),
      'normal',
      jsonb_build_object('route_id', p_route_id, 'permanent', assignment.permanent)
    );
  exception when others then
    null;
  end;

  return to_jsonb(assignment);
end;
$$;

revoke all on function public.assign_route_to_company(uuid, uuid, boolean) from public;
revoke all on function public.assign_route_to_company(uuid, uuid, boolean) from anon;
grant execute on function public.assign_route_to_company(uuid, uuid, boolean) to authenticated;

create or replace function public.unassign_route_from_company(
  p_route_id uuid,
  p_company_id uuid
)
returns void
language plpgsql
security definer
set search_path to 'public'
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Only the platform admin may unassign available routes';
  end if;
  delete from public.route_assignments
  where route_id = p_route_id and company_id = p_company_id;
end;
$$;

revoke all on function public.unassign_route_from_company(uuid, uuid) from public;
revoke all on function public.unassign_route_from_company(uuid, uuid) from anon;
grant execute on function public.unassign_route_from_company(uuid, uuid) to authenticated;

-- 3. Org: my assigned available routes (full field set for the auto-fill).

create or replace function public.list_my_available_routes(p_company_id uuid)
returns table (
  route_id uuid,
  route_number text,
  commodity text,
  loading_point text,
  offloading_point text,
  payment_terms text,
  operating_hours_24h boolean,
  operating_start text,
  operating_end text,
  tons text,
  num_trucks text,
  route_notes text,
  permanent boolean,
  assigned_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    rt.id, rt.route_number, rt.commodity, rt.loading_point, rt.offloading_point,
    rt.payment_terms, rt.operating_hours_24h, rt.operating_start, rt.operating_end,
    rt.tons, rt.num_trucks, rt.route_notes,
    ra.permanent, ra.created_at
  from public.route_assignments ra
  join public.routes rt on rt.id = ra.route_id
  where ra.company_id = p_company_id
    and public.is_company_staff(p_company_id)
  order by ra.created_at desc;
$$;

revoke all on function public.list_my_available_routes(uuid) from public;
revoke all on function public.list_my_available_routes(uuid) from anon;
grant execute on function public.list_my_available_routes(uuid) to authenticated;

-- 4. Admin-only marketplace: routes each transporter runs.

create or replace function public.list_route_marketplace()
returns table (
  route_id uuid,
  route_number text,
  commodity text,
  loading_point text,
  offloading_point text,
  transporter_name text,
  accepted_at timestamptz,
  trips_total bigint,
  trips_completed bigint,
  tons_delivered numeric
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    rt.id, rt.route_number, rt.commodity, rt.loading_point, rt.offloading_point,
    tc.company_name,
    d.dispatched_at,
    count(t.id),
    count(t.id) filter (where t.status = 'completed'),
    coalesce(sum(t.net_tons), 0)
  from public.request_dispatches d
  join public.routes rt on rt.id = d.route_id
  join public.companies tc on tc.id = d.transporter_company_id
  left join public.trips t on t.dispatch_id = d.id
  where d.status = 'accepted'
    and public.is_platform_admin()
  group by rt.id, rt.route_number, rt.commodity, rt.loading_point,
           rt.offloading_point, tc.company_name, d.dispatched_at
  order by d.dispatched_at desc;
$$;

revoke all on function public.list_route_marketplace() from public;
revoke all on function public.list_route_marketplace() from anon;
grant execute on function public.list_route_marketplace() to authenticated;

commit;
