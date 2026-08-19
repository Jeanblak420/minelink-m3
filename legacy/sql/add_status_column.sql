-- Add status column to employees table
ALTER TABLE employees
ADD COLUMN IF NOT EXISTS status TEXT;

-- Add comment to explain the purpose of this field
COMMENT ON COLUMN employees.status IS 'Status of the employee (pending, accepted, etc.)';

-- Create index for faster queries on the status column
CREATE INDEX IF NOT EXISTS employees_status_idx ON employees(status);
