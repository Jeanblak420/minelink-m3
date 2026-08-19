# Action Tracking System

## Overview

The Action Tracking System ensures that all user actions in the application automatically generate notifications for the appropriate user roles. This system provides transparency and accountability by tracking who did what and when.

## Key Features

- **Automatic Notification Creation**: All user actions generate notifications
- **Role-Based Visibility**: Notifications are sent to users based on their roles
- **Comprehensive Tracking**: Captures who performed the action, what was done, and when
- **Metadata Support**: Includes relevant context with each notification
- **Consistent Implementation**: Standardized approach across the application

## Getting Started

1. **Install the Pre-Commit Hook**:
   ```
   ./scripts/install-hooks.ps1
   ```

2. **Read the Developer Guide**:
   See [Action Tracking Guide](action_tracking_guide.md) for detailed implementation instructions.

3. **Use the ActionTrackingMixin**:
   Add the mixin to your provider notifiers to easily track actions.

## System Components

- **ActionTrackingService**: Core service for tracking actions and creating notifications
- **ActionTrackingMixin**: Mixin for provider notifiers to easily track actions
- **Pre-Commit Hook**: Checks for action tracking in new code
- **Documentation**: Comprehensive guide for developers

## Implementation Example

Here's a simple example of tracking a user action:

```dart
Future<void> createTask(String title, String assigneeId) async {
  try {
    // Perform the action
    final task = await _taskService.createTask(title, assigneeId);
    
    // Track the action
    if (_authState.user != null) {
      await trackUserAction(
        ref: _ref,
        actionType: NotificationType.taskCreated,
        actionTitle: 'Task Created',
        actionDescription: 'Task "$title" was created and assigned to user',
        actionedBy: _authState.user!,
        companyId: companyId,
        targetUserId: assigneeId,
        metadata: {'task_id': task.id, 'task_title': title},
      );
    }
  } catch (e) {
    // Error handling
  }
}
```

## Best Practices

1. **Track All User Actions**: Any action that changes data or affects other users
2. **Be Descriptive**: Use clear titles and messages
3. **Include Context**: Add relevant metadata
4. **Consider Role-Based Visibility**: Think about which roles should see each notification
5. **Use Consistent Terminology**: Use consistent language across notifications

## Troubleshooting

If you see warnings from the pre-commit hook about missing action tracking:

1. Check if the method represents a user action
2. If it does, add action tracking using the `trackUserAction` method
3. If it doesn't (e.g., it's a helper method), you can ignore the warning

## Need Help?

See the [Action Tracking Guide](action_tracking_guide.md) for detailed implementation instructions.
