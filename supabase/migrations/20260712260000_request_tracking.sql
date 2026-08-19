-- Request tracking for every involved party (Jean, 2026-07-12): each company
-- in a request's loop — the requester, the supplying mine, every dispatched
-- transporter — and the super global admin can follow the request through to
-- completion. A request counts as COMPLETED when it is linked, trips exist,
-- and every trip is completed (derived — no stored status to drift).

begin;

create or replace function public.list_request_tracking(p_company_id uuid)
returns table (
  request_id uuid,
  request_type text,
  status text,
  requester_name text,
  supplier_name text,
  transporter_names text,
  commodity text,
  loading_point text,
  offloading_point text,
  trips_total bigint,
  trips_completed bigint,
  tons_delivered numeric,
  is_completed boolean,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    r.id,
    r.request_type,
    r.status,
    rc.company_name,
    sc.company_name,
    (
      select string_agg(distinct c.company_name, ', ')
      from public.request_dispatches d
      join public.companies c on c.id = d.transporter_company_id
      where d.request_id = r.id
    ),
    r.commodity,
    r.loading_point,
    r.offloading_point,
    tr.total,
    tr.done,
    tr.tons,
    (r.status = 'linked' and tr.total > 0 and tr.done = tr.total) as is_completed,
    r.updated_at
  from public.transportation_requests r
  left join public.companies rc on rc.id = r.buyer_company_id
  left join public.companies sc on sc.id = r.supplier_company_id
  left join lateral (
    select
      count(t.id) as total,
      count(t.id) filter (where t.status = 'completed') as done,
      coalesce(sum(t.net_tons), 0) as tons
    from public.request_dispatches d
    join public.trips t on t.dispatch_id = d.id
    where d.request_id = r.id
  ) tr on true
  where (
    public.is_platform_admin()
    or (
      p_company_id is not null
      and public.is_company_staff(p_company_id)
      and (
        r.buyer_company_id = p_company_id
        or r.supplier_company_id = p_company_id
        or exists (
          select 1 from public.request_dispatches d
          where d.request_id = r.id
            and d.transporter_company_id = p_company_id
        )
      )
    )
  )
  order by r.updated_at desc;
$function$;

revoke all on function public.list_request_tracking(uuid) from public;
revoke all on function public.list_request_tracking(uuid) from anon;
grant execute on function public.list_request_tracking(uuid) to authenticated;

commit;
