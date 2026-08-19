-- Reconciliations Side A (CLAUDE.md §4 "Reconciliations screen"):
--   1. list_raw_recon_rows — the raw, as-captured per-trip records (the recon
--      table columns: DATE · TIME-IN · WAYBILL NUMBER · TRANSPORTER · TRUCK ·
--      DESTINATION · PRODUCT · SOURCE · CUSTOMER · NET MASS · TIME-OUT),
--      before any reconciliation logic. Party-scoped like Side B.
--   2. The two-version export→edit→re-upload round-trip: a private
--      `recon_docs` bucket + `reconciliation_uploads` holding exactly two
--      versions per (company, side) — the ORIGINAL (system snapshot, never
--      overwritten) and the LATEST edited upload (each new upload replaces
--      the previous edited copy only).
--
-- Edit rights (intentionally limited for now): the initiator org's managers
-- and the super-admin; everyone else in the loop is view-only via RLS.

begin;

-- 1. Raw (Side A) rows --------------------------------------------------------

create or replace function public.list_raw_recon_rows(p_company_id uuid)
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
  time_out timestamptz,
  trip_status text
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
    t.status
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
  order by coalesce(t.arrived_at, t.created_at) desc;
$function$;

revoke all on function public.list_raw_recon_rows(uuid) from public;
revoke all on function public.list_raw_recon_rows(uuid) from anon;
grant execute on function public.list_raw_recon_rows(uuid) to authenticated;

-- 2. Private bucket for the round-trip documents ------------------------------
-- Object layout: `<company_id>/<uuid>_<name>` — first folder scopes RLS.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'recon_docs',
  'recon_docs',
  false,
  20971520,
  array[
    'text/csv',
    'application/pdf',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'application/vnd.ms-excel'
  ]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists recon_docs_select on storage.objects;
drop policy if exists recon_docs_insert on storage.objects;
drop policy if exists recon_docs_delete on storage.objects;

create policy recon_docs_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'recon_docs'
  and (
    public.is_platform_admin()
    or exists (
      select 1 from public.companies c
      where c.id::text = (storage.foldername(name))[1]
        and public.is_company_staff(c.id)
    )
  )
);

create policy recon_docs_insert
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'recon_docs'
  and (
    public.is_platform_admin()
    or exists (
      select 1 from public.companies c
      where c.id::text = (storage.foldername(name))[1]
        and public.is_company_manager(c.id)
    )
  )
);

create policy recon_docs_delete
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'recon_docs'
  and (
    public.is_platform_admin()
    or exists (
      select 1 from public.companies c
      where c.id::text = (storage.foldername(name))[1]
        and public.is_company_manager(c.id)
    )
  )
);

-- 3. The two-version pairs -----------------------------------------------------

create table if not exists public.reconciliation_uploads (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  side text not null check (side in ('A', 'B')),
  original_path text not null,
  original_created_at timestamptz not null default timezone('utc', now()),
  edited_path text,
  edited_by uuid,
  edited_uploaded_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  unique (company_id, side)
);

alter table public.reconciliation_uploads enable row level security;

drop policy if exists reconciliation_uploads_select on public.reconciliation_uploads;
create policy reconciliation_uploads_select
on public.reconciliation_uploads
for select
to authenticated
using (public.is_company_staff(company_id) or public.is_platform_admin());
-- Writes go through save_recon_upload only.

-- 4. Round-trip write RPC. The original is written once and never replaced;
--    every subsequent call replaces only the edited copy.

create or replace function public.save_recon_upload(
  p_company_id uuid,
  p_side text,
  p_original_path text,
  p_edited_path text
)
returns jsonb
language plpgsql
security definer
set search_path to 'public'
as $$
declare
  pair public.reconciliation_uploads;
begin
  if not (public.is_platform_admin() or public.is_company_manager(p_company_id)) then
    raise exception 'Only the initiating org''s admin or the MineLink admin may upload edited reconciliations';
  end if;
  if p_side not in ('A', 'B') then
    raise exception 'Side must be A or B';
  end if;
  if p_edited_path is null or length(trim(p_edited_path)) = 0 then
    raise exception 'An edited file is required';
  end if;

  select * into pair
  from public.reconciliation_uploads
  where company_id = p_company_id and side = p_side;

  if pair.id is null then
    if p_original_path is null or length(trim(p_original_path)) = 0 then
      raise exception 'The original system export must be snapshotted on the first upload';
    end if;
    insert into public.reconciliation_uploads (
      company_id, side, original_path, edited_path, edited_by, edited_uploaded_at
    ) values (
      p_company_id, p_side, p_original_path, p_edited_path, auth.uid(), timezone('utc', now())
    )
    returning * into pair;
  else
    -- Original is immutable; only the edited copy is replaced.
    update public.reconciliation_uploads
    set edited_path = p_edited_path,
        edited_by = auth.uid(),
        edited_uploaded_at = timezone('utc', now())
    where id = pair.id
    returning * into pair;
  end if;

  return to_jsonb(pair);
end;
$$;

revoke all on function public.save_recon_upload(uuid, text, text, text) from public;
revoke all on function public.save_recon_upload(uuid, text, text, text) from anon;
grant execute on function public.save_recon_upload(uuid, text, text, text) to authenticated;

commit;
