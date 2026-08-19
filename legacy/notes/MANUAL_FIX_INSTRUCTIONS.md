# Manual Fix Instructions for Employee Role Assignment Issues

Since there was an issue with the Supabase CLI, please follow these manual steps to fix the database issues:

## Step 1: Access the Supabase SQL Editor

1. Go to the [Supabase Dashboard](https://app.supabase.io)
2. Select your project (kkcseqmpgzzrogatdoqi)
3. Navigate to the SQL Editor in the left sidebar

## Step 2: Run the SQL Fix Script

Copy and paste the following SQL script into the editor and run it:

```sql
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
```

## Step 3: Verify the Fix

After running the SQL script:

1. Refresh your Flutter application
2. Try assigning a role to an employee again
3. Check if the operation completes without errors

If you continue to experience issues, please check the browser console for any new error messages and provide those details for further troubleshooting.
