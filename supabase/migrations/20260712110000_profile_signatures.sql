-- Per-user profile signature (CLAUDE.md §4 "Parties & roles").
-- Every user (employees, company owners, and both super global admins) can draw
-- their own signature once; it is stored as a transparent PNG in the private
-- `signatures` bucket and reused wherever a signature is needed (waybills, PODs).
--
-- The signature is a per-auth-user concept, so it lives on `profiles` (keyed by
-- auth.users.id) rather than on `employees`/`companies` — that way it applies
-- uniformly to every role and org type, including super admins.

begin;

-- 1. Column holding the storage object path (bucket-relative), e.g.
--    `signatures/<user_id>/signature.png`. Resolved to a signed URL client-side
--    by StorageAssetService, mirroring employee_assets.
alter table public.profiles
  add column if not exists signature_url text;

-- 2. Self-service RPC to save the current user's signature path. SECURITY
--    INVOKER: the existing `profiles_update_own` RLS policy already scopes
--    updates to the caller's own row, so no elevated privileges are needed.
create or replace function public.set_my_signature(p_signature_path text)
returns void
language sql
security invoker
set search_path = public
as $$
  update public.profiles
  set signature_url = p_signature_path,
      updated_at = timezone('utc', now())
  where id = (select auth.uid());
$$;

-- Lock the function down to signed-in users only (Postgres grants EXECUTE to
-- PUBLIC by default, which would expose it to anon).
revoke all on function public.set_my_signature(text) from public;
revoke all on function public.set_my_signature(text) from anon;
grant execute on function public.set_my_signature(text) to authenticated;

-- 3. Private storage bucket for signature PNGs. Small size limit; PNG only so
--    the transparent-background export is preserved.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('signatures', 'signatures', false, 2097152, array['image/png'])
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- 4. Storage RLS. Objects are laid out as `<user_id>/signature.png`, so
--    foldername(name)[1] is the owning user's id.
--    - Writes (insert/update): owner of the folder only.
--    - Reads (select): any authenticated user, because the waybill/POD
--      generator legitimately needs to render another trip participant's
--      signature (e.g. the Load Controller printing the dispatch block, or an
--      admin regenerating a completed waybill).
drop policy if exists signatures_select_authenticated on storage.objects;
drop policy if exists signatures_insert_own on storage.objects;
drop policy if exists signatures_update_own on storage.objects;

create policy signatures_select_authenticated
on storage.objects
for select
to authenticated
using (bucket_id = 'signatures');

create policy signatures_insert_own
on storage.objects
for insert
to authenticated
with check (
  bucket_id = 'signatures'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

create policy signatures_update_own
on storage.objects
for update
to authenticated
using (
  bucket_id = 'signatures'
  and (storage.foldername(name))[1] = (select auth.uid())::text
)
with check (
  bucket_id = 'signatures'
  and (storage.foldername(name))[1] = (select auth.uid())::text
);

commit;
