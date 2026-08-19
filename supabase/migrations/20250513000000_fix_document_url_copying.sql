-- Fix document URL copying in the handle_driver_assignment function

-- Update the handle_driver_assignment function to correctly map column names
CREATE OR REPLACE FUNCTION handle_driver_assignment()
RETURNS TRIGGER AS $$
DECLARE
    driver_data RECORD;
BEGIN
    -- If a driver is being assigned (assigned_driver_id is being set to a non-NULL value)
    IF NEW.assigned_driver_id IS NOT NULL AND (OLD.assigned_driver_id IS NULL OR OLD.assigned_driver_id != NEW.assigned_driver_id) THEN
        -- Fetch the driver's details from the employees table
        -- Make sure we're using the correct column names from the employees table
        SELECT 
            first_name, 
            last_name, 
            id_number, 
            passport_or_workers_permit, -- This is the actual column name in employees
            license_document,
            id_document_url,
            passport_document_url,
            work_visa_document_url,
            license_document_url,
            is_south_african_citizen
        INTO driver_data
        FROM employees
        WHERE user_id = NEW.assigned_driver_id;
        
        -- If driver found, update the vehicle record with driver details
        IF FOUND THEN
            NEW.driver_first_name := driver_data.first_name;
            NEW.driver_last_name := driver_data.last_name;
            NEW.driver_id_number := driver_data.id_number;
            NEW.driver_passport_number := driver_data.passport_or_workers_permit; -- Map to the correct column
            NEW.driver_work_permit := NULL; -- This will be handled separately in the future
            NEW.drivers_license_document := driver_data.license_document;
            
            -- Copy document URLs
            NEW.driver_id_document_url := driver_data.id_document_url;
            NEW.driver_passport_document_url := driver_data.passport_document_url;
            NEW.driver_work_visa_document_url := driver_data.work_visa_document_url;
            NEW.driver_license_document_url := driver_data.license_document_url;
            NEW.driver_is_south_african_citizen := driver_data.is_south_african_citizen;
            
            -- Log the document URLs for debugging
            RAISE NOTICE 'Copying document URLs: ID=%', driver_data.id_document_url;
            RAISE NOTICE 'Copying document URLs: Passport=%', driver_data.passport_document_url;
            RAISE NOTICE 'Copying document URLs: Work Visa=%', driver_data.work_visa_document_url;
            RAISE NOTICE 'Copying document URLs: License=%', driver_data.license_document_url;
        ELSE
            -- If no matching driver found, raise an exception
            RAISE EXCEPTION 'Driver with user_id % not found', NEW.assigned_driver_id;
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

-- Add a comment to explain the purpose of this migration
COMMENT ON FUNCTION handle_driver_assignment() IS 'Automatically updates driver details including document URLs when a driver is assigned or unassigned';
