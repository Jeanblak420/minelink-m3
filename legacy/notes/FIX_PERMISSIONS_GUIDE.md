# Fix for 403 Forbidden Errors

This guide provides instructions for fixing the 403 Forbidden errors you're encountering with Supabase:

1. `POST https://kkcseqmpgzzrogatdoqi.supabase.co/rest/v1/rpc/check_user_exists 403 (Forbidden)`
2. `POST https://kkcseqmpgzzrogatdoqi.supabase.co/rest/v1/notifications 403 (Forbidden)`

## The Problem

These errors indicate that your application doesn't have the proper permissions to:
1. Call the `check_user_exists` RPC function
2. Insert records into the `notifications` table

## How to Fix

### Option 1: Using the Supabase Dashboard (Recommended)

1. **Log in to your Supabase Dashboard**
   - Go to https://app.supabase.com/project/kkcseqmpgzzrogatdoqi/sql

2. **Create a new SQL query**
   - Click on "New Query"
   - Copy and paste the contents of the `fix_permissions.sql` file
   - Click "Run" to execute the SQL

### Option 2: Using the Supabase CLI

If you have the Supabase CLI installed:

1. **Run the SQL file directly**
   ```bash
   supabase db execute --project-ref kkcseqmpgzzrogatdoqi --file fix_permissions.sql
   ```

## What This Fix Does

1. **Fixes RLS Policies for the Notifications Table**
   - Enables Row Level Security (RLS) for the notifications table
   - Creates a policy that allows any authenticated user to insert notifications
   - Creates policies for viewing, updating, and deleting notifications

2. **Fixes the `check_user_exists` Function**
   - Recreates the function with proper permissions
   - Grants execute permission to authenticated users

3. **Ensures Proper Table Permissions**
   - Grants all permissions on the notifications table to authenticated users

## Verifying the Fix

After applying the fix, you should no longer see the 403 Forbidden errors. To verify:

1. Refresh your application
2. Try to create a notification
3. Check the browser console for any errors

If you still encounter issues, please check the Supabase logs for more details.

## Additional Troubleshooting

If the fix doesn't resolve the issue, you may need to:

1. **Check Authentication**
   - Make sure your application is properly authenticated with Supabase
   - Verify that the auth token is being sent with your requests

2. **Check for Other RLS Policies**
   - There might be other RLS policies affecting your tables

3. **Restart Your Application**
   - Sometimes a full refresh or restart is needed after changing permissions

4. **Check Supabase Logs**
   - Look at the logs in the Supabase dashboard for more detailed error information
