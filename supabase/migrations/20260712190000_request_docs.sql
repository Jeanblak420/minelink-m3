-- Request attachments (CLAUDE.md §4 "Request Buyer"): multi-PDF lab
-- results/reports + one optional product picture per request.
--
-- Paths live on `transportation_requests` as bucket-relative object paths in
-- the private `request_docs` bucket; the client resolves them to signed URLs
-- via StorageAssetService (same pattern as `signatures`).
--
-- Object layout: `<company_id>/<uuid>_<original_name>` — the first folder is
-- the requesting company, so storage RLS can scope by company membership.

begin;

-- 1. Columns holding the attachment object paths.
alter table public.transportation_requests
  add column if not exists lab_result_paths text[] not null default '{}'::text[],
  add column if not exists product_image_path text;

-- 2. Private storage bucket. PDFs (lab results) + common photo formats
--    (optional product picture). 20 MB per object.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'request_docs',
  'request_docs',
  false,
  20971520,
  array[
    'application/pdf',
    'image/png',
    'image/jpeg',
    'image/webp',
    'image/heic'
  ]
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- 3. Storage RLS. The first path folder is the owning company id. The
--    companies join (rather than a bare ::uuid cast) keeps a malformed folder
--    name from raising a cast error instead of a clean policy denial.
--    - Writes (insert/delete): staff of that company only.
--    - Reads (select): staff of that company, or the platform admin reviewing
--      the request.
drop policy if exists request_docs_select on storage.objects;
drop policy if exists request_docs_insert_company on storage.objects;
drop policy if exists request_docs_delete_company on storage.objects;

create policy request_docs_select
on storage.objects
for select
to authenticated
using (
  bucket_id = 'request_docs'
  and (
    public.is_platform_admin()
    or exists (
      select 1
      from public.companies c
      where c.id::text = (storage.foldername(name))[1]
        and public.is_company_staff(c.id)
    )
  )
);

create policy request_docs_insert_company
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'request_docs'
  and exists (
    select 1
    from public.companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.is_company_staff(c.id)
  )
);

create policy request_docs_delete_company
on storage.objects
for delete
to authenticated
using (
  bucket_id = 'request_docs'
  and exists (
    select 1
    from public.companies c
    where c.id::text = (storage.foldername(name))[1]
      and public.is_company_staff(c.id)
  )
);

commit;
