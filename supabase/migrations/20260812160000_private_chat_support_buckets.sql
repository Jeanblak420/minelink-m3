-- P3-52 / P3-53 — `chat-attachments` and `support-attachments` become private
-- (client ruling 3, 2026-08-11; standing order wave 1.6, 2026-08-12).
--
-- Client ruling 3: "chat-attachments and support-attachments become private with
-- signed URLs. company_assets stays public (logos render on partner-facing
-- screens)." company_assets is therefore deliberately untouched here.
--
-- Both buckets were `public = true` with NO size limit and NO MIME restriction.
-- Public means reads bypass RLS entirely and go through the CDN, so every file
-- and image shared in company-to-company chat — lab results, contracts, load
-- photos — was readable by URL to anyone on the internet. support-attachments
-- was additionally an abuse vector: unauthenticated-readable, unbounded size,
-- any content type.
--
-- ============================================================================
-- A SECOND HOLE, WORSE THAN THE ONE THE ITEM NAMES
-- ============================================================================
--
-- `chat_attach_insert` was, in full:
--
--     WITH CHECK (bucket_id = 'chat-attachments')
--
-- No folder check, no room check, no ownership check. **Any authenticated user
-- could write any file into any chat room's folder.** Making the bucket private
-- would have closed the read hole and left that one wide open — a private bucket
-- with a permissive object policy is not private (P3-49). It is narrowed here to
-- the same `can_access_chat_room()` predicate the already-correct `chat_files`
-- bucket uses.
--
-- The bucket also had no SELECT policy at all, which was not an oversight: while
-- it was public nothing ever evaluated one. Going private means reads start
-- being checked, so the policy has to exist or every attachment 404s.
--
-- support-attachments needed neither fix — `support_attach_insert` and
-- `support_attach_select` are both already scoped through
-- `support_can_see_ticket()`. It needed only privacy, a size cap and a MIME
-- allow-list.
--
-- ============================================================================
-- WHY THIS IS SAFE TO RUN ON PRODUCTION RIGHT NOW
-- ============================================================================
--
-- Verified immediately before applying: **both buckets hold 0 objects.**
-- (`chat_files`, the private twin from the half-finished migration in P3-54, is
-- also empty.) No file has ever been uploaded to either, so:
--   * no stored URL breaks,
--   * no object needs migrating,
--   * nothing needs backfilling.
-- The Dart side switches from getPublicUrl() to a signed URL in the same commit.
--
-- ⚠ The stored value in `chat_messages.file_url` changes meaning: it now holds a
-- BUCKET-QUALIFIED OBJECT PATH (`chat-attachments/<roomId>/<uuid>.<ext>`), not a
-- URL. A signed URL expires, so storing one in a row would produce attachments
-- that work until they silently stop — the path is stored and signed on read,
-- the same pattern pod_uploads.photo_url and compliance_documents already use.
-- This is only safe because the table's attachment rows are as empty as the
-- buckets; a legacy `http…` value is still passed through untouched by the Dart
-- resolver rather than being mangled.

-- ---------------------------------------------------------------- privacy
update storage.buckets
   set public = false,
       file_size_limit = 26214400,                         -- 25 MB, as chat_files
       allowed_mime_types = array[
         'image/png','image/jpeg','image/webp','image/gif','image/heic',
         'application/pdf']
 where id = 'chat-attachments';

update storage.buckets
   set public = false,
       file_size_limit = 10485760,                         -- 10 MB is plenty for a
                                                           -- support screenshot
       allowed_mime_types = array[
         'image/png','image/jpeg','image/webp','image/gif','image/heic',
         'application/pdf']
 where id = 'support-attachments';

-- ---------------------------------------------------------------- chat policies
-- INSERT: was unscoped. Now the writer must be a participant of the room named
-- by the first path segment — identical to chat_files_insert.
drop policy if exists chat_attach_insert on storage.objects;

create policy chat_attach_insert
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'chat-attachments'
    and coalesce(array_length(storage.foldername(name), 1), 0) >= 1
    and public.can_access_chat_room(((storage.foldername(name))[1])::uuid)
  );

-- SELECT: did not exist, because a public bucket never evaluated one.
drop policy if exists chat_attach_select on storage.objects;

create policy chat_attach_select
  on storage.objects for select to authenticated
  using (
    bucket_id = 'chat-attachments'
    and coalesce(array_length(storage.foldername(name), 1), 0) >= 1
    and public.can_access_chat_room(((storage.foldername(name))[1])::uuid)
  );

-- DELETE: a participant may remove an attachment from their own room. Without
-- this an uploaded file can never be withdrawn by anyone but the service role.
drop policy if exists chat_attach_delete on storage.objects;

create policy chat_attach_delete
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'chat-attachments'
    and coalesce(array_length(storage.foldername(name), 1), 0) >= 1
    and public.can_access_chat_room(((storage.foldername(name))[1])::uuid)
  );
