-- Add metadata field to notifications table
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS metadata JSONB;
