# Instructions for Updating Notifications RLS Policies

To fix the 403 Forbidden error when trying to insert into the notifications table, you need to update the Row Level Security (RLS) policies for the notifications table in Supabase.

Follow these steps:

1. Log in to your Supabase dashboard at https://app.supabase.com
2. Select your project (kkcseqmpgzzrogatdoqi)
3. Go to the SQL Editor
4. Create a new query
5. Copy and paste the following SQL:

```sql
-- Update RLS policies for the notifications table to allow company users to insert notifications

-- First, check if the policy already exists and drop it if it does
DROP POLICY IF EXISTS "Companies can insert notifications" ON notifications;

-- Create a new policy that allows company users to insert notifications
CREATE POLICY "Companies can insert notifications" 
ON notifications FOR INSERT 
TO authenticated 
WITH CHECK (
  -- Allow if the user is a company admin (user_id exists in companies table)
  EXISTS (
    SELECT 1 FROM companies 
    WHERE companies.user_id = auth.uid()
  )
);

-- Also ensure there's a policy for companies to view notifications
DROP POLICY IF EXISTS "Companies can view their notifications" ON notifications;
CREATE POLICY "Companies can view their notifications" 
ON notifications FOR SELECT 
TO authenticated 
USING (
  -- Allow if the notification is for a company the user manages
  EXISTS (
    SELECT 1 FROM companies 
    WHERE companies.user_id = auth.uid() 
    AND (
      companies.id = notifications.company_id
      OR 
      EXISTS (
        SELECT 1 FROM employees 
        WHERE employees.company_id = companies.id 
        AND employees.id = notifications.employee_id
      )
    )
  )
) 
WITH CHECK (auth.uid() = company_id);
```

6. Run the query
7. Restart your Flutter application and try changing an employee's role again

This will update the RLS policies to allow company users to insert and view notifications related to their company and employees.
