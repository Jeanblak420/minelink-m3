-- Check RLS policies for the employees table
SELECT
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM
    pg_policies
WHERE
    tablename = 'employees';

-- Fix RLS policies if needed
-- Make sure authenticated users can insert into the employees table
CREATE POLICY IF NOT EXISTS "Employees can be created by authenticated users" 
ON employees FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

-- Make sure employees are viewable by everyone
CREATE POLICY IF NOT EXISTS "Employees are viewable by everyone" 
ON employees FOR SELECT 
USING (true);

-- Make sure employees can be updated by their owners or company owners
CREATE POLICY IF NOT EXISTS "Employees can be updated by their owners or company owners" 
ON employees FOR UPDATE 
TO authenticated 
USING (
    auth.uid() = user_id OR 
    auth.uid() IN (
        SELECT user_id FROM companies WHERE id = company_id
    )
);

-- Make sure employees can be deleted by their owners
CREATE POLICY IF NOT EXISTS "Employees can be deleted by their owners" 
ON employees FOR DELETE 
TO authenticated 
USING (auth.uid() = user_id);
