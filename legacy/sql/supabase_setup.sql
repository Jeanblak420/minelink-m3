-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create tables
CREATE TABLE IF NOT EXISTS companies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company_name TEXT NOT NULL,
  whatsapp_number TEXT NOT NULL,
  org_type TEXT NOT NULL,
  logo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE IF NOT EXISTS employees (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  whatsapp_number TEXT NOT NULL,
  company_id UUID REFERENCES companies(id) ON DELETE SET NULL,
  role TEXT,
  profile_photo_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes
CREATE INDEX IF NOT EXISTS companies_user_id_idx ON companies(user_id);
CREATE INDEX IF NOT EXISTS employees_user_id_idx ON employees(user_id);
CREATE INDEX IF NOT EXISTS employees_company_id_idx ON employees(company_id);

-- Enable Row Level Security
ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;


-- Make policy creation idempotent
DROP POLICY IF EXISTS "Companies are viewable by everyone" ON companies;
CREATE POLICY "Companies are viewable by everyone" 
ON companies FOR SELECT 
USING (true);

CREATE POLICY "Companies can be created by authenticated users" 
ON companies FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Companies can be updated by their owners" 
ON companies FOR UPDATE 
TO authenticated 
USING (auth.uid() = user_id);

CREATE POLICY "Companies can be deleted by their owners" 
ON companies FOR DELETE 
TO authenticated 
USING (auth.uid() = user_id);

-- Create policies for employees table
CREATE POLICY "Employees are viewable by everyone" 
ON employees FOR SELECT 
USING (true);

CREATE POLICY "Employees can be created by authenticated users" 
ON employees FOR INSERT 
TO authenticated 
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Employees can be updated by themselves or their company admins" 
ON employees FOR UPDATE 
TO authenticated 
USING (
  auth.uid() = user_id OR 
  EXISTS (
    SELECT 1 FROM companies c
    JOIN employees e ON e.company_id = c.id
    WHERE c.user_id = auth.uid() AND e.id = employees.id
  )
);

CREATE POLICY "Employees can be deleted by themselves or their company admins" 
ON employees FOR DELETE 
TO authenticated 
USING (
  auth.uid() = user_id OR 
  EXISTS (
    SELECT 1 FROM companies c
    JOIN employees e ON e.company_id = c.id
    WHERE c.user_id = auth.uid() AND e.id = employees.id
  )
);

-- Create storage buckets
INSERT INTO storage.buckets (id, name, public) VALUES ('company_assets', 'Company Assets', true)
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public) VALUES ('employee_assets', 'Employee Assets', true)
ON CONFLICT (id) DO NOTHING;

-- Create storage policies
CREATE POLICY "Company assets are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'company_assets');

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

CREATE POLICY "Employee assets are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'employee_assets');

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
