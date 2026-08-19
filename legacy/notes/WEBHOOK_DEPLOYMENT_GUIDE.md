# Webhook Deployment Guide

This guide explains how to deploy the Supabase Database Webhooks implementation for real-time features in our application.

## Prerequisites

- Supabase CLI installed
- Access to the Supabase project
- Flutter development environment set up

## Deployment Steps

### 1. Deploy Edge Functions

First, deploy the Edge Functions that will handle the webhook calls:

```bash
./deploy-webhooks.bat
```

This script will:
1. Deploy the `employee-webhook` function
2. Deploy the `company-webhook` function
3. Deploy the `notification-webhook` function
4. Apply the database migrations

### 2. Set Up Database Triggers

The database migrations will set up the necessary triggers and functions for the webhook system. If you need to run them manually, you can use the following SQL:

```sql
-- Run this in the Supabase SQL Editor
\i supabase/migrations/20240901000000_setup_database_webhooks.sql
```

### 3. Test the Webhooks

After deploying the webhooks, you should test them to make sure they're working correctly:

1. Create a new company
2. Create a new employee
3. Link the employee to the company
4. Assign a role to the employee
5. Check that notifications are created correctly

### 4. Update Client Code

The client code has already been updated to use the webhook system. If you need to make additional changes, here are the key files:

- `lib/core/services/database_service.dart`: The central service for database operations
- `lib/core/services/webhook_service.dart`: The service for handling webhook responses
- `lib/core/controllers/webhook_controller.dart`: The controller for UI updates
- `lib/features/company/services/company_database_service.dart`: Company-specific database operations
- `lib/features/employee/services/employee_database_service.dart`: Employee-specific database operations
- `lib/features/notifications/services/notification_database_service.dart`: Notification-specific database operations

### 5. Clean Up Old Realtime Code

The old realtime code has been removed from the codebase. If you find any remaining references to realtime features, you should remove them:

- Remove any imports of `realtime_setup_helper.dart`
- Remove any calls to `enableRealtimeForAllTables()`
- Remove any uses of `createSubscription()` or `createStreamSubscription()`
- Remove any uses of `RealtimeChannel`

### 6. Monitor Webhook Performance

After deploying the webhooks, you should monitor their performance:

1. Check the Edge Function logs in the Supabase dashboard
2. Monitor the database performance
3. Check for any errors in the client application

### 7. Troubleshooting

If you encounter issues with the webhook implementation:

1. Check the Edge Function logs in the Supabase dashboard
2. Verify that the database triggers are set up correctly
3. Make sure the webhook URL is correct in the database settings
4. Check for any errors in the client application

## Additional Resources

- [Supabase Database Webhooks Documentation](https://supabase.com/docs/guides/database/webhooks)
- [Supabase Edge Functions Documentation](https://supabase.com/docs/guides/functions)
- [Flutter Supabase Documentation](https://supabase.com/docs/guides/with-flutter)

## Next Steps

After deploying the webhooks, you may want to:

1. Add more webhook functions for other tables
2. Implement more sophisticated error handling
3. Add retry mechanisms for failed webhook calls
4. Implement webhook authentication for improved security
5. Monitor webhook performance using Supabase logs and metrics
6. Set up alerts for webhook failures to ensure timely resolution
