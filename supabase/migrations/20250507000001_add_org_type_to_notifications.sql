-- Add org_type field to notifications table
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS org_type TEXT;
