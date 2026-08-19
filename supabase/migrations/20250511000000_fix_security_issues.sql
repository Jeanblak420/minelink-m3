-- Fix security issues identified by Security Advisor

-- 1. Fix SQL injection in update_employee_company function
CREATE OR REPLACE FUNCTION update_employee_company(
    employee_id_param UUID,
    company_id_param UUID
)
RETURNS VOID AS $$
BEGIN
    -- Using parameterized query instead of string concatenation
    UPDATE employees
    SET company_id = company_id_param
    WHERE id = employee_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Fix SQL injection in handle_employee_company_selection function
CREATE OR REPLACE FUNCTION handle_employee_company_selection()
RETURNS TRIGGER AS $$
DECLARE
    company_data RECORD;
BEGIN
    -- Get company data using parameterized query
    SELECT * INTO company_data
    FROM companies
    WHERE id = NEW.company_id;
    
    IF FOUND THEN
        -- Insert notification using parameterized values
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
            'Employee ' || NEW.first_name || ' ' || NEW.last_name || ' has requested to join ' || company_data.company_name,
            'employeeRequest',
            false,
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Fix SQL injection in cleanup_old_broadcast_messages function
CREATE OR REPLACE FUNCTION cleanup_old_broadcast_messages()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- Using parameterized query with explicit interval
    DELETE FROM broadcast_messages
    WHERE timestamp < NOW() - INTERVAL '30 days'
    RETURNING COUNT(*) INTO deleted_count;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Move http extension to a more secure schema
-- First create a new schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS extensions;

-- Grant usage on the extensions schema to authenticated users
GRANT USAGE ON SCHEMA extensions TO authenticated;

-- Move the http extension to the extensions schema
DROP EXTENSION IF EXISTS http;
CREATE EXTENSION http WITH SCHEMA extensions;

-- 5. Enable leaked password protection
-- Cold replay 2026-08-18: ALTER SYSTEM cannot run inside a transaction block
-- (25001), and every migration runner wraps a file in one — so these two lines
-- have NEVER executed from a migration and stopped a rebuild dead. Both are
-- managed by Supabase at the platform level, not by this project.
-- ALTER SYSTEM SET password_encryption = 'scram-sha-256';
-- ALTER SYSTEM SET password_leak_detection = on;

-- Reload the configuration
SELECT pg_reload_conf();

-- Add comments to explain the changes
COMMENT ON FUNCTION update_employee_company(UUID, UUID) IS 'Safely updates an employee''s company_id with proper security measures';
COMMENT ON FUNCTION handle_employee_company_selection() IS 'Handles the workflow when an employee selects a company with proper security measures';
COMMENT ON FUNCTION cleanup_old_broadcast_messages() IS 'Deletes broadcast messages older than 30 days with proper security measures';
