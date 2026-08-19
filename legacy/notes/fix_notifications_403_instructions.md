# Fix Instructions for 403 Forbidden Error with Notifications

## Problem
After signup, when a user tries to select a company, they encounter a 403 Forbidden error when the app tries to POST to the Supabase notifications table.

## Root Cause
The issue is with the Row Level Security (RLS) policies for the notifications table. The current policies don't properly allow newly signed-up users to insert notifications.

## Solution
You need to update the RLS policies for the notifications table in Supabase.

### Option 1: Using Supabase CLI (Recommended)
1. Make sure you have the Supabase CLI installed and configured
2. Run the provided PowerShell script:
   ```powershell
   .\apply_rls_fix.ps1
   ```

### Option 2: Manual SQL Execution
1. Log in to your Supabase dashboard at https://app.supabase.com
2. Select your project (kkcseqmpgzzrogatdoqi)
3. Go to the SQL Editor
4. Create a new query
5. Copy and paste the following SQL:

```sql
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
-- This is the key policy that needs to be fixed
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

6. Click "Run" to execute the SQL

## Verification
After applying the fix, test the signup and company selection process again. The 403 Forbidden error should no longer occur.
