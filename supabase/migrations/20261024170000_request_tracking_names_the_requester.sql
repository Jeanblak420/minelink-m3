-- Request tracking names the company that raised the request.
--
-- Found on the S25 walk, 2026-10-24; fixed on Jean's OK ("please fix it").
-- `list_request_tracking` took "requested by" from `buyer_company_id`, so a
-- request a MINE raised ("Request buyers") showed the buyer as its
-- requester — on the mine's, the buyer's, the transporter's and the
-- admin's tracking pages alike. The admin inbox had the same fault and was
-- fixed on 2026-08-17 (request_service.dart, listForAdmin); this function
-- never was.
--
-- Two changes, nothing else:
--   * requester = requesting_company_id, falling back to buyer_company_id for
--     rows written before that column was filled.
--   * the company that RAISED a request can see it. Visibility checked only
--     buyer, supplier and transporter, so a mine's own request was invisible
--     on its tracking page until a mine had been assigned to it.
--
-- Body otherwise copied from the live catalog (2026-10-24); return type
-- unchanged, so create or replace is allowed.
begin;

create or replace function public.list_request_tracking(p_company_id uuid)
returns table (
  request_id uuid, request_type text, status text, requester_name text,
  supplier_name text, transporter_names text, commodity text,
  loading_point text, offloading_point text, trips_total bigint,
  trips_completed bigint, tons_delivered numeric, is_completed boolean,
  updated_at timestamp with time zone)
language sql
stable security definer
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
  left join public.companies rc
    on rc.id = coalesce(r.requesting_company_id, r.buyer_company_id)
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
        r.requesting_company_id = p_company_id
        or r.buyer_company_id = p_company_id
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

commit;
