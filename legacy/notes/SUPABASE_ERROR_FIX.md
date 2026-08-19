# Supabase Error Fix Guide

This guide provides instructions for fixing the following Supabase errors:

1. `POST https://kkcseqmpgzzrogatdoqi.supabase.co/rest/v1/employee_status_history 400 (Bad Request)`
2. `POST https://kkcseqmpgzzrogatdoqi.supabase.co/rest/v1/notifications 409 (Conflict)`

## Automatic Fix

The easiest way to fix these issues is to use the built-in debug screen:

1. Navigate to the Debug Screen in the app
2. Click the "Apply Database Fixes" button
3. Wait for the confirmation message
4. Test the fixes by clicking "Test Employee Status History" and "Test Notifications"

## Manual Fix Using SQL Editor

If the automatic fix doesn't work, you can manually apply the fixes using the Supabase SQL Editor:

1. Go to the [Supabase Dashboard](https://app.supabase.io)
2. Select your project (kkcseqmpgzzrogatdoqi)
3. Navigate to the SQL Editor in the left sidebar
4. Copy and paste the following SQL script:

```sql
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
```

5. Click "Run" to execute the script

## Fix Using PowerShell Script

If you have the Supabase CLI installed, you can run the provided PowerShell script:

1. Open PowerShell
2. Navigate to the project directory
3. Run the script:

```powershell
.\apply_fixes.ps1
```

## Explanation of Errors

### 400 Bad Request for employee_status_history

This error occurs because the model is trying to insert fields that don't exist in the database table. The fix adds the missing columns:

- `actioned_by_id`
- `actioned_by_name`
- `assigned_role`

### 409 Conflict for notifications

This error occurs due to RLS (Row Level Security) policy conflicts. The fix updates the RLS policies to allow authenticated users to insert notifications.

## Verifying the Fix

After applying the fixes, you can verify that they worked by:

1. Using the Debug Screen to test insertions
2. Checking the Supabase Table Editor to see if new records are being created
3. Monitoring the browser console for any remaining errors

If you continue to experience issues, please contact the development team for further assistance.
