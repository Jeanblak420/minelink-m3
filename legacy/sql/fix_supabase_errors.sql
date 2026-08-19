-- Fix for employee_status_history table
ALTER TABLE employee_status_history 
  ADD COLUMN IF NOT EXISTS actioned_by_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS actioned_by_name TEXT,
  ADD COLUMN IF NOT EXISTS assigned_role TEXT;

-- Create index for faster queries on the new columns
CREATE INDEX IF NOT EXISTS employee_status_history_actioned_by_id_idx ON employee_status_history(actioned_by_id);
CREATE INDEX IF NOT EXISTS employee_status_history_employee_id_idx ON employee_status_history(employee_id);

-- Add missing columns to notifications table
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS org_type TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS metadata JSONB;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS importance TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actioned_by TEXT;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS actioned_by_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS role_scope TEXT;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS notifications_importance_idx ON notifications(importance);
CREATE INDEX IF NOT EXISTS notifications_actioned_by_id_idx ON notifications(actioned_by_id);

-- Fix RLS policies for notifications table
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Any authenticated user can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;
DROP POLICY IF EXISTS "Companies can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Companies can view their notifications" ON notifications;

-- Create new policies
-- Policy: Users can view their own notifications
CREATE POLICY "Users can view their own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Any authenticated user can insert notifications
CREATE POLICY "Any authenticated user can insert notifications"
  ON notifications FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

-- Policy: Users can update their own notifications (e.g., mark as read)
CREATE POLICY "Users can update their own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- Policy: Users can delete their own notifications
CREATE POLICY "Users can delete their own notifications"
  ON notifications FOR DELETE
  USING (auth.uid() = user_id);
