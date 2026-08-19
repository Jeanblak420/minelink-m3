-- `chat_mark_all_delivered()` is an UPDATE with `where delivered_at is null`,
-- and it is called on a timer by every signed-in client for the life of every
-- open tab (the ChatDock keeps the delivery provider alive on every portal
-- screen). The overwhelmingly common outcome is that it matches nothing, and
-- with no index on `delivered_at` deciding that meant scanning the table.
--
-- A partial index over just the undelivered rows makes the no-op case an index
-- probe. It is also self-limiting: a row leaves the index the moment it is
-- marked delivered, so the index stays roughly the size of the unread backlog
-- rather than of the message history. Today that is 3 rows out of 38.
--
-- Paired with the client change that widened the sweep from 5 s to 60 s. The
-- index is the half that keeps this cheap once there are real message volumes.
create index if not exists chat_messages_undelivered_idx
  on public.chat_messages (chat_room_id)
  where delivered_at is null;

comment on index public.chat_messages_undelivered_idx is
  'Serves chat_mark_all_delivered()''s `delivered_at is null` predicate. '
  'Partial, so it holds only the undelivered backlog, not the history.';
