-- Trip weight-variance reconciliation (CLAUDE.md §4 Reconciliations Side B +
-- two-weight offload variance).
--
-- The mine Net Weight (trips.net_tons, loaded at source) is the AUTHORITATIVE
-- figure. The delivered tons (pod_uploads.delivered_tons, re-weighed at offload)
-- is stored separately. This RPC surfaces both plus the computed variance
-- (mine net − delivered = lost/stolen/swapped mass) per trip, scoped to the
-- trip's parties (or the platform admin). Nothing is overwritten.

begin;

create or replace function public.list_trip_reconciliations(p_company_id uuid)
returns table (
  trip_id uuid,
  reference text,
  truck_reg text,
  commodity text,
  source_name text,
  customer_name text,
  transporter_name text,
  mine_net_tons numeric,
  delivered_tons numeric,
  variance numeric,
  trip_status text,
  updated_at timestamptz
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    t.id,
    txn.reference_number,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    txn.metadata->>'commodity',
    sc.company_name,
    bc.company_name,
    tc.company_name,
    t.net_tons,
    pod.delivered_tons,
    case
      when t.net_tons is not null and pod.delivered_tons is not null
        then t.net_tons - pod.delivered_tons
      else null
    end as variance,
    t.status,
    t.updated_at
  from public.trips t
  join public.transactions txn on txn.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.companies sc on sc.id = txn.supplier_company_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  left join public.companies tc on tc.id = txn.transporter_company_id
  left join lateral (
    select p.delivered_tons
    from public.pod_uploads p
    where p.trip_id = t.id
    order by p.uploaded_at desc
    limit 1
  ) pod on true
  where (
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
    and t.net_tons is not null
  order by t.updated_at desc;
$function$;

revoke all on function public.list_trip_reconciliations(uuid) from public;
revoke all on function public.list_trip_reconciliations(uuid) from anon;
grant execute on function public.list_trip_reconciliations(uuid) to authenticated;

commit;
