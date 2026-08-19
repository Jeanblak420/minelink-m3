-- S2-15. `chat_messages` carries TWO AFTER INSERT triggers that both write
-- `chat_rooms.last_message_*`:
--
--   handle_chat_rooms_last_message -> sync_chat_room_last_message()
--   trg_chat_bump_last_message     -> chat_bump_last_message()
--
-- Postgres fires same-timing triggers in alphabetical order by trigger name,
-- so `trg_chat_bump_last_message` runs SECOND and overwrites the first.
--
-- `content` is NOT NULL, so an attachment-only message is sent as ''.
-- sync_chat_room_last_message() handles exactly that case and writes
-- "Sent a file: invoice.pdf"; chat_bump_last_message() then blindly wrote
-- NEW.content over it. Proven on production in a rolled-back transaction:
-- with both triggers the preview came back '' (length 0); with the bump
-- trigger disabled it came back 'Sent a file: invoice.pdf'.
--
-- User-visible effect: send an attachment with no text and the conversation
-- list shows a BLANK last-message preview.
--
-- Fixed additively rather than by dropping the redundant trigger, which would
-- need the client's sign-off on production (COMPLETION-PLAN.md §3). Giving
-- both functions identical logic makes the outcome independent of firing
-- order, so the bug cannot come back if the order ever changes. The remaining
-- cost is one redundant UPDATE per message; removing the duplicate trigger is
-- raised as S2-15a and is a one-line change once approved.
create or replace function public.chat_bump_last_message()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
begin
  update public.chat_rooms
  set
    last_message_content = case
      when nullif(trim(coalesce(new.content, '')), '') is not null then new.content
      when nullif(trim(coalesce(new.file_name, '')), '') is not null then 'Sent a file: ' || new.file_name
      else 'New message'
    end,
    last_message_timestamp = new.timestamp,
    last_message_sender_id = new.sender_id
  where id = new.chat_room_id;

  return new;
end;
$function$;

comment on function public.chat_bump_last_message() is
  'Mirrors sync_chat_room_last_message() exactly. Both fire AFTER INSERT on '
  'chat_messages and write chat_rooms.last_message_*; identical bodies make '
  'the result independent of trigger firing order. Before 2026-08-15 this one '
  'wrote NEW.content blindly and, firing second, blanked the '
  '"Sent a file: <name>" preview for every attachment-only message. '
  'See S2-15a for removing the duplication.';
