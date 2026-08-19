-- ============================================================================
-- Recon reads the trip's own variance, and the raw table gains the column
-- (P3-13, follows 20260811170000)
-- ----------------------------------------------------------------------------
-- Both recon feeds resolved the delivered figure themselves, by lateral-joining
-- the newest `pod_uploads` row per trip. That was the only place it lived. Now
-- that `trips.delivered_tons` exists and `trips.variance_tons` is generated
-- from it, a second derivation is a second answer waiting to disagree with the
-- first -- and the two would part company the moment anyone corrected a
-- delivered figure on the trip without re-uploading a POD.
--
-- So both read the trip. `pod_uploads` is still lateral-joined, but only for
-- the photo, which genuinely lives there.
--
-- `list_raw_recon_rows` also gains `variance_tons`. The raw recon table is the
-- one every org and the super-admin console render, and it showed net mass and
-- delivered tonnage side by side while leaving the reader to subtract them --
-- which is exactly the signal the whole reconciliation layer exists to produce.
--
-- NOTE ON THE DROP. `create or replace` cannot add a column to a RETURNS TABLE
-- function, so this is `drop` + `create` in one migration. The function is not
-- being retired: its result is a strict SUPERSET of what it returned before,
-- and PostgREST keys its JSON by name, so no caller breaks on the new column.
-- ============================================================================

drop function if exists public.list_raw_recon_rows(uuid);

create function public.list_raw_recon_rows(p_company_id uuid)
returns table (
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
  variance_tons numeric,
  time_out timestamptz,
  trip_status text,
  pod_photo_path text
)
language sql
stable
security definer
set search_path = public
as $$
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
    -- The trip's own columns, not a re-derivation from pod_uploads: one
    -- source, so the table and the Side B view cannot disagree.
    t.delivered_tons,
    t.variance_tons,
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
    -- Photo only. The delivered figure comes off the trip now.
    select p.photo_url
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
$$;

comment on function public.list_raw_recon_rows(uuid) is
  'Side A raw recon rows, party-scoped. Net mass, delivered tonnage and the '
  'generated variance all come off `trips`, so this table, the Side B '
  'reconciliation view and the exports cannot report three different answers '
  'for one load.';

revoke execute on function public.list_raw_recon_rows(uuid) from public;
grant  execute on function public.list_raw_recon_rows(uuid) to authenticated;
