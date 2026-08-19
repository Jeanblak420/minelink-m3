-- Fix permissions for notifications table and check_user_exists function

-- First, ensure the notifications table has RLS enabled
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop existing policies to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Any authenticated user can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;
DROP POLICY IF EXISTS "Companies can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Companies can view their notifications" ON notifications;

-- Create new policies with proper permissions

-- Policy: Users can view their own notifications
CREATE POLICY "Users can view their own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id);

-- Policy: Any authenticated user can insert notifications
-- This is the key policy that was missing or not working
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

-- Policy: Companies can view notifications for their employees
CREATE POLICY "Companies can view their notifications"
  ON notifications FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM companies 
      WHERE companies.user_id = auth.uid() 
      AND (
        companies.id = notifications.company_id
        OR 
        EXISTS (
          SELECT 1 FROM employees 
          WHERE employees.company_id = companies.id 
          AND employees.id = notifications.employee_id
        )
      )
    )
  );

-- Create or replace the check_user_exists function
CREATE OR REPLACE FUNCTION check_user_exists(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM auth.users WHERE id = user_id);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_user_exists(UUID) TO authenticated;

-- Grant necessary permissions on the notifications table
GRANT ALL ON notifications TO authenticated;

-- Ensure the HTTP extension is available for webhooks
CREATE EXTENSION IF NOT EXISTS http;

-- Set the webhook URL if needed
SET app.settings.webhook_url = 'https://kkcseqmpgzzrogatdoqi.supabase.co/functions/v1';
