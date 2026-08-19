# Edge Function Deployment Guide

This guide explains how to deploy the Edge Functions for the webhook implementation in our Flutter application with Supabase.

## Prerequisites

- Access to the Supabase dashboard
- The Edge Function files in the `supabase/functions` directory
- SQL migration files in the `supabase/migrations` directory

## Option 1: Deploy Using the Supabase Dashboard (Recommended)

If you don't have Docker Desktop installed or are experiencing issues with the Supabase CLI, you can deploy the Edge Functions directly through the Supabase Dashboard:

1. **Log in to the Supabase Dashboard**
   - Go to https://supabase.com/dashboard
   - Select your project (kkcseqmpgzzrogatdoqi)

2. **Navigate to Edge Functions**
   - Click on "Edge Functions" in the left sidebar

3. **Create and Deploy the Edge Functions**
   - For each function (`employee-webhook`, `company-webhook`, `notification-webhook`):
     1. Click "Create a new function"
     2. Enter the function name (e.g., `employee-webhook`)
     3. Click "Create function"
     4. Copy and paste the code from the corresponding file in `supabase/functions`
     5. Click "Deploy"

4. **Set Up Environment Variables**
   - In the Edge Functions section, click on "Settings"
   - Add the following environment variables:
     - `SUPABASE_URL`: Your Supabase URL (https://kkcseqmpgzzrogatdoqi.supabase.co)
     - `SUPABASE_SERVICE_ROLE_KEY`: Your Supabase service role key (find this in Project Settings > API)

5. **Set Up Database Triggers**
   - Go to the SQL Editor in the Supabase Dashboard
   - Open the `manual_webhook_setup.sql` file from `supabase/migrations`
   - Copy the contents and paste them into the SQL Editor
   - Click "Run" to execute the SQL script

## Option 2: Deploy Using the Supabase CLI

If you have Docker Desktop installed, you can use the Supabase CLI to deploy the functions:

1. **Install the Supabase CLI**
   ```bash
   npm install -g supabase
   ```

   Or with pnpm:
   ```bash
   pnpm add -g supabase
   ```

2. **Log in to Supabase**
   ```bash
   supabase login
   ```

3. **Link Your Project**
   ```bash
   supabase link --project-ref kkcseqmpgzzrogatdoqi
   ```

4. **Deploy the Functions**
   ```bash
   supabase functions deploy employee-webhook
   supabase functions deploy company-webhook
   supabase functions deploy notification-webhook
   ```

5. **Apply Database Migrations**
   ```bash
   supabase migration up
   ```

   Or you can run the deployment script:
   ```bash
   ./deploy-webhooks.bat
   ```

## Option 3: Manual SQL Setup Only (No Edge Functions)

If you can't deploy the Edge Functions at all, you can set up database triggers that perform similar functionality directly in the database:

1. **Open the SQL Editor**
   - Go to the Supabase Dashboard
   - Click on "SQL Editor" in the left sidebar

2. **Run the SQL Script**
   - Open the `supabase/migrations/manual_webhook_setup.sql` file
   - Copy the contents
   - Paste into the SQL Editor
   - Click "Run"

This will set up database triggers that perform similar functionality to the Edge Functions, but with more limited capabilities.

## Testing the Deployment

After deploying the Edge Functions and setting up the database triggers, you should test them:

1. **Test the Employee Webhook**
   - Create a new employee
   - Link the employee to a company
   - Check that a notification is created for the company owner

2. **Test the Company Webhook**
   - Create a new company
   - Check that a welcome notification is created for the company owner

3. **Test the Notification Webhook**
   - Create a new notification
   - Check that it appears in the UI
   - Mark it as read
   - Check that the unread count is updated

## Troubleshooting

If you encounter issues with the Edge Functions:

1. **Check the Logs**
   - Go to the Edge Functions section in the Supabase Dashboard
   - Click on the function
   - Click on "Logs"

2. **Check the Environment Variables**
   - Make sure the `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are set correctly

3. **Check the Database Triggers**
   - If the Edge Functions are working but the triggers aren't firing, check the database triggers in the SQL Editor:
     ```sql
     SELECT * FROM pg_trigger;
     ```

4. **Check the Network Requests**
   - Use the browser's developer tools to check the network requests
   - Look for any errors in the console

5. **Verify the Webhook URL**
   - Make sure the webhook URL in the database settings is correct:
     ```sql
     SHOW app.settings.webhook_url;
     ```
   - It should be set to your Supabase project URL + `/functions/v1`

## Common Issues and Solutions

### Issue: "Error: Docker Desktop is not running"
**Solution:** If you're using the Supabase CLI and get this error, you need to install Docker Desktop or use Option 1 (Supabase Dashboard) instead.

### Issue: "Error: Function not found"
**Solution:** Make sure you've created the function in the Supabase Dashboard or deployed it correctly using the CLI.

### Issue: "Error: Permission denied"
**Solution:** Check that your service role key has the necessary permissions.

### Issue: "Error: HTTP request failed"
**Solution:** Check that your webhook URL is correct and that the Edge Function is deployed.

### Issue: "Error: Database trigger not firing"
**Solution:** Check that the database triggers are set up correctly and that the webhook URL is set in the database settings.

## Next Steps

After successfully deploying the webhooks:

1. **Monitor Performance**
   - Check the Edge Function logs for any errors
   - Monitor the database performance
   - Check for any UI issues in the Flutter app

2. **Optimize Polling Intervals**
   - Adjust the polling intervals in the Flutter app based on performance needs
   - Consider increasing intervals for less critical features

3. **Add Error Handling**
   - Implement retry mechanisms for failed webhook calls
   - Add more robust error handling in the Edge Functions

4. **Enhance Security**
   - Implement webhook authentication
   - Use environment variables for sensitive information
