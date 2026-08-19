-- Add importance field to notifications table
ALTER TABLE notifications ADD COLUMN IF NOT EXISTS importance TEXT;

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS notifications_importance_idx ON notifications(importance);
