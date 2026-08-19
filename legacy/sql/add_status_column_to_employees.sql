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
