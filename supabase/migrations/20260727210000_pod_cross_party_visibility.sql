-- POD photo cross-party visibility (2026-07-27).
--
-- The driver's POD photo uploads to the private `pod_photos` bucket under the
-- TRANSPORTER's company folder, so the existing company-folder storage policy
-- meant the buyer and the mine could see the row (`pod_uploads` is already
-- party-scoped) but never open the photo itself. Adds a storage SELECT policy
-- that follows the reference: any object pointed at by a `pod_uploads` row is
-- viewable by staff of every company on that upload's transaction (mine /
-- buyer / transporter) — the platform admin was already covered.
--
-- Also extends `list_raw_recon_rows` (the recon table all three orgs + the
-- super-admin combined screen read) with `pod_photo_path` so the POD photo is
-- openable straight from the table that tracks every check-in → check-out.

begin;

-- 1. Storage: parties on the transaction may view the POD photo -----------------

drop policy if exists pod_photos_select_parties on storage.objects;
create policy pod_photos_select_parties
on storage.objects
for select
to authenticated
using (
  bucket_id = 'pod_photos'
  and exists (
    select 1
    from public.pod_uploads p
    join public.transactions txn on txn.id = p.transaction_id
    where p.photo_url = storage.objects.name
      and (
        public.is_company_staff(txn.supplier_company_id)
        or public.is_company_staff(txn.buyer_company_id)
        or public.is_company_staff(txn.transporter_company_id)
      )
  )
);

-- 2. Raw recon rows carry the POD photo path -----------------------------------
-- Return type changes, so the old signature must be dropped first.

drop function if exists public.list_raw_recon_rows(uuid);

create or replace function public.list_raw_recon_rows(p_company_id uuid)
returns table(
  trip_id uuid,
  trip_date timestamptz,
  time_in timestamptz,
  waybill_number text,
  transporter_name text,
  truck_reg text,
  destination text,
  product text,
  source_name text,
  customer_name text,
  net_mass numeric,
  delivered_tons numeric,
  time_out timestamptz,
  trip_status text,
  pod_photo_path text
)
language sql
stable
security definer
set search_path to 'public'
as $function$
  select
    t.id,
    coalesce(t.arrived_at, t.created_at),
    t.arrived_at,
    txn.reference_number,
    tc.company_name,
    coalesce(t.metadata->>'truck_reg', fv.vehicle_registration_number),
    txn.metadata->>'offloading_point',
    txn.metadata->>'commodity',
    sc.company_name,
    bc.company_name,
    t.net_tons,
    pod.delivered_tons,
    t.left_at,
    t.status,
    pod.photo_url
  from public.trips t
  join public.transactions txn on txn.id = t.transaction_id
  left join public.fleet_vehicles fv on fv.id = t.vehicle_id
  left join public.companies sc on sc.id = txn.supplier_company_id
  left join public.companies bc on bc.id = txn.buyer_company_id
  left join public.companies tc on tc.id = txn.transporter_company_id
  left join lateral (
    select p.delivered_tons, p.photo_url
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
  order by coalesce(t.arrived_at, t.created_at) desc;
$function$;

revoke all on function public.list_raw_recon_rows(uuid) from public;
revoke all on function public.list_raw_recon_rows(uuid) from anon;
grant execute on function public.list_raw_recon_rows(uuid) to authenticated;

commit;
