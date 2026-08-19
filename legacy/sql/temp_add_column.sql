ALTER TABLE fleet_vehicles ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;
UPDATE fleet_vehicles SET is_active = TRUE WHERE is_active IS NULL;
COMMENT ON COLUMN fleet_vehicles.is_active IS 'Indicates whether the vehicle is active (true) or inactive (false)';
