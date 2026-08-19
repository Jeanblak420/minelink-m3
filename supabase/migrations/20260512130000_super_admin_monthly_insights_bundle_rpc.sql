begin;

-- Performance: monthly range scans on transactions (trips already have trips_updated_at_idx).
create index if not exists transactions_updated_at_idx on public.transactions (updated_at desc);

-- Server-side rollups for Super Global Admin insights (layer 1–2).
-- Time window must match the client: pass the same ISO bounds used in Dart queries.
create or replace function public.super_admin_monthly_insights_bundle(
  p_org_type text,
  p_range_start timestamptz,
  p_range_end timestamptz
)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
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
  company_row jsonb;
  sum_trips bigint := 0;
  sum_fleet bigint := 0;
  sum_tons numeric := 0;
  sum_loads bigint := 0;
  sum_comp bigint := 0;
  sum_pend bigint := 0;
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

    if p_org_type = 'transporter' then
      select
        count(*)::int,
        coalesce(sum(quantity), 0)::numeric,
        count(*) filter (where lower(trim(coalesce(status, ''))) = 'completed')::int,
        count(*) filter (where lower(trim(coalesce(status, ''))) is distinct from 'completed')::int
      into loads_n, tons_n, comp_wb, pend_wb
      from public.transactions
      where updated_at >= p_range_start
        and updated_at <= p_range_end
        and transporter_company_id = cid;
    elsif p_org_type = 'buyer' then
      select
        count(*)::int,
        coalesce(sum(quantity), 0)::numeric,
        count(*) filter (where lower(trim(coalesce(status, ''))) = 'completed')::int,
        count(*) filter (where lower(trim(coalesce(status, ''))) is distinct from 'completed')::int
      into loads_n, tons_n, comp_wb, pend_wb
      from public.transactions
      where updated_at >= p_range_start
        and updated_at <= p_range_end
        and buyer_company_id = cid;
    else
      select
        count(*)::int,
        coalesce(sum(quantity), 0)::numeric,
        count(*) filter (where lower(trim(coalesce(status, ''))) = 'completed')::int,
        count(*) filter (where lower(trim(coalesce(status, ''))) is distinct from 'completed')::int
      into loads_n, tons_n, comp_wb, pend_wb
      from public.transactions
      where updated_at >= p_range_start
        and updated_at <= p_range_end
        and supplier_company_id = cid;
    end if;

    select count(*)::int into trips_n
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
      'pending_waybills', pend_wb
    );

    companies_json := companies_json || jsonb_build_array(company_row);

    sum_trips := sum_trips + trips_n;
    sum_fleet := sum_fleet + fleet_n;
    sum_tons := sum_tons + tons_n;
    sum_loads := sum_loads + loads_n;
    sum_comp := sum_comp + comp_wb;
    sum_pend := sum_pend + pend_wb;
  end loop;

  agg := jsonb_build_object(
    'org_type', p_org_type,
    'company_count', jsonb_array_length(companies_json),
    'active_trips_approx', sum_trips,
    'fleet_vehicles_total', sum_fleet,
    'tons_moved', sum_tons,
    'transactions_total', sum_loads,
    'completed_waybills', sum_comp,
    'pending_waybills', sum_pend
  );

  return jsonb_build_object(
    'companies', companies_json,
    'aggregate', agg,
    'range_start', to_jsonb(p_range_start),
    'range_end', to_jsonb(p_range_end)
  );
end;
$$;

grant execute on function public.super_admin_monthly_insights_bundle(text, timestamptz, timestamptz) to authenticated;

commit;
