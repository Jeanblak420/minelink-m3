# Fixing the run_sql RPC Function Error

This document explains how to fix the 404 (Not Found) error when calling the `run_sql` RPC endpoint in your Supabase project.

## Problem

You're encountering the following error:
```
POST https://kkcseqmpgzzrogatdoqi.supabase.co/rest/v1/rpc/run_sql 404 (Not Found)
```

This error occurs because the `run_sql` function doesn't exist in your Supabase database. This function is used in several places in your code to execute SQL queries directly against the database.

## Solution

We've created a SQL function that can be added to your Supabase database to fix this issue. The function is defined in `supabase/migrations/20250515000000_create_run_sql_function.sql`.

### How to Apply the Fix

1. Run the provided script to open the HTML page with the SQL:
   ```
   ./fix_run_sql.bat
   ```
   or
   ```
   ./fix_run_sql.ps1
   ```

2. Follow the instructions on the page:
   - Click the "Copy SQL" button to copy the SQL to your clipboard
   - Go to the Supabase SQL Editor (a link is provided on the page)
   - Create a new query
   - Paste the SQL into the editor
   - Click "Run" to execute the query

3. Alternatively, you can open the Supabase SQL Editor directly:
   ```
   ./open_supabase_sql_editor.bat
   ```

   Then copy the SQL from `run_sql_function.html` and paste it into the SQL Editor.

## Code Changes

We've also updated your code to use a new `SqlExecutor` utility class that provides a safer and more robust way to execute SQL queries. This class will use the `run_sql` function you've just created.

The following files have been updated:
- `lib/core/utils/sql_executor.dart` (new file)
- `lib/core/utils/realtime_setup_helper.dart`
- `lib/debug_supabase.dart`
- `lib/debug_simple.dart`

## Testing the Fix

After applying the fix, you can test it by:

1. Running your application
2. Going to the debug screen
3. Clicking on "Check RLS Policies" or "Enable Realtime"

If the fix was successful, you should no longer see the 404 error.

## Security Considerations

The `run_sql` function is created with `SECURITY DEFINER`, which means it runs with the privileges of the user who created it. This is necessary to allow the function to execute arbitrary SQL queries.

In a production environment, you might want to restrict the types of queries that can be executed through this function to prevent potential security issues.

## Need Help?

If you encounter any issues with this fix, please:

1. Check the Supabase logs for any errors
2. Make sure the function was created successfully
3. Try running a simple query through the function to test it

If you still have issues, you can contact support or open an issue on the project repository.
