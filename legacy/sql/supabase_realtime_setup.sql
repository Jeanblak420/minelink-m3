-- Enable Realtime for all required tables
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
ALTER PUBLICATION supabase_realtime ADD TABLE employee_status_history;
ALTER PUBLICATION supabase_realtime ADD TABLE broadcast_messages;

-- Set REPLICA IDENTITY to FULL for all tables to get both old and new values in realtime events
ALTER TABLE companies REPLICA IDENTITY FULL;
ALTER TABLE employees REPLICA IDENTITY FULL;
ALTER TABLE notifications REPLICA IDENTITY FULL;
ALTER TABLE employee_status_history REPLICA IDENTITY FULL;
ALTER TABLE broadcast_messages REPLICA IDENTITY FULL;

-- Create RLS policies for realtime access
-- Companies table
DROP POLICY IF EXISTS "Enable realtime for companies" ON companies;
CREATE POLICY "Enable realtime for companies" ON companies
FOR SELECT USING (true);

-- Employees table
DROP POLICY IF EXISTS "Enable realtime for employees" ON employees;
CREATE POLICY "Enable realtime for employees" ON employees
FOR SELECT USING (true);

-- Notifications table
DROP POLICY IF EXISTS "Enable realtime for notifications" ON notifications;
CREATE POLICY "Enable realtime for notifications" ON notifications
FOR SELECT USING (auth.uid() = user_id OR 
                 auth.uid() IN (SELECT user_id FROM companies WHERE id = company_id));

-- Employee status history table
DROP POLICY IF EXISTS "Enable realtime for employee_status_history" ON employee_status_history;
CREATE POLICY "Enable realtime for employee_status_history" ON employee_status_history
FOR SELECT USING (auth.uid() IN (
    SELECT user_id FROM employees WHERE id = employee_id
) OR auth.uid() IN (
    SELECT user_id FROM companies WHERE id = company_id
));

-- Broadcast messages table
DROP POLICY IF EXISTS "Enable realtime for broadcast_messages" ON broadcast_messages;
CREATE POLICY "Enable realtime for broadcast_messages" ON broadcast_messages
FOR SELECT USING (true);

-- Add the requestDeclined status to the employee_status_history table if it doesn't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type 
        JOIN pg_enum ON pg_enum.enumtypid = pg_type.oid 
        WHERE pg_type.typname = 'employee_approval_status' 
        AND pg_enum.enumlabel = 'requestDeclined'
    ) THEN
        ALTER TYPE employee_approval_status ADD VALUE IF NOT EXISTS 'requestDeclined';
    END IF;
EXCEPTION
    WHEN others THEN
        -- If the type doesn't exist or there's another error, we'll just continue
        RAISE NOTICE 'Could not add requestDeclined to employee_approval_status: %', SQLERRM;
END $$;

-- Create a function to handle employee request declined events
CREATE OR REPLACE FUNCTION handle_employee_request_declined()
RETURNS TRIGGER AS $$
BEGIN
  -- Insert a record into the employee_status_history table
  INSERT INTO employee_status_history (
    id,
    employee_id,
    company_id,
    status,
    timestamp,
    actioned_by_id,
    actioned_by_name
  )
  VALUES (
    gen_random_uuid(),
    OLD.id,
    OLD.company_id,
    'requestDeclined',
    NOW(),
    auth.uid(),
    (SELECT email FROM auth.users WHERE id = auth.uid())
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a trigger for employee request declined events
DROP TRIGGER IF EXISTS on_employee_request_declined ON employees;
CREATE TRIGGER on_employee_request_declined
AFTER UPDATE OF company_id ON employees
FOR EACH ROW
WHEN (OLD.company_id IS NOT NULL AND NEW.company_id IS NULL)
EXECUTE FUNCTION handle_employee_request_declined();
