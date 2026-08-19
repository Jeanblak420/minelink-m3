# Supabase Realtime Features Implementation

This document provides a detailed overview of the realtime database features implemented in the application using Supabase.

## Overview

We've implemented a comprehensive realtime database system that provides:

1. **Realtime Data Synchronization**: Instant updates across all connected clients when data changes
2. **Broadcast Messaging**: Send and receive messages between connected clients
3. **Presence Tracking**: Monitor online status of users
4. **Centralized Database Service**: A unified approach to database operations with realtime capabilities

## Implementation Details

### Core Database Service

The `DatabaseService` class (`lib/core/services/database_service.dart`) serves as the central point for all database operations with realtime capabilities:

- **CRUD Operations**: Standard database operations (get, insert, update, delete)
- **Realtime Subscriptions**: Subscribe to database changes using channels
- **Stream Subscriptions**: Subscribe to database changes using streams
- **Broadcast**: Send and receive messages between clients
- **Presence**: Track online status of users

### Table-Specific Database Services

We've created specialized database services for each major entity in the application:

1. **CompanyDatabaseService**: Handles company-related operations with realtime support
2. **EmployeeDatabaseService**: Handles employee-related operations with realtime support
3. **NotificationDatabaseService**: Handles notification-related operations with realtime support

### Realtime Setup

The `RealtimeSetup` utility (`lib/core/utils/realtime_setup.dart`) enables realtime for all tables in the application:

```dart
// Enable realtime for all tables
await RealtimeSetup.enableRealtimeForAllTables();
```

This is automatically called when the application starts in `main.dart`.

### Testing Utilities

We've provided tools to test the realtime features:

1. **RealtimeTest**: A utility class for testing realtime features
2. **Command-line Tool**: A command-line tool for testing realtime features (`bin/realtime_test.dart`)

## Usage Examples

### Subscribing to Database Changes

```dart
// Using channels
final channel = _databaseService.createSubscription(
  'company_updates_$companyId',
  'companies',
  event: PostgresChangeEvent.update,
  callback: (data) {
    if (data['id'] == companyId) {
      onUpdate(Company.fromJson(data));
    }
  },
);

// Using streams
_databaseService.createStreamSubscription(
  'company_employees_$companyId',
  'employees',
  primaryKey: ['id'],
  filters: {'company_id': companyId},
  callback: (data) {
    final employees = data.map((json) => Employee.fromJson(json)).toList();
    onUpdate(employees);
  },
);
```

### Broadcast Messaging

```dart
// Create a broadcast channel
final channel = _databaseService.createBroadcastChannel(
  'chat_channel',
  eventName: 'new_message',
  onReceive: (payload) {
    // Handle the received message
    print('New message: ${payload['message']}');
  },
);

// Send a broadcast message
await _databaseService.sendBroadcastMessage(
  'chat_channel',
  'new_message',
  {
    'message': 'Hello, world!',
    'sender': 'User123',
    'timestamp': DateTime.now().toIso8601String(),
  },
);
```

### Presence Tracking

```dart
// Create a presence channel
final channel = _databaseService.createPresenceChannel(
  'online_users',
  onSync: (state) {
    // Handle the complete list of online users
    print('Online users: $state');
  },
  onJoin: (joins) {
    // Handle users who just came online
    print('Users joined: $joins');
  },
  onLeave: (leaves) {
    // Handle users who just went offline
    print('Users left: $leaves');
  },
  userState: {
    'user_id': currentUserId,
    'online_at': DateTime.now().toIso8601String(),
    'status': 'active',
  },
);

// Update presence state
await _databaseService.updatePresenceState(
  'online_users',
  {
    'user_id': currentUserId,
    'online_at': DateTime.now().toIso8601String(),
    'status': 'away',
  },
);
```

## Testing Realtime Features

You can test the realtime features using the provided command-line tool:

```bash
# Test realtime subscription to a table
dart bin/realtime_test.dart subscription companies id

# Test stream subscription to a table
dart bin/realtime_test.dart stream employees id

# Test broadcast feature
dart bin/realtime_test.dart broadcast

# Test presence feature
dart bin/realtime_test.dart presence

# Run all tests
dart bin/realtime_test.dart all
```

## Enabling Realtime in Supabase

To enable realtime for tables in Supabase, run the following SQL:

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

This is automatically executed when the application starts through the `RealtimeSetup` utility.

## Best Practices

1. **Always clean up subscriptions**: Use `dispose()` methods to clean up subscriptions when they're no longer needed
2. **Use unique channel names**: Ensure channel names are unique to avoid conflicts
3. **Handle errors gracefully**: Implement proper error handling for realtime operations
4. **Limit subscription scope**: Subscribe only to the data you need to minimize network traffic
5. **Use caching**: Combine realtime updates with caching for optimal performance

## Conclusion

The implemented realtime features provide a robust foundation for building interactive, collaborative applications with Supabase. The centralized approach ensures consistency and maintainability, while the specialized services provide domain-specific functionality.
