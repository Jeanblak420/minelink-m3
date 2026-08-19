-- Add is_active column to fleet_vehicles table
ALTER TABLE fleet_vehicles 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- Add comment to explain the field
COMMENT ON COLUMN fleet_vehicles.is_active IS 'Indicates whether the vehicle is active (true) or inactive (false)';

-- Update the handle_driver_assignment function to handle the new field
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
            passport_number,
            work_permit, 
            license_document,
            id_document_url,
            passport_document_url,
            work_visa_document_url,
            license_document_url,
            is_south_african_citizen
        INTO driver_data
        FROM employees
        WHERE user_id = NEW.assigned_driver_id;
        
        -- Update the vehicle record with the driver's details
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
    END IF;
    
    -- If a driver is being unassigned (assigned_driver_id is being set to NULL)
    IF NEW.assigned_driver_id IS NULL AND OLD.assigned_driver_id IS NOT NULL THEN
        -- Clear the driver details
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
