-- Add missing columns to employee_status_history table
ALTER TABLE employee_status_history 
  ADD COLUMN IF NOT EXISTS actioned_by_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS actioned_by_name TEXT,
  ADD COLUMN IF NOT EXISTS assigned_role TEXT;

-- Create index for faster queries on the new columns
CREATE INDEX IF NOT EXISTS employee_status_history_actioned_by_id_idx ON employee_status_history(actioned_by_id);
CREATE INDEX IF NOT EXISTS employee_status_history_employee_id_idx ON employee_status_history(employee_id);

-- Fix RLS policies for notifications table
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;

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
