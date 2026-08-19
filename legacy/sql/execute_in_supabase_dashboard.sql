-- Execute this SQL in the Supabase Dashboard SQL Editor

-- Add is_active column to fleet_vehicles table
ALTER TABLE fleet_vehicles 
ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- Update existing records to set is_active to true
UPDATE fleet_vehicles
SET is_active = TRUE
WHERE is_active IS NULL;

-- Add comment to explain the field
COMMENT ON COLUMN fleet_vehicles.is_active IS 'Indicates whether the vehicle is active (true) or inactive (false)';

-- Verify the column was added
SELECT column_name, data_type, column_default 
FROM information_schema.columns 
WHERE table_name = 'fleet_vehicles' AND column_name = 'is_active';
