-- Add citizenship field to employees table
ALTER TABLE employees
ADD COLUMN IF NOT EXISTS is_south_african_citizen BOOLEAN DEFAULT TRUE;

-- Add comment to explain the purpose of this field
COMMENT ON COLUMN employees.is_south_african_citizen IS 'Indicates whether the employee is a South African citizen';

-- Add document URL fields for uploaded documents
ALTER TABLE employees
ADD COLUMN IF NOT EXISTS id_document_url TEXT,
ADD COLUMN IF NOT EXISTS passport_document_url TEXT,
ADD COLUMN IF NOT EXISTS work_visa_document_url TEXT,
ADD COLUMN IF NOT EXISTS license_document_url TEXT;

-- Add comments to explain the purpose of these fields
COMMENT ON COLUMN employees.id_document_url IS 'URL to the uploaded South African ID document';
COMMENT ON COLUMN employees.passport_document_url IS 'URL to the uploaded passport document';
COMMENT ON COLUMN employees.work_visa_document_url IS 'URL to the uploaded work visa document';
COMMENT ON COLUMN employees.license_document_url IS 'URL to the uploaded license document';
