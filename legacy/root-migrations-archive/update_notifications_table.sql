-- Add new columns to notifications table for action stamping and role-based filtering
ALTER TABLE notifications 
  ADD COLUMN IF NOT EXISTS actioned_by TEXT,
  ADD COLUMN IF NOT EXISTS actioned_by_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS role_scope TEXT;

-- Create index for faster queries on the new columns
CREATE INDEX IF NOT EXISTS notifications_actioned_by_id_idx ON notifications(actioned_by_id);
CREATE INDEX IF NOT EXISTS notifications_role_scope_idx ON notifications(role_scope);

-- Update RLS policies for notifications to allow for role-based filtering
DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;

-- Policy: Any authenticated user can insert notifications (for cross-user notifications)
CREATE POLICY "Users can insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (true);  -- Allow any authenticated user to insert notifications
