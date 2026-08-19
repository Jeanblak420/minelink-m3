-- Fleet Management System Migration

-- Create fleet_vehicles table
CREATE TABLE IF NOT EXISTS fleet_vehicles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    vehicle_registration_expiry_date DATE,
    vehicle_registration_number TEXT NOT NULL,
    first_trailer_regs TEXT,
    second_trailer_regs TEXT,
    -- Cold replay 2026-08-18: employees.user_id carries no unique constraint,
    -- so this foreign key could not be created on a rebuild (42830).
    -- Everything in this 2025-era file is dropped again by 20260327000100
    -- (`drop schema if exists public cascade`), so the reference is dead
    -- weight; the column stays so the rest of the file is unchanged.
    assigned_driver_id UUID,
    driver_first_name TEXT,
    driver_last_name TEXT,
    driver_id_number TEXT,
    driver_passport_or_workers_permit TEXT,
    drivers_license_document TEXT,
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS fleet_vehicles_company_id_idx ON fleet_vehicles(company_id);
CREATE INDEX IF NOT EXISTS fleet_vehicles_assigned_driver_id_idx ON fleet_vehicles(assigned_driver_id);

-- Create a unique constraint to prevent duplicate vehicle registrations within the same company
ALTER TABLE fleet_vehicles ADD CONSTRAINT unique_vehicle_reg_per_company UNIQUE (company_id, vehicle_registration_number);

-- Create function to handle driver assignment
CREATE OR REPLACE FUNCTION handle_driver_assignment()
RETURNS TRIGGER AS $$
DECLARE
    driver_data RECORD;
BEGIN
    -- If a driver is being assigned (assigned_driver_id is being set to a non-NULL value)
    IF NEW.assigned_driver_id IS NOT NULL AND (OLD.assigned_driver_id IS NULL OR OLD.assigned_driver_id != NEW.assigned_driver_id) THEN
        -- Fetch the driver's details from the employees table
        SELECT first_name, last_name, id_number, passport_or_workers_permit, license_document
        INTO driver_data
        FROM employees
        WHERE user_id = NEW.assigned_driver_id AND company_id = NEW.company_id AND role = 'driver';
        
        -- If driver found, update the vehicle record with driver details
        IF FOUND THEN
            NEW.driver_first_name := driver_data.first_name;
            NEW.driver_last_name := driver_data.last_name;
            NEW.driver_id_number := driver_data.id_number;
            NEW.driver_passport_or_workers_permit := driver_data.passport_or_workers_permit;
            NEW.drivers_license_document := driver_data.license_document;
        ELSE
            -- If no matching driver found, raise an exception
            RAISE EXCEPTION 'Driver not found or not authorized. Driver must belong to the same company and have the driver role.';
        END IF;
    -- If a driver is being unassigned (assigned_driver_id is being set to NULL)
    ELSIF NEW.assigned_driver_id IS NULL AND OLD.assigned_driver_id IS NOT NULL THEN
        -- Clear all driver-related fields
        NEW.driver_first_name := NULL;
        NEW.driver_last_name := NULL;
        NEW.driver_id_number := NULL;
        NEW.driver_passport_or_workers_permit := NULL;
        NEW.drivers_license_document := NULL;
    END IF;
    
    -- Update the updated_at timestamp
    NEW.updated_at := NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for driver assignment/unassignment
DROP TRIGGER IF EXISTS driver_assignment_trigger ON fleet_vehicles;
CREATE TRIGGER driver_assignment_trigger
BEFORE UPDATE OF assigned_driver_id ON fleet_vehicles
FOR EACH ROW
EXECUTE FUNCTION handle_driver_assignment();

-- Create trigger for updating timestamps on any update
CREATE OR REPLACE FUNCTION update_fleet_vehicle_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_fleet_vehicle_timestamp_trigger ON fleet_vehicles;
CREATE TRIGGER update_fleet_vehicle_timestamp_trigger
BEFORE UPDATE ON fleet_vehicles
FOR EACH ROW
EXECUTE FUNCTION update_fleet_vehicle_timestamp();

-- Enable Row Level Security
ALTER TABLE fleet_vehicles ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for fleet_vehicles

-- SELECT policy: Allow users to view vehicles only for their company
DROP POLICY IF EXISTS "Users can view fleet vehicles for their company" ON fleet_vehicles;
CREATE POLICY "Users can view fleet vehicles for their company"
ON fleet_vehicles FOR SELECT
USING (
    -- Company users can see their company's vehicles
    EXISTS (
        SELECT 1 FROM companies
        WHERE companies.id = fleet_vehicles.company_id
        AND companies.user_id = auth.uid()
    )
    OR
    -- Employees can see vehicles for their company
    EXISTS (
        SELECT 1 FROM employees
        WHERE employees.user_id = auth.uid()
        AND employees.company_id = fleet_vehicles.company_id
    )
);

-- INSERT policy: Allow only transporter admins and above to add vehicles
DROP POLICY IF EXISTS "Transporter admins can add fleet vehicles" ON fleet_vehicles;
CREATE POLICY "Transporter admins can add fleet vehicles"
ON fleet_vehicles FOR INSERT
TO authenticated
WITH CHECK (
    -- Check if the user is a company admin or management for a transporter company
    EXISTS (
        SELECT 1 FROM companies
        WHERE companies.id = fleet_vehicles.company_id
        AND companies.user_id = auth.uid()
        AND companies.org_type = 'transporter'
    )
    OR
    -- Check if the user is an employee with admin or management role for a transporter company
    EXISTS (
        SELECT 1 FROM employees
        WHERE employees.user_id = auth.uid()
        AND employees.company_id = fleet_vehicles.company_id
        AND employees.role IN ('admin', 'management')
        AND EXISTS (
            SELECT 1 FROM companies
            WHERE companies.id = employees.company_id
            AND companies.org_type = 'transporter'
        )
    )
);

-- UPDATE policy: Allow only transporter admins and above to update vehicles
DROP POLICY IF EXISTS "Transporter admins can update fleet vehicles" ON fleet_vehicles;
CREATE POLICY "Transporter admins can update fleet vehicles"
ON fleet_vehicles FOR UPDATE
TO authenticated
USING (
    -- Check if the user is a company admin or management for a transporter company
    EXISTS (
        SELECT 1 FROM companies
        WHERE companies.id = fleet_vehicles.company_id
        AND companies.user_id = auth.uid()
        AND companies.org_type = 'transporter'
    )
    OR
    -- Check if the user is an employee with admin or management role for a transporter company
    EXISTS (
        SELECT 1 FROM employees
        WHERE employees.user_id = auth.uid()
        AND employees.company_id = fleet_vehicles.company_id
        AND employees.role IN ('admin', 'management')
        AND EXISTS (
            SELECT 1 FROM companies
            WHERE companies.id = employees.company_id
            AND companies.org_type = 'transporter'
        )
    )
);

-- DELETE policy: Allow only transporter admins and above to delete vehicles
DROP POLICY IF EXISTS "Transporter admins can delete fleet vehicles" ON fleet_vehicles;
CREATE POLICY "Transporter admins can delete fleet vehicles"
ON fleet_vehicles FOR DELETE
TO authenticated
USING (
    -- Check if the user is a company admin or management for a transporter company
    EXISTS (
        SELECT 1 FROM companies
        WHERE companies.id = fleet_vehicles.company_id
        AND companies.user_id = auth.uid()
        AND companies.org_type = 'transporter'
    )
    OR
    -- Check if the user is an employee with admin or management role for a transporter company
    EXISTS (
        SELECT 1 FROM employees
        WHERE employees.user_id = auth.uid()
        AND employees.company_id = fleet_vehicles.company_id
        AND employees.role IN ('admin', 'management')
        AND EXISTS (
            SELECT 1 FROM companies
            WHERE companies.id = employees.company_id
            AND companies.org_type = 'transporter'
        )
    )
);

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT ALL ON TABLE fleet_vehicles TO authenticated;
-- Cold replay 2026-08-18: `id` on this table is `UUID PRIMARY KEY DEFAULT
-- uuid_generate_v4()`. There is no sequence and there never was, so this
-- grant has never executed once — it just stopped a rebuild dead (42P01).
-- GRANT ALL ON SEQUENCE fleet_vehicles_id_seq TO authenticated;
GRANT EXECUTE ON FUNCTION handle_driver_assignment() TO authenticated;
GRANT EXECUTE ON FUNCTION update_fleet_vehicle_timestamp() TO authenticated;

-- Add helpful comments
COMMENT ON TABLE fleet_vehicles IS 'Stores information about vehicles in a company''s fleet';
COMMENT ON FUNCTION handle_driver_assignment() IS 'Automatically updates driver details when a driver is assigned or unassigned';
COMMENT ON FUNCTION update_fleet_vehicle_timestamp() IS 'Updates the updated_at timestamp whenever a fleet vehicle record is modified';
