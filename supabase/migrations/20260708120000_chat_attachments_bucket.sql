-- ============================================================================
-- Storage bucket for chat attachments (images + files shared in the chat).
-- Objects are written under `{chat_room_id}/{uuid}.{ext}` by authenticated
-- users; the bucket is public-read so image/file bubbles render by URL.
-- (Paths are unguessable UUIDs; harden to signed URLs later if needed.)
-- ============================================================================
insert into storage.buckets (id, name, public, file_size_limit)
values ('chat-attachments', 'chat-attachments', true, 26214400)  -- 25 MB
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit;

-- Authenticated users may upload into the bucket.
drop policy if exists chat_attach_insert on storage.objects;
create policy chat_attach_insert on storage.objects
  for insert to authenticated
  with check (bucket_id = 'chat-attachments');

-- Public read (bucket is public; explicit select policy for API reads).
drop policy if exists chat_attach_read on storage.objects;
create policy chat_attach_read on storage.objects
  for select to public
  using (bucket_id = 'chat-attachments');
