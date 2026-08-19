-- Fix for the employee_status_history table missing appeal_reason column
ALTER TABLE employee_status_history 
  ADD COLUMN IF NOT EXISTS appeal_reason TEXT;

-- Fix for the notifications foreign key constraint issue
-- First, let's check if the RLS policy is enabled on the notifications table
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop the foreign key constraint if it exists
ALTER TABLE notifications 
  DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;

-- Add the constraint back with ON DELETE CASCADE
ALTER TABLE notifications 
  ADD CONSTRAINT notifications_user_id_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES auth.users(id) 
  ON DELETE CASCADE;

-- Create a policy to allow users to see their own notifications
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
CREATE POLICY "Users can view their own notifications" 
  ON notifications FOR SELECT 
  USING (auth.uid() = user_id);

-- Create a policy to allow users to insert notifications
DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;
CREATE POLICY "Users can insert notifications" 
  ON notifications FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

-- Create a policy to allow users to update their own notifications
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
CREATE POLICY "Users can update their own notifications" 
  ON notifications FOR UPDATE 
  USING (auth.uid() = user_id);

-- Create a policy to allow users to delete their own notifications
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;
CREATE POLICY "Users can delete their own notifications" 
  ON notifications FOR DELETE 
  USING (auth.uid() = user_id);
