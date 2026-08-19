-- Fix for the notifications foreign key constraint issue
-- This script addresses the error: "insert or update on table "notifications" violates foreign key constraint "notifications_user_id_fkey""

-- First, enable RLS on the notifications table
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

-- Drop the foreign key constraints if they exist
ALTER TABLE notifications 
  DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;

ALTER TABLE notifications 
  DROP CONSTRAINT IF EXISTS notifications_actioned_by_id_fkey;

-- Add the constraints back with ON DELETE CASCADE
ALTER TABLE notifications 
  ADD CONSTRAINT notifications_user_id_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES auth.users(id) 
  ON DELETE CASCADE;

ALTER TABLE notifications 
  ADD CONSTRAINT notifications_actioned_by_id_fkey 
  FOREIGN KEY (actioned_by_id) 
  REFERENCES auth.users(id) 
  ON DELETE SET NULL;

-- Make sure all RLS policies are properly set up
-- Drop existing policies if they exist to avoid conflicts
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Any authenticated user can insert notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can delete their own notifications" ON notifications;
DROP POLICY IF EXISTS "Companies can insert notifications" ON notifications;

-- Create policy to allow users to see their own notifications
CREATE POLICY "Users can view their own notifications" 
  ON notifications FOR SELECT 
  USING (auth.uid() = user_id);

-- Create policy to allow any authenticated user to insert notifications
-- This is necessary for cross-user notifications
CREATE POLICY "Any authenticated user can insert notifications" 
  ON notifications FOR INSERT 
  WITH CHECK (auth.role() = 'authenticated');

-- Create policy to allow users to update their own notifications
CREATE POLICY "Users can update their own notifications" 
  ON notifications FOR UPDATE 
  USING (auth.uid() = user_id);

-- Create policy to allow users to delete their own notifications
CREATE POLICY "Users can delete their own notifications" 
  ON notifications FOR DELETE 
  USING (auth.uid() = user_id);

-- Create a function to validate user_id before insertion
CREATE OR REPLACE FUNCTION validate_notification_user_id()
RETURNS TRIGGER AS $$
BEGIN
  -- Check if the user_id exists in auth.users
  IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = NEW.user_id) THEN
    RAISE EXCEPTION 'User ID % does not exist in auth.users table', NEW.user_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to validate user_id before insertion
DROP TRIGGER IF EXISTS validate_notification_user_id_trigger ON notifications;
CREATE TRIGGER validate_notification_user_id_trigger
  BEFORE INSERT ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION validate_notification_user_id();

-- Create a function to check if a user exists
CREATE OR REPLACE FUNCTION check_user_exists(user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (SELECT 1 FROM auth.users WHERE id = user_id);
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION check_user_exists(UUID) TO authenticated;
