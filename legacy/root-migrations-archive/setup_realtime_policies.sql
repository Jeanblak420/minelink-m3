-- Enable Realtime for all tables
BEGIN;
-- Remove the supabase_realtime publication if it exists
DROP PUBLICATION IF EXISTS supabase_realtime;
-- Re-create the supabase_realtime publication with no tables
CREATE PUBLICATION supabase_realtime;
COMMIT;

-- Add tables to the publication
ALTER PUBLICATION supabase_realtime ADD TABLE companies;
ALTER PUBLICATION supabase_realtime ADD TABLE employees;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- Set REPLICA IDENTITY to FULL for all tables to get both old and new values in realtime events
ALTER TABLE companies REPLICA IDENTITY FULL;
ALTER TABLE employees REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;

-- Add new columns to notifications table for action stamping if they don't exist
ALTER TABLE notifications 
  ADD COLUMN IF NOT EXISTS actioned_by TEXT,
  ADD COLUMN IF NOT EXISTS actioned_by_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;

-- Create index for faster queries on the new columns
CREATE INDEX IF NOT EXISTS notifications_actioned_by_id_idx ON notifications(actioned_by_id);
