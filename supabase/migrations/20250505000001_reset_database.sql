-- Reset database schema
-- Drop existing tables if they exist
DROP TABLE IF EXISTS notifications CASCADE;
DROP TABLE IF EXISTS employee_status_history CASCADE;
DROP TABLE IF EXISTS broadcast_messages CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS companies CASCADE;

-- Drop existing functions if they exist
DROP FUNCTION IF EXISTS handle_employee_company_selection() CASCADE;
DROP FUNCTION IF EXISTS update_employee_company(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS cleanup_old_broadcast_messages() CASCADE;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "http";

-- Create companies table
CREATE TABLE companies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    company_name TEXT NOT NULL,
    whatsapp_number TEXT,
    org_type TEXT,
    logo_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- Create employees table
CREATE TABLE employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
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
    employee_id UUID REFERENCES employees(id) ON DELETE CASCADE,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    status TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Create notifications table
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
    company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    type TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ,
    actioned_by TEXT,
    actioned_by_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    role_scope TEXT
);

-- Create broadcast_messages table
CREATE TABLE broadcast_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sender_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    company_id UUID REFERENCES companies(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    timestamp TIMESTAMPTZ DEFAULT NOW()
);

-- Create function to update employee company
CREATE OR REPLACE FUNCTION update_employee_company(
    employee_id_param UUID,
    company_id_param UUID
)
RETURNS VOID AS $$
BEGIN
    UPDATE employees
    SET company_id = company_id_param
    WHERE id = employee_id_param;
END;
$$ LANGUAGE plpgsql;

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
            'Employee ' || NEW.first_name || ' ' || NEW.last_name || ' has requested to join ' || company_data.company_name,
            'employeeRequest',
            false,
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on employees table
DROP TRIGGER IF EXISTS employee_company_selection_trigger ON employees;
CREATE TRIGGER employee_company_selection_trigger
AFTER UPDATE OF company_id ON employees
FOR EACH ROW
WHEN (OLD.company_id IS NULL AND NEW.company_id IS NOT NULL)
EXECUTE FUNCTION handle_employee_company_selection();

-- Create function to clean up old broadcast messages
CREATE OR REPLACE FUNCTION cleanup_old_broadcast_messages()
RETURNS INTEGER AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    DELETE FROM broadcast_messages
    WHERE timestamp < NOW() - INTERVAL '30 days'
    RETURNING COUNT(*) INTO deleted_count;
    
    RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS companies_user_id_idx ON companies(user_id);
CREATE INDEX IF NOT EXISTS employees_user_id_idx ON employees(user_id);
CREATE INDEX IF NOT EXISTS employees_company_id_idx ON employees(company_id);
CREATE INDEX IF NOT EXISTS notifications_user_id_idx ON notifications(user_id);
CREATE INDEX IF NOT EXISTS notifications_company_id_idx ON notifications(company_id);
CREATE INDEX IF NOT EXISTS notifications_employee_id_idx ON notifications(employee_id);
CREATE INDEX IF NOT EXISTS notifications_actioned_by_id_idx ON notifications(actioned_by_id);
CREATE INDEX IF NOT EXISTS notifications_role_scope_idx ON notifications(role_scope);

-- Enable Row Level Security
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE employee_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE broadcast_messages ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for companies
DROP POLICY IF EXISTS "Companies are viewable by everyone" ON companies;
CREATE POLICY "Companies are viewable by everyone" 
ON companies FOR SELECT 
USING (true);

DROP POLICY IF EXISTS "Companies can be created by authenticated users" ON companies;
CREATE POLICY "Companies can be created by authenticated users" 
ON companies FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Companies can be updated by their owners" ON companies;
CREATE POLICY "Companies can be updated by their owners" 
ON companies FOR UPDATE 
TO authenticated 
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Companies can be deleted by their owners" ON companies;
CREATE POLICY "Companies can be deleted by their owners" 
ON companies FOR DELETE 
TO authenticated 
USING (auth.uid() = user_id);

-- Create RLS policies for employees
DROP POLICY IF EXISTS "Employees are viewable by everyone" ON employees;
CREATE POLICY "Employees are viewable by everyone" 
ON employees FOR SELECT 
USING (true);

DROP POLICY IF EXISTS "Employees can be created by authenticated users" ON employees;
CREATE POLICY "Employees can be created by authenticated users" 
ON employees FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS "Employees can be updated by themselves or company owners" ON employees;
CREATE POLICY "Employees can be updated by themselves or company owners" 
ON employees FOR UPDATE 
TO authenticated 
USING (
    auth.uid() = user_id OR 
    EXISTS (
        SELECT 1 FROM companies 
        WHERE companies.id = employees.company_id AND companies.user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Employees can be deleted by themselves" ON employees;
CREATE POLICY "Employees can be deleted by themselves" 
ON employees FOR DELETE 
TO authenticated 
USING (auth.uid() = user_id);

-- Create RLS policies for notifications
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
CREATE POLICY "Users can view their own notifications" 
ON notifications FOR SELECT 
TO authenticated 
USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can insert notifications" ON notifications;
CREATE POLICY "Users can insert notifications" 
ON notifications FOR INSERT 
TO authenticated 
WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update their own notifications" ON notifications;
CREATE POLICY "Users can update their own notifications" 
ON notifications FOR UPDATE 
TO authenticated 
USING (user_id = auth.uid());

-- Create RLS policies for employee_status_history
DROP POLICY IF EXISTS "Employee status history is viewable by related users" ON employee_status_history;
CREATE POLICY "Employee status history is viewable by related users" 
ON employee_status_history FOR SELECT 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM employees 
        WHERE employees.id = employee_status_history.employee_id AND employees.user_id = auth.uid()
    ) OR 
    EXISTS (
        SELECT 1 FROM companies 
        WHERE companies.id = employee_status_history.company_id AND companies.user_id = auth.uid()
    )
);

-- Create RLS policies for broadcast_messages
DROP POLICY IF EXISTS "Broadcast messages are viewable by company members" ON broadcast_messages;
CREATE POLICY "Broadcast messages are viewable by company members" 
ON broadcast_messages FOR SELECT 
TO authenticated 
USING (
    EXISTS (
        SELECT 1 FROM employees 
        WHERE employees.company_id = broadcast_messages.company_id AND employees.user_id = auth.uid()
    ) OR 
    EXISTS (
        SELECT 1 FROM companies 
        WHERE companies.id = broadcast_messages.company_id AND companies.user_id = auth.uid()
    )
);

DROP POLICY IF EXISTS "Company owners can create broadcast messages" ON broadcast_messages;
CREATE POLICY "Company owners can create broadcast messages" 
ON broadcast_messages FOR INSERT 
TO authenticated 
WITH CHECK (
    EXISTS (
        SELECT 1 FROM companies 
        WHERE companies.id = broadcast_messages.company_id AND companies.user_id = auth.uid()
    )
);

-- Create storage buckets if they don't exist
INSERT INTO storage.buckets (id, name, public) 
VALUES ('company_assets', 'Company Assets', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) 
VALUES ('employee_assets', 'Employee Assets', true)
ON CONFLICT (id) DO NOTHING;

-- Create storage policies
DROP POLICY IF EXISTS "Company assets are publicly accessible" ON storage.objects;
CREATE POLICY "Company assets are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'company_assets');

DROP POLICY IF EXISTS "Company owners can upload company assets" ON storage.objects;
CREATE POLICY "Company owners can upload company assets"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'company_assets' AND
  (storage.foldername(name))[1] = 'company_logos' AND
  EXISTS (
    SELECT 1 FROM companies
    WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]
  )
);

DROP POLICY IF EXISTS "Employee assets are publicly accessible" ON storage.objects;
CREATE POLICY "Employee assets are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'employee_assets');

DROP POLICY IF EXISTS "Employees can upload their own assets" ON storage.objects;
CREATE POLICY "Employees can upload their own assets"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'employee_assets' AND
  (storage.foldername(name))[1] = 'profile_photos' AND
  EXISTS (
    SELECT 1 FROM employees
    WHERE user_id = auth.uid() AND id::text = (storage.foldername(name))[2]
  )
);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO authenticated;
GRANT EXECUTE ON FUNCTION update_employee_company(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION cleanup_old_broadcast_messages() TO authenticated;

-- Add helpful comments
COMMENT ON FUNCTION update_employee_company(UUID, UUID) IS 'Safely updates an employee''s company_id with proper type handling';
COMMENT ON FUNCTION handle_employee_company_selection() IS 'Handles the workflow when an employee selects a company';
COMMENT ON FUNCTION cleanup_old_broadcast_messages() IS 'Deletes broadcast messages older than 30 days';
