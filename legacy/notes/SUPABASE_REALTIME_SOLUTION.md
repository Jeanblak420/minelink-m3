# Supabase Realtime Troubleshooting Solution

Based on our testing, we've identified the key issues with your Supabase realtime setup and have solutions to fix them.

## Diagnosis Results

1. **Basic Database Connectivity**: ✅ Working
   - We can successfully query the `companies` and `employees` tables
   - Data is being returned correctly

2. **Realtime Channel Connection**: ✅ Working
   - We can create and subscribe to realtime channels
   - The channel status shows "RealtimeSubscribeStatus.subscribed"

3. **SQL Function Access**: ❌ Not Working
   - The `run_sql` function is not available in your Supabase project
   - This prevents us from directly modifying the realtime publication

4. **Supabase Version Compatibility**: ⚠️ Issues
   - Your project is using an older version of Supabase that has different API methods
   - This causes compatibility issues with newer code

## Solutions

### 1. Enable Realtime in Supabase Dashboard

Since we can't use the `run_sql` function, you'll need to enable realtime through the Supabase dashboard:

1. Log in to your Supabase dashboard at https://app.supabase.io
2. Select your project
3. Go to Database → Replication
4. Make sure the "Realtime" option is enabled
5. Add the following tables to the publication:
   - `companies`
   - `employees`
   - `notifications`

### 2. Set REPLICA IDENTITY to FULL

For each table, you need to set REPLICA IDENTITY to FULL to get both old and new values in realtime events:

1. In the Supabase dashboard, go to the SQL Editor
2. Run the following SQL commands:

```sql
ALTER TABLE companies REPLICA IDENTITY FULL;
ALTER TABLE employees REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;
```

### 3. Update Your Code to Use the Correct Supabase API

Based on our testing, your Supabase version requires a slightly different approach to realtime:

```dart
// Create a channel
final channel = supabase.channel('your_channel_name');

// Subscribe to the channel
channel.subscribe((status, [_]) {
  print('Channel status: $status');
});

// To listen for PostgreSQL changes (add this before subscribe)
channel.postgres()
  .table('companies')
  .on(PostgresAction.insert, (payload) {
    print('Insert: $payload');
  })
  .on(PostgresAction.update, (payload) {
    print('Update: $payload');
  })
  .on(PostgresAction.delete, (payload) {
    print('Delete: $payload');
  });
```

### 4. Check RLS Policies

Your RLS policies appear to be correctly set up, but make sure they allow the necessary access:

- For SELECT operations, your policies allow everyone to view companies and employees
- For INSERT, UPDATE, and DELETE operations, your policies restrict access based on user ID
- Make sure the authenticated user has the necessary permissions for the operations you're trying to perform

### 5. Use the Minimal Test App

We've created a minimal test app (`lib/minimal_app.dart`) that you can use to test your Supabase realtime setup:

```bash
flutter run -d chrome --web-port=63965 --web-hostname=localhost lib/minimal_app.dart
```

This app provides simple tools to:
- Test database connectivity
- Test realtime channel connections
- Check authentication status

## Implementation Steps

1. **Update Supabase Configuration**:
   - Log in to the Supabase dashboard and enable realtime as described above

2. **Update Your Code**:
   - Use the correct channel subscription method with the `[_]` parameter
   - Use the `postgres()` method to listen for PostgreSQL changes

3. **Test with the Minimal App**:
   - Run the minimal app to verify that realtime is working
   - Try updating a record and see if the realtime channel receives the update

4. **Integrate into Your Main App**:
   - Once you've confirmed that realtime is working in the minimal app, apply the same patterns to your main app

## Example Implementation

Here's a complete example of how to implement realtime in your app:

```dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeExample extends StatefulWidget {
  const RealtimeExample({Key? key}) : super(key: key);

  @override
  State<RealtimeExample> createState() => _RealtimeExampleState();
}

class _RealtimeExampleState extends State<RealtimeExample> {
  final _supabase = Supabase.instance.client;
  RealtimeChannel? _channel;
  String _messages = '';
  
  @override
  void initState() {
    super.initState();
    _setupRealtime();
  }
  
  void _setupRealtime() {
    // Create a channel
    _channel = _supabase.channel('companies_channel');
    
    // Listen for PostgreSQL changes
    _channel!.postgres()
      .table('companies')
      .on(PostgresAction.insert, (payload) {
        _addMessage('Company inserted: ${payload['new']['company_name']}');
      })
      .on(PostgresAction.update, (payload) {
        _addMessage('Company updated: ${payload['new']['company_name']}');
      })
      .on(PostgresAction.delete, (payload) {
        _addMessage('Company deleted: ${payload['old']['company_name']}');
      });
    
    // Subscribe to the channel
    _channel!.subscribe((status, [_]) {
      _addMessage('Channel status: $status');
    });
  }
  
  void _addMessage(String message) {
    setState(() {
      _messages = '$message\n$_messages';
    });
    print(message);
  }
  
  Future<void> _updateCompany() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        _addMessage('Not authenticated, cannot update company');
        return;
      }
      
      // Get the company for this user
      final companies = await _supabase
          .from('companies')
          .select()
          .eq('user_id', user.id)
          .limit(1);
      
      if (companies.isEmpty) {
        _addMessage('No company found for this user');
        return;
      }
      
      final companyId = companies[0]['id'];
      
      // Update the company
      await _supabase
          .from('companies')
          .update({'updated_at': DateTime.now().toIso8601String()})
          .eq('id', companyId);
      
      _addMessage('Company updated successfully');
    } catch (e) {
      _addMessage('Error updating company: $e');
    }
  }
  
  @override
  void dispose() {
    // Clean up the channel when the widget is disposed
    if (_channel != null) {
      _supabase.removeChannel(_channel!);
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Realtime Example'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _updateCompany,
              child: const Text('Update Company'),
            ),
            const SizedBox(height: 16),
            const Text('Realtime Messages:', style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  child: Text(_messages),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

## Conclusion

Based on our testing, the core issue is that your Supabase project is using a different API version than what some of your code is expecting. By updating your code to use the correct API methods and ensuring that realtime is properly enabled in the Supabase dashboard, you should be able to get realtime working in your app.

The minimal test app we've created demonstrates that basic realtime functionality is working, and you can use it as a reference for implementing realtime in your main app.
