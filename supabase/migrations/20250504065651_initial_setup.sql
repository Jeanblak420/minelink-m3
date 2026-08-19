-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "http";

-- Drop existing tables if they exist
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS employee_status_history CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS companies CASCADE;

-- Create companies table
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id),
    company_name TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- Create employees table with proper UUID types
CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id),
    company_id UUID REFERENCES companies(id),
    first_name TEXT NOT NULL,
    last_name TEXT NOT NULL,
    whatsapp_number TEXT,
    profile_photo_url TEXT,
    role TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- Create employee_status_history table
CREATE TABLE employee_status_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID REFERENCES employees(id),
    company_id UUID REFERENCES companies(id),
    status TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Create notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id),
    employee_id UUID REFERENCES employees(id),
    company_id UUID REFERENCES companies(id),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    actioned_by TEXT,
    actioned_by_id UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

-- Create function to update employee company
CREATE OR REPLACE FUNCTION update_employee_company(
    employee_id_param UUID,
    company_id_param UUID
)
RETURNS VOID AS $$
BEGIN
    UPDATE employees
    SET 
        company_id = company_id_param,
        updated_at = NOW()
    WHERE id = employee_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for employee company selection
CREATE OR REPLACE FUNCTION handle_employee_company_selection()
RETURNS TRIGGER AS $$
DECLARE
    company_data RECORD;
BEGIN
    -- If company_id was added (employee selected a company)
    IF NEW.company_id IS NOT NULL AND OLD.company_id IS NULL THEN
        -- Get company details
        SELECT c.user_id, c.company_name 
        INTO company_data
        FROM companies c
        WHERE c.id = NEW.company_id;

        -- Insert status history
        INSERT INTO employee_status_history (
            id,
            employee_id,
            company_id,
            status,
            timestamp
        )
        VALUES (
            gen_random_uuid(),
            NEW.id,
            NEW.company_id,
            'requestSent',
            NOW()
        );

        -- Create notification
        INSERT INTO notifications (
            id,
            user_id,
            employee_id,
            company_id,
            title,
            message,
            type,
            is_read,
            created_at
        )
        VALUES (
            gen_random_uuid(),
            company_data.user_id,
            NEW.id,
            NEW.company_id,
            'New Employee Request',
            'An employee has requested to join ' || company_data.company_name || '.',
            'employeeRequest',
            false,
            NOW()
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
DROP TRIGGER IF EXISTS employee_company_selection_trigger ON employees;
CREATE TRIGGER employee_company_selection_trigger
    AFTER UPDATE ON employees
    FOR EACH ROW
    WHEN (NEW.company_id IS NOT NULL AND OLD.company_id IS NULL)
    EXECUTE FUNCTION handle_employee_company_selection();

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION update_employee_company(UUID, UUID) TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION update_employee_company(UUID, UUID) IS 'Safely updates an employee''s company_id with proper type handling';
COMMENT ON FUNCTION handle_employee_company_selection() IS 'Handles the workflow when an employee selects a company';