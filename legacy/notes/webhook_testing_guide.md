# Testing the Employee-Company Link Webhook

This guide will help you test the employee-company linking process using both direct Edge Function calls and the webhook trigger.

## Prerequisites

1. Make sure the Edge Function is deployed:
   ```
   supabase functions deploy employee-company-link --use-api
   ```

2. Verify that the webhook is configured in the Supabase Dashboard:
   - Table: employees
   - Events: UPDATE
   - Function to trigger: employee-company-link

## Testing Options

### Option 1: Using the Test Script

1. Open the `test_employee_company_link.dart` file in your Flutter project
2. Replace `your-supabase-key` with your actual Supabase API key
3. Run the Flutter app
4. Enter an existing Employee ID and Company ID
5. Click "Test Direct Link" to call the Edge Function directly
6. Click "Test Webhook Link" to update the employee record and trigger the webhook

### Option 2: Using the Supabase Dashboard

1. Go to the Supabase Dashboard: https://supabase.com/dashboard/project/kkcseqmpgzzrogatdoqi/editor
2. Run a SQL query to update an employee's company_id:
   ```sql
   UPDATE employees
   SET company_id = 'your-company-id'
   WHERE id = 'your-employee-id';
   ```
3. Check the Edge Function logs to verify that the webhook was triggered

### Option 3: Using the Supabase API in the Browser Console

1. Open your Flutter app in a browser
2. Open the browser console (F12)
3. Run the following JavaScript code:
   ```javascript
   const supabase = window.supabase;
   
   // Direct function call
   supabase.functions.invoke('employee-company-link', {
     body: {
       employee_id: 'your-employee-id',
       company_id: 'your-company-id'
     }
   }).then(console.log).catch(console.error);
   
   // Webhook trigger
   supabase
     .from('employees')
     .update({ company_id: 'your-company-id' })
     .eq('id', 'your-employee-id')
     .then(console.log).catch(console.error);
   ```

## Verifying Results

After testing, verify that:

1. The employee record is updated with the company_id
2. An entry is created in the employee_status_history table
3. A notification is created for the company owner

You can check these in the Supabase Dashboard:
- https://supabase.com/dashboard/project/kkcseqmpgzzrogatdoqi/editor

Run these queries:
```sql
-- Check employee record
SELECT * FROM employees WHERE id = 'your-employee-id';

-- Check status history
SELECT * FROM employee_status_history WHERE employee_id = 'your-employee-id';

-- Check notifications
SELECT * FROM notifications WHERE related_id = 'your-employee-id';
```

## Troubleshooting

If the webhook isn't triggering:

1. Check the Edge Function logs in the Supabase Dashboard
2. Verify that the webhook is properly configured
3. Make sure the employee and company IDs exist in the database
4. Check that the Edge Function has the necessary permissions
5. Ensure that the webhook URL is accessible from the Supabase Edge Function environment.
6. Verify that the webhook payload matches the expected schema to avoid processing errors.

If you encounter any errors:

- The Edge Function logs will provide detailed information about what went wrong.
- Ensure that the database connection is active and the Edge Function is deployed correctly.
- Additionally, confirm that the required environment variables are set properly.
