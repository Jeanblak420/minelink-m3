# Supabase SQL Migration Guide

To add the status column to the employees table, follow these steps to execute the SQL migration in the Supabase SQL Editor:

1. Log in to your Supabase dashboard at https://kkcseqmpgzzrogatdoqi.supabase.co
2. Navigate to the SQL Editor in the left sidebar
3. Create a new query
4. Copy and paste the following SQL code:

```sql
-- Add status column to employees table
ALTER TABLE employees
ADD COLUMN IF NOT EXISTS status TEXT;

-- Add comment to explain the purpose of this field
COMMENT ON COLUMN employees.status IS 'Status of the employee (pending, accepted, etc.)';

-- Create index for faster queries on the status column
CREATE INDEX IF NOT EXISTS employees_status_idx ON employees(status);

-- Update existing employees to have a default status
UPDATE employees
SET status = 'accepted'
WHERE status IS NULL AND company_id IS NOT NULL;

-- Add a trigger to automatically set status to 'pending' when company_id is set
CREATE OR REPLACE FUNCTION set_employee_status_on_company_link()
RETURNS TRIGGER AS $$
BEGIN
  -- If company_id is being set and was previously NULL
  IF NEW.company_id IS NOT NULL AND (OLD.company_id IS NULL OR OLD.company_id <> NEW.company_id) THEN
    NEW.status := 'pending';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS set_employee_status_trigger ON employees;
CREATE TRIGGER set_employee_status_trigger
BEFORE UPDATE ON employees
FOR EACH ROW
EXECUTE FUNCTION set_employee_status_on_company_link();
```

5. Click "Run" to execute the SQL migration
6. Verify the migration was successful by checking the employees table structure

## Testing the Migration

After executing the migration, you can test it with the following SQL queries:

### Check if the status column exists:

```sql
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'employees' AND column_name = 'status';
```

### Check if existing employees have been updated with the 'accepted' status:

```sql
SELECT id, first_name, last_name, company_id, status 
FROM employees 
WHERE company_id IS NOT NULL;
```

### Test the trigger by updating an employee's company_id:

```sql
-- First, find an employee without a company
SELECT id, first_name, last_name, company_id, status 
FROM employees 
WHERE company_id IS NULL 
LIMIT 1;

-- Then update their company_id (replace the IDs with actual values)
UPDATE employees 
SET company_id = 'some-company-id' 
WHERE id = 'employee-id-from-previous-query';

-- Check if the status was automatically set to 'pending'
SELECT id, first_name, last_name, company_id, status 
FROM employees 
WHERE id = 'employee-id-from-previous-query';
```

## Troubleshooting

If you encounter any issues during the migration:

1. Check the error messages in the SQL Editor
2. Verify that the employees table exists and has the expected structure
3. Make sure you have the necessary permissions to alter tables and create triggers
4. If the trigger creation fails, check if there are any existing triggers with conflicting names
