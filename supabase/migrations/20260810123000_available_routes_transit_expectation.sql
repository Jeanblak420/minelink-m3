-- Surface the agreed transit expectation on the admin's Available routes list.
--
-- `20260810120000` added `routes.expected_transit_hours` and made it the thing
-- the leaderboard's ON-TIME column is measured against. A yardstick nobody can
-- see is a yardstick nobody sets, and an unset one makes on-time read "—"
-- forever — so the list the admin already uses to manage routes now carries the
-- current value, and shows plainly which routes have none.
--
-- Nothing is removed: the twelve existing columns keep their names, types and
-- order, and one nullable column is appended. Adding to a RETURNS TABLE changes
-- the function's return type, which `create or replace` cannot do, hence the
-- drop-and-recreate rather than a replace in place.

drop function if exists public.list_available_routes();

create function public.list_available_routes()
returns table(
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
  created_at timestamp with time zone,
  assigned_companies text,
  expected_transit_hours numeric
)
language sql
stable
security definer
set search_path to 'public'
as $function$
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
    ),
    rt.expected_transit_hours
  from public.routes rt
  left join public.companies sc on sc.id = rt.supplier_company_id
  left join public.companies bc on bc.id = rt.buyer_company_id
  where public.is_platform_admin()
  order by rt.created_at desc;
$function$;

grant execute on function public.list_available_routes() to authenticated;
