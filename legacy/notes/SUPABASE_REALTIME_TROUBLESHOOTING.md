# Supabase Realtime Troubleshooting Guide

This guide provides detailed steps to diagnose and fix issues with Supabase realtime features in your Flutter application.

## Understanding Supabase Realtime

Supabase offers two main approaches for realtime features:

1. **Channels with PostgresChanges**: Subscribe to database changes
2. **Stream API**: Subscribe to database changes using a more Flutter-friendly API

Both approaches are affected by Row Level Security (RLS) policies, which can cause connection issues if not properly configured.

## Common Issues

### 1. Authentication Issues

Realtime features often require authentication to work properly, especially with RLS policies.

**Symptoms:**
- Channels subscribe but no data is received
- 403 Forbidden errors in the console

**Solutions:**
- Ensure the user is authenticated before subscribing to channels
- Check that the authenticated user has the necessary permissions according to RLS policies

### 2. RLS Policy Issues

RLS policies can prevent realtime connections if they're too restrictive.

**Symptoms:**
- Broadcast channels work but PostgresChanges channels don't
- No data is received despite successful subscription

**Solutions:**
- Review your RLS policies to ensure they allow the necessary access
- Temporarily disable RLS for testing purposes (not recommended for production)
- Use the debug tools to identify which policies are causing issues

### 3. Publication Configuration Issues

Tables must be added to the `supabase_realtime` publication to enable realtime features.

**Symptoms:**
- No data is received despite successful subscription
- Channel subscribes but no changes are detected

**Solutions:**
- Ensure all tables are added to the `supabase_realtime` publication
- Set `REPLICA IDENTITY` to `FULL` for all tables to get both old and new values

### 4. Network and CORS Issues

Network and CORS issues can prevent realtime connections.

**Symptoms:**
- Connection errors in the console
- Channels fail to subscribe

**Solutions:**
- Check your network connection
- Ensure CORS is properly configured in your Supabase project
- Add `localhost:63965` to the allowed origins in your Supabase project settings

## Diagnostic Tools

We've provided several tools to help diagnose realtime issues:

### 1. Debug Realtime Page

Access the debug page by clicking the bug icon in the app bar. This page provides:

- Connection status information
- Tools to test different types of channels
- A diagnostic test runner
- Debug mode toggle

### 2. Standalone Test Script

Run the standalone test script to test realtime features outside of the app:

```bash
dart test_realtime.dart
```

### 3. Supabase Debugger

The `SupabaseDebugger` class provides diagnostic tools to identify issues:

```dart
// Run all diagnostic tests
final report = await SupabaseDebugger.runDiagnostics();

// Show a diagnostic report dialog
SupabaseDebugger.showDiagnosticReport(context);
```

## Step-by-Step Troubleshooting

Follow these steps to diagnose and fix realtime issues:

### 1. Verify Authentication

```dart
final user = Supabase.instance.client.auth.currentUser;
print('Current user: ${user?.id}');
```

### 2. Test with a Broadcast Channel

Broadcast channels are not affected by RLS policies, so they're a good way to test basic connectivity:

```dart
final channel = Supabase.instance.client.channel('test_broadcast');
channel
  .on(
    RealtimeListenTypes.broadcast,
    ChannelFilter(event: 'test-event'),
    (payload, [_]) {
      print('Received broadcast: $payload');
    },
  )
  .subscribe();

// Later, send a message
channel.send(
  type: RealtimeListenTypes.broadcast,
  event: 'test-event',
  payload: {'message': 'Hello world!'},
);
```

### 3. Check RLS Policies

Review your RLS policies to ensure they allow the necessary access:

```sql
-- Example: Allow users to access their own data
CREATE POLICY "Users can view their own data"
ON my_table
FOR SELECT
USING (auth.uid() = user_id);
```

### 4. Enable Realtime for Tables

Ensure all tables are added to the `supabase_realtime` publication:

```sql
-- Enable realtime for tables
BEGIN;
-- Remove the supabase_realtime publication if it exists
DROP PUBLICATION IF EXISTS supabase_realtime;
-- Re-create the supabase_realtime publication with no tables
CREATE PUBLICATION supabase_realtime;
COMMIT;

-- Add tables to the publication
ALTER PUBLICATION supabase_realtime ADD TABLE companies;
ALTER PUBLICATION supabase_realtime ADD TABLE employees;
ALTER PUBLICATION supabase_realtime ADD TABLE notifications;

-- Set replica identity to full for all tables
ALTER TABLE companies REPLICA IDENTITY FULL;
ALTER TABLE employees REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;
```

### 5. Enable Debug Mode

Enable debug mode to get more detailed logs:

```dart
// In your code
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
  debug: true, // Enable debug mode
);

// Or use the debug page to toggle debug mode at runtime
```

### 6. Check for Specific Table Permissions

If you're still having issues, you might need to check if your authenticated user has permissions to access the specific rows you're trying to subscribe to:

```sql
-- Example: Allow users to only access their own companies
CREATE POLICY "Users can only access their own companies"
ON companies
FOR SELECT
TO authenticated
USING (user_id = auth.uid());
```

## Advanced Troubleshooting

### Using the Supabase Dashboard

The Supabase dashboard provides tools to help diagnose realtime issues:

1. Go to the Database section
2. Check the Replication tab to ensure realtime is enabled
3. Review the Policies tab to ensure RLS policies are correctly configured
4. Use the SQL Editor to run diagnostic queries

### Checking Realtime Logs

If you have access to the Supabase instance logs, check for realtime-related errors:

1. Look for errors related to the `supabase_realtime` publication
2. Check for authentication errors
3. Look for RLS policy violations

## Conclusion

Realtime features in Supabase are powerful but can be tricky to set up correctly. By following this guide and using the provided diagnostic tools, you should be able to identify and fix most realtime issues.

If you're still having problems after trying all these steps, consider:

1. Checking the Supabase documentation for updates
2. Asking for help on the Supabase Discord or GitHub
3. Simplifying your realtime implementation to isolate the issue
