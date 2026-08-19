-- Margin ledger: richer per-route detail for the super-admin screen
-- (2026-08-05 request: per-mine filter, proper details, totals).
--
-- Adds to list_margin_ledger(): buyer + transporter company names, the route
-- lane (commodity, loading point, offloading point) and the REAL tons moved on
-- the route so far (sum of trips.net_tons), so the UI can show margin earned
-- to date and honest totals. Return type changes => drop + recreate.

drop function if exists public.list_margin_ledger();

create function public.list_margin_ledger()
returns table(
  id uuid,
  request_id uuid,
  route_id uuid,
  route_number text,
  supplier_name text,
  buyer_name text,
  transporter_name text,
  commodity text,
  loading_point text,
  offloading_point text,
  agreed_price_per_ton numeric,
  admin_margin_per_ton numeric,
  transporter_price_per_ton numeric,
  currency text,
  tons_moved numeric,
  created_at timestamp with time zone
)
language sql
stable
security definer
set search_path to 'public'
as $$
  select
    l.id,
    l.request_id,
    l.route_id,
    rt.route_number,
    sc.company_name,
    bc.company_name,
    tc.company_name,
    rt.commodity,
    rt.loading_point,
    rt.offloading_point,
    l.agreed_price_per_ton,
    l.admin_margin_per_ton,
    l.transporter_price_per_ton,
    l.currency,
    coalesce(tons.sum_tons, 0),
    l.created_at
  from public.margin_ledger l
  left join public.routes rt on rt.id = l.route_id
  left join public.companies sc on sc.id = l.supplier_company_id
  left join public.transportation_requests req on req.id = l.request_id
  left join public.companies bc on bc.id = req.buyer_company_id
  left join lateral (
    select d.transporter_company_id
    from public.request_dispatches d
    where d.request_id = l.request_id
    order by d.dispatched_at desc nulls last
    limit 1
  ) disp on true
  left join public.companies tc on tc.id = disp.transporter_company_id
  left join lateral (
    select sum(t.net_tons) as sum_tons
    from public.trips t
    where t.route_id = l.route_id
  ) tons on true
  where public.is_platform_admin()
  order by l.created_at desc;
$$;

revoke all on function public.list_margin_ledger() from public, anon;
grant execute on function public.list_margin_ledger() to authenticated;
