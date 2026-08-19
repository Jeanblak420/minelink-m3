-- Update fleet_vehicles table to add document URL fields and split passport/permit fields

-- Rename the existing passport_or_workers_permit column to passport_number
ALTER TABLE fleet_vehicles 
RENAME COLUMN driver_passport_or_workers_permit TO driver_passport_number;

-- Add new work permit column
ALTER TABLE fleet_vehicles 
ADD COLUMN IF NOT EXISTS driver_work_permit TEXT;

-- Add document URL fields
ALTER TABLE fleet_vehicles 
ADD COLUMN IF NOT EXISTS driver_id_document_url TEXT,
ADD COLUMN IF NOT EXISTS driver_passport_document_url TEXT,
ADD COLUMN IF NOT EXISTS driver_work_visa_document_url TEXT,
ADD COLUMN IF NOT EXISTS driver_license_document_url TEXT,
ADD COLUMN IF NOT EXISTS driver_is_south_african_citizen BOOLEAN;

-- Update the driver assignment function to handle the new fields
CREATE OR REPLACE FUNCTION handle_driver_assignment()
RETURNS TRIGGER AS $$
DECLARE
    driver_data RECORD;
BEGIN
    -- If a driver is being assigned (assigned_driver_id is being set to a non-NULL value)
    IF NEW.assigned_driver_id IS NOT NULL AND (OLD.assigned_driver_id IS NULL OR OLD.assigned_driver_id != NEW.assigned_driver_id) THEN
        -- Fetch the driver's details from the employees table
        SELECT 
            first_name, 
            last_name, 
            id_number, 
            passport_or_workers_permit AS passport_number,
            NULL AS work_permit, -- This will be handled separately in the future
            license_document,
            id_document_url,
            passport_document_url,
            work_visa_document_url,
            license_document_url,
            is_south_african_citizen
        INTO driver_data
        FROM employees
        WHERE user_id = NEW.assigned_driver_id AND company_id = NEW.company_id AND role = 'driver';
        
        -- If driver found, update the vehicle record with driver details
        IF FOUND THEN
            NEW.driver_first_name := driver_data.first_name;
            NEW.driver_last_name := driver_data.last_name;
            NEW.driver_id_number := driver_data.id_number;
            NEW.driver_passport_number := driver_data.passport_number;
            NEW.driver_work_permit := driver_data.work_permit;
            NEW.drivers_license_document := driver_data.license_document;
            NEW.driver_id_document_url := driver_data.id_document_url;
            NEW.driver_passport_document_url := driver_data.passport_document_url;
            NEW.driver_work_visa_document_url := driver_data.work_visa_document_url;
            NEW.driver_license_document_url := driver_data.license_document_url;
            NEW.driver_is_south_african_citizen := driver_data.is_south_african_citizen;
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
        NEW.driver_passport_number := NULL;
        NEW.driver_work_permit := NULL;
        NEW.drivers_license_document := NULL;
        NEW.driver_id_document_url := NULL;
        NEW.driver_passport_document_url := NULL;
        NEW.driver_work_visa_document_url := NULL;
        NEW.driver_license_document_url := NULL;
        NEW.driver_is_south_african_citizen := NULL;
    END IF;
    
    -- Update the updated_at timestamp
    NEW.updated_at := NOW();
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Add comments to explain the new fields
COMMENT ON COLUMN fleet_vehicles.driver_passport_number IS 'Passport number of the assigned driver';
COMMENT ON COLUMN fleet_vehicles.driver_work_permit IS 'Work permit details of the assigned driver';
COMMENT ON COLUMN fleet_vehicles.driver_id_document_url IS 'URL to the ID document of the assigned driver';
COMMENT ON COLUMN fleet_vehicles.driver_passport_document_url IS 'URL to the passport document of the assigned driver';
COMMENT ON COLUMN fleet_vehicles.driver_work_visa_document_url IS 'URL to the work visa document of the assigned driver';
COMMENT ON COLUMN fleet_vehicles.driver_license_document_url IS 'URL to the license document of the assigned driver';
COMMENT ON COLUMN fleet_vehicles.driver_is_south_african_citizen IS 'Indicates whether the assigned driver is a South African citizen';
