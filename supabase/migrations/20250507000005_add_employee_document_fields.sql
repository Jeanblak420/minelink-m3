-- Add document fields to employees table
ALTER TABLE employees
ADD COLUMN IF NOT EXISTS id_number TEXT,
ADD COLUMN IF NOT EXISTS passport_or_workers_permit TEXT,
ADD COLUMN IF NOT EXISTS license_document TEXT;

-- Add comment to explain the purpose of these fields
COMMENT ON COLUMN employees.id_number IS 'National ID number of the employee';
COMMENT ON COLUMN employees.passport_or_workers_permit IS 'Passport or workers permit information';
COMMENT ON COLUMN employees.license_document IS 'License document information or URL';
