# Troubleshooting Guide

This guide covers common issues you might encounter while running the app and how to resolve them.

## Database Permission Issues

### 403 Forbidden Error for Notifications Table

**Error Message:**
```
kkcseqmpgzzrogatdoqi.supabase.co/rest/v1/notifications:1 Failed to load resource: the server responded with a status of 403 ()
```

**Solution:**
This error occurs when the notifications table doesn't exist or has incorrect permissions. To fix it:

1. Open your Supabase project dashboard
2. Go to the SQL Editor
3. Run the SQL script in `supabase_notifications_setup.sql`
4. Restart the app

The script creates the notifications table and sets up the proper Row Level Security (RLS) policies to allow users to interact with their notifications.

### Other 403 Forbidden Errors

If you encounter 403 errors for other tables:

1. Check if the table exists in your Supabase database
2. Verify that the table has Row Level Security (RLS) policies set up correctly
3. Make sure the authenticated user has the necessary permissions according to the RLS policies

### Additional Steps for 403 Errors

- Ensure that the Row Level Security (RLS) policies are correctly configured for the `notifications` table.
- Verify that the API key being used has the necessary permissions to access the table.

## Authentication Issues

### Unable to Sign Up or Sign In

If you're having trouble with authentication:

1. Check your Supabase URL and anon key in `lib/core/config/supabase_config.dart`
2. Verify that email authentication is enabled in your Supabase project settings
3. Check if there are any email confirmation requirements that might be preventing login

## App Not Running on Port 61783

If the app is not running on port 61783:

1. Make sure you're using one of the provided methods to run the app:
   - `run_web.bat` file
   - `run_web.ps1` PowerShell script
   - VS Code "Flutter Web (Port 61783)" launch configuration
   - Command: `flutter run -d chrome --web-port=61783 --web-hostname=localhost`

2. Check if another process is already using port 61783. You can check this with:
   ```
   netstat -ano | findstr :61783
   ```

   If a process is using the port, you'll need to terminate it before running the app:

   ```
   # Look for the PID (Process ID) in the last column of the netstat output
   # Find the line with "LISTENING" status and note the PID (e.g., 788)

   # Kill the process using the PID
   taskkill /F /PID <PID>

   # Example:
   taskkill /F /PID 788
   ```

   After killing the process, try running the app again.

## Missing Dependencies

If you encounter errors about missing packages:

1. Run `flutter pub get` to install all dependencies
2. If specific packages are mentioned in the error, try installing them individually:
   ```
   flutter pub add package_name
   ```

## Browser Issues

If the app doesn't load properly in Chrome:

1. Try clearing your browser cache and cookies
2. Disable browser extensions that might interfere with the app
3. Try running the app in an incognito/private window

## Employee Role Assignment Not Working

If the employee role assignment process isn't working:

1. Make sure the notifications table is properly set up (see above)
2. Check the browser console for any errors
3. Verify that both the company and employee users exist in the database
4. Check that the company has permission to assign roles to employees
