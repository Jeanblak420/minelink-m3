-- Drop the trigger that prevents notification deletion
DROP TRIGGER IF EXISTS prevent_notification_deletion_trigger ON notifications;
