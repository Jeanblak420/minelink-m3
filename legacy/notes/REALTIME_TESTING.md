# Real-Time Functionality Testing Guide

This guide provides instructions on how to test the real-time functionality implemented in the application.

## Prerequisites

1. Make sure you have the latest version of the application code.
2. Ensure that Supabase is properly configured with the required tables and policies.
3. Run the Supabase migrations to set up the real-time functionality:
   ```
   supabase db push
   ```

## Testing the Accept/Decline Buttons

1. **Setup Test Environment**:
   - Create a company account
   - Create an employee account
   - Have the employee request to join the company

2. **Test Accept Button**:
   - Log in as the company
   - Navigate to the "Manage Employees" section
   - Verify that the green "Accept" button is visible next to each pending employee request
   - Click the "Accept" button for an employee
   - Verify that a loading indicator appears
   - Once the action completes, verify that the employee is moved to the appropriate section
   - Verify that the UI updates without requiring a manual refresh

3. **Test Decline Button**:
   - Log in as the company
   - Navigate to the "Manage Employees" section
   - Click the red "Decline" button for an employee
   - Verify that a confirmation dialog appears
   - Confirm the decline action
   - Verify that a loading indicator appears
   - Once the action completes, verify that the employee is removed from the list
   - Verify that the UI updates without requiring a manual refresh

## Testing the Notification Bell Animation

1. **Setup Test Environment**:
   - Create a company account
   - Create an employee account
   - Have the employee request to join the company

2. **Test Notification Bell Animation**:
   - Log in as the employee
   - Have the company accept or decline the request (using another browser or device)
   - Verify that the notification bell animates when a new notification is received
   - Verify that the red circle with the unread count appears on the bell
   - Click the bell to view notifications
   - Verify that the unread count is updated correctly

## Testing the "Actioned By" Feature

1. **Setup Test Environment**:
   - Create a company account with CEO details
   - Create an employee account
   - Have the employee request to join the company

2. **Test "Actioned By" Display**:
   - Log in as the company
   - Accept or decline an employee request
   - Log in as the employee
   - Navigate to the status screen
   - Click "Check Status"
   - Verify that the expanded status section shows "Actioned by: [CEO First Name] [CEO Last Name]"

## Testing the Check Status Button

1. **Setup Test Environment**:
   - Create a company account
   - Create an employee account
   - Have the employee request to join the company

2. **Test Check Status Button**:
   - Log in as the employee
   - Navigate to the waiting screen
   - Click the "Check Status" button
   - Verify that the status section expands to show the current status
   - Have the company accept or decline the request (using another browser or device)
   - Verify that the status updates in real-time without requiring a manual refresh

## Testing Form Field Attributes

1. **Test Form Field Attributes**:
   - Open the browser's developer tools
   - Inspect the form fields in the company profile and employee profile forms
   - Verify that each input field has appropriate autofill hints
   - Test browser autofill functionality to ensure it works correctly

## Testing Employee Request Wording

1. **Test Employee Request Wording**:
   - Create a new employee account
   - Select a company to join
   - Verify that the confirmation message matches the specified wording:
     "Your request to be added as an employee under [Company Name] has been submitted to management for verification. Once your employment is confirmed, an appropriate role will be assigned to you, granting access to the application features associated with your assigned role. These features will become available instantly upon role assignment. We encourage you to check back periodically for updates on your role."

## Troubleshooting Real-Time Issues

If you encounter issues with real-time functionality:

1. **Check Supabase Realtime Configuration**:
   - Verify that the realtime publication includes all required tables
   - Check that RLS policies allow access to the required tables

2. **Enable Debug Mode**:
   - Set the `debug` parameter to `true` when creating subscriptions
   - Check the console logs for any errors or issues

3. **Check Network Connectivity**:
   - Ensure that WebSocket connections are not blocked by firewalls
   - Verify that the client has a stable internet connection

4. **Verify Database Triggers**:
   - Check that the database triggers for status updates are properly configured
   - Test the triggers manually to ensure they work as expected
