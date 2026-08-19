-- ============================================================================
-- Chat: bump chat_rooms last-message preview via trigger (SECURITY DEFINER),
-- so clients don't need UPDATE privilege on chat_rooms just to send a message.
-- Also grant UPDATE to authenticated for legitimate room edits (RLS still limits
-- edits to participants).
-- ============================================================================

CREATE OR REPLACE FUNCTION public.chat_bump_last_message()
  RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE public.chat_rooms
     SET last_message_content   = NEW.content,
         last_message_timestamp = NEW.timestamp,
         last_message_sender_id = NEW.sender_id
   WHERE id = NEW.chat_room_id;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_chat_bump_last_message ON public.chat_messages;
CREATE TRIGGER trg_chat_bump_last_message
  AFTER INSERT ON public.chat_messages
  FOR EACH ROW EXECUTE FUNCTION public.chat_bump_last_message();

GRANT UPDATE ON public.chat_rooms TO authenticated;
