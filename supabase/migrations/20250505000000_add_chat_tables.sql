-- Create chat_rooms table
CREATE TABLE IF NOT EXISTS chat_rooms (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  participant_ids UUID[] NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_message_content TEXT,
  last_message_timestamp TIMESTAMPTZ,
  last_message_sender_id UUID
);

-- Create chat_messages table
CREATE TABLE IF NOT EXISTS chat_messages (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  chat_room_id UUID REFERENCES chat_rooms(id) ON DELETE CASCADE,
  content TEXT NOT NULL,
  sender_id UUID NOT NULL,
  sender_name TEXT NOT NULL,
  sender_avatar_url TEXT,
  timestamp TIMESTAMPTZ DEFAULT NOW(),
  is_read BOOLEAN DEFAULT FALSE,
  reply_to_id UUID,
  file_url TEXT,
  file_type TEXT,
  file_name TEXT
);

-- Enable Row Level Security
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_messages ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for chat_rooms
CREATE POLICY "Users can view their chat rooms" ON chat_rooms
  FOR SELECT USING (
    auth.uid() = ANY(participant_ids)
  );

CREATE POLICY "Users can create chat rooms" ON chat_rooms
  FOR INSERT WITH CHECK (
    auth.uid() = ANY(participant_ids)
  );

CREATE POLICY "Users can update their chat rooms" ON chat_rooms
  FOR UPDATE USING (
    auth.uid() = ANY(participant_ids)
  );

-- Create RLS policies for chat_messages
CREATE POLICY "Users can view messages in their chat rooms" ON chat_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE id = chat_messages.chat_room_id
      AND auth.uid() = ANY(participant_ids)
    )
  );

CREATE POLICY "Users can send messages to their chat rooms" ON chat_messages
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM chat_rooms
      WHERE id = chat_messages.chat_room_id
      AND auth.uid() = ANY(participant_ids)
    )
    AND auth.uid() = sender_id
  );

CREATE POLICY "Users can update their own messages" ON chat_messages
  FOR UPDATE USING (
    auth.uid() = sender_id
  );

-- Add chat tables to realtime publication
ALTER PUBLICATION supabase_realtime ADD TABLE chat_rooms;
ALTER PUBLICATION supabase_realtime ADD TABLE chat_messages;

-- Set replica identity to full for realtime
ALTER TABLE chat_rooms REPLICA IDENTITY FULL;
ALTER TABLE chat_messages REPLICA IDENTITY FULL;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_chat_rooms_participant_ids ON chat_rooms USING GIN (participant_ids);
CREATE INDEX IF NOT EXISTS idx_chat_messages_chat_room_id ON chat_messages (chat_room_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender_id ON chat_messages (sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_timestamp ON chat_messages (timestamp);
