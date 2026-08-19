-- This migration updates the permissions and policies for the employee-company linking process

-- 1. Create a policy to allow Edge Functions to update employees
DROP POLICY IF EXISTS "Edge Functions can update employees" ON employees;
CREATE POLICY "Edge Functions can update employees"
ON employees FOR UPDATE
TO authenticated
USING (true)
WITH CHECK (true);

-- 2. Create a policy to allow Edge Functions to insert into employee_status_history
DROP POLICY IF EXISTS "Edge Functions can insert employee status history" ON employee_status_history;
CREATE POLICY "Edge Functions can insert employee status history"
ON employee_status_history FOR INSERT
TO authenticated
WITH CHECK (true);

-- 3. Create a policy to allow Edge Functions to insert into notifications
-- (This is already covered by the existing policy "Users can insert notifications")

-- 4. Ensure the RPC function is still accessible (for backward compatibility)
GRANT EXECUTE ON FUNCTION update_employee_company(UUID, UUID) TO authenticated;
