# Enterprise Flutter App with Supabase

A robust Flutter application for managing companies, employees, and role-based access control using Supabase as the backend.

## Features

- **Authentication:** Email/Password Login & Logout
- **User Types:** Company and Employee
- **Organization Types:** Mine/Supplier, Buyer, Transporter
- **Role-Based UI:** Different tabs visible based on user type and role
- **Profile Management:** Edit company/employee information
- **File Upload:** Upload profile pictures and documents
- **Employee Management:** Companies can view and manage their employees
- **Role Assignment:** Companies can assign roles to their employees
- **Realtime Updates:** Instant data synchronization across clients
- **Notifications:** Realtime notifications for important events
- **Presence:** Track online status of users
- **Broadcast:** Send and receive messages between connected clients

## Getting Started

### Prerequisites

- Flutter SDK (Beta channel, version ^3.8.0-278.1.beta)
- Dart SDK
- Supabase account

### Setup

1. **Clone the repository**

```bash
git clone <repository-url>
cd <repository-directory>
```

2. **Install dependencies**

```bash
flutter pub get
```

3. **Supabase configuration**

- This repo targets the live Supabase project only.
- The app reads its live configuration from `config/supabase.live.json`.
- The database source of truth is `supabase/migrations/`, with the canonical baseline in `supabase/migrations/20260327000100_canonical_platform_reset.sql`.
- Realtime, RLS, storage policies, RPCs, and required database objects are provisioned by the tracked migrations, not by ad hoc SQL snippets in the README.

4. **Run the app**

```bash
# Run on default port
flutter run --dart-define-from-file=config/supabase.live.json

# Run on specific port (61783)
flutter run -d chrome --web-port=61783 --web-hostname=localhost --dart-define-from-file=config/supabase.live.json

# Or use the provided scripts:
# Windows: run_web.bat
# PowerShell: run_web.ps1
```

For detailed testing instructions, see [TESTING.md](TESTING.md).

## Project Structure

```
lib/
├── core/
│   ├── config/
│   ├── routing/
│   ├── services/
│   ├── theme/
│   └── utils/
├── features/
│   ├── auth/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   ├── services/
│   │   └── widgets/
│   ├── company/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── services/
│   ├── employee/
│   │   ├── models/
│   │   ├── providers/
│   │   ├── screens/
│   │   └── services/
│   ├── home/
│   │   └── screens/
│   ├── profile/
│   │   └── screens/
│   └── tabs/
│       └── screens/
├── app.dart
└── main.dart
```

## User Flows

Self-service signup has been removed. All accounts are provisioned by an
administrator and the user signs in with the credentials they receive.

### Company User Flow

1. Created by a platform administrator via the super-admin console
   (Register Company workflow in `/super-admin/register-company`,
   backed by the `super-admin-create-company` edge function).
2. Log in with email and password.
3. View and manage employees.
4. Assign roles to employees.
5. Access role-based tabs based on organization type.

### Employee User Flow

1. Created by their company from the Employees screen
   (uses the `company-user-admin` edge function with
   `action: "create_employee"`).
2. Log in with email and password.
3. Access role-based tabs based on the assigned role.

## Role-Based Tab Visibility

### Mine/Supplier Organization

- **Company:** Security, Load Controller, Admin, Management, Mine/Supplier tabs
- **Security Employee:** Security tab
- **Load Controller Employee:** Load Controller tab
- **Supervisor/Foreman Employee:** Dashboard, Profile tabs
- **Admin Employee:** Manage Employees (user management only)
- **Management Employee:** Security, Load Controller, Admin, Management tabs

### Buyer Organization

- **Company:** Admin, Management, Buyer tabs
- **Admin Employee:** Admin tab
- **Management Employee:** Admin, Management tabs

### Transporter Organization

- **Company:** Driver, Admin, Management, Transporter tabs
- **Driver Employee:** Driver tab
- **Admin Employee:** Driver, Admin tabs
- **Management Employee:** Driver, Admin, Management tabs

## Realtime Features

### Subscribing to Database Changes

The app uses Supabase's realtime features to provide instant updates across clients. There are two main approaches:

1. **Using Channels with PostgresChanges**

```dart
// Create a channel
final realtimeChannel = supabase.channel('my_channel');

// Subscribe to changes
realtimeChannel
  .onPostgresChanges(
    event: PostgresChangeEvent.all,  // You can use .insert, .update, .delete instead of .all
    schema: 'public',
    table: 'companies',
    callback: (payload) {
      // Handle the change payload
      print('Change received: $payload');
    })
  .subscribe();

// Important: Remember to remove channel when no longer needed
supabase.removeChannel(realtimeChannel);
```

2. **Using Stream API**

```dart
// Create a stream subscription
final streamSubscription = supabase
  .from('companies')
  .stream(primaryKey: ['id'])
  .order('name')
  .limit(10)
  .listen((snapshot) {
    // Update your UI with the new data
    print('snapshot: $snapshot');
  });

// Remember to cancel the subscription when done
streamSubscription.cancel();
```

### Broadcast and Presence

The app also supports broadcast for sending messages between clients and presence for tracking online status:

```dart
// Broadcast example
final myChannel = supabase.channel('my_channel');

// Listen for broadcast messages
myChannel
  .on(
    RealtimeListenTypes.broadcast,
    ChannelFilter(event: 'test-event'),
    (payload, [ref]) {
      print('Received broadcast: $payload');
    },
  )
  .subscribe();

// Send broadcast message
myChannel.send(
  type: RealtimeListenTypes.broadcast,
  event: 'test-event',
  payload: {'message': 'Hello world!'},
);

// Presence example
myChannel
  .onPresence(
    event: PresenceEvent.sync,
    callback: (payload) {
      final onlineUsers = myChannel.presenceState();
      // Handle sync event
    })
  .subscribe(((status, [_]) async {
    if (status == RealtimeSubscribeStatus.subscribed) {
      // Send the current user's state upon subscribing
      await myChannel.track({'online_at': DateTime.now().toIso8601String()});
    }
  }));
```

### Testing Realtime Features

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

## Testing

### Running Tests

Run the tests with:

```bash
flutter test
```

### Testing the App

For detailed instructions on testing the app, including the employee sign-up and verification workflow, see [TESTING.md](TESTING.md).

### Troubleshooting

If you encounter any issues while running the app, refer to the [TROUBLESHOOTING.md](TROUBLESHOOTING.md) guide for solutions to common problems.

### Running on Port 61783

To ensure the app always runs on port 61783, use one of the following methods:

1. Use the provided batch file: `run_web.bat`
2. Use the PowerShell script: `run_web.ps1`
3. Run with VS Code using the "Flutter Web (Port 61783)" launch configuration
4. Run the command: `flutter run -d chrome --web-port=61783 --web-hostname=localhost`
