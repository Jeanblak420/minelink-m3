# Action Tracking and Notification System Guide

This guide explains how to implement automatic action tracking and notifications for all user actions in the application.

## Overview

The action tracking system ensures that:
1. All user actions are tracked
2. Appropriate notifications are created for each action
3. Notifications are sent to the correct users based on their roles

## How to Implement Action Tracking for a New Feature

### Step 1: Add the ActionTrackingMixin to your Provider Notifier

```dart
import 'package:flutter_application_1/core/mixins/action_tracking_mixin.dart';

class YourFeatureNotifier extends StateNotifier<YourFeatureState> with ActionTrackingMixin {
  // Your notifier implementation
}
```

### Step 2: Track Actions in Your Methods

For any method that represents a user action, add action tracking:

```dart
Future<void> performUserAction({
  required String someParameter,
  // other parameters
}) async {
  try {
    // Perform the action logic
    // ...
    
    // Track the action
    if (_authState.user != null) {
      await trackUserAction(
        ref: ref,
        actionType: NotificationType.yourActionType, // Use an appropriate type
        actionTitle: 'Action Title',
        actionDescription: 'Detailed description of what happened',
        actionedBy: _authState.user!,
        companyId: companyId,
        targetUserId: targetUserId, // Optional - if action affects a specific user
        targetEntityId: entityId, // Optional - ID of the entity being acted upon
        metadata: {
          // Include any relevant data about the action
          'key': 'value',
        },
      );
    }
  } catch (e) {
    // Error handling
  }
}
```

### Step 3: Add a New NotificationType if Needed

If your feature requires a new type of notification, add it to the `NotificationType` enum:

```dart
// In lib/features/notifications/models/notification_model.dart
enum NotificationType {
  // Existing types...
  yourNewActionType,
  // Other new types...
  general;
}
```

Then add a label for the new type:

```dart
String get label {
  switch (this) {
    // Existing cases...
    case NotificationType.yourNewActionType:
      return 'Your Action Type Label';
    // Other cases...
  }
}
```

### Step 4: Add Icons and Colors for the New Notification Type

Update the notification display code to include icons and colors for your new notification type:

```dart
// In notification_management_screen.dart or notification_card.dart
switch (notification.type) {
  // Existing cases...
  case NotificationType.yourNewActionType:
    iconData = Icons.your_icon;
    iconColor = Colors.yourColor;
    break;
  // Other cases...
}
```

## Best Practices

1. **Be Descriptive**: Use clear, descriptive titles and messages for notifications
2. **Include Context**: Add relevant metadata to help users understand the action
3. **Consider Role-Based Visibility**: Think about which roles should see each notification
4. **Track All User Actions**: Any action that changes data or affects other users should be tracked
5. **Use Consistent Terminology**: Use consistent language across all notifications

## Example Implementation

Here's an example of implementing action tracking for a "create task" feature:

```dart
Future<void> createTask({
  required String taskTitle,
  required String description,
  required String assigneeId,
}) async {
  try {
    state = state.copyWith(isLoading: true, error: null);
    
    // Create the task
    final newTask = await _taskService.createTask(
      title: taskTitle,
      description: description,
      assigneeId: assigneeId,
      createdById: _authState.user!.id,
    );
    
    // Update state
    final updatedTasks = [...state.tasks, newTask];
    state = state.copyWith(tasks: updatedTasks, isLoading: false);
    
    // Track the action
    if (_authState.user != null) {
      await trackUserAction(
        ref: ref,
        actionType: NotificationType.taskCreated,
        actionTitle: 'Task Created',
        actionDescription: '${_authState.user!.fullName} created task "$taskTitle" and assigned it to ${newTask.assigneeName}',
        actionedBy: _authState.user!,
        companyId: companyId,
        targetUserId: assigneeId, // The assignee will get a direct notification
        targetEntityId: newTask.id,
        metadata: {
          'task_id': newTask.id,
          'task_title': taskTitle,
          'assignee_id': assigneeId,
        },
      );
    }
  } catch (e) {
    state = state.copyWith(
      isLoading: false,
      error: 'Failed to create task: ${e.toString()}',
    );
  }
}
```

## Checklist for New Features

- [ ] Add ActionTrackingMixin to the feature's notifier
- [ ] Add action tracking to all methods that represent user actions
- [ ] Add new NotificationType(s) if needed
- [ ] Add labels, icons, and colors for new notification types
- [ ] Test that notifications appear for the correct users
