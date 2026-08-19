-- Create a function to prevent deletion of notifications
CREATE OR REPLACE FUNCTION prevent_notification_deletion()
RETURNS TRIGGER AS $$
BEGIN
  RAISE EXCEPTION 'Failed to delete table row: Notifications cannot be deleted to maintain persistent history (Step 11)';
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create a trigger to prevent deletion of notifications
DROP TRIGGER IF EXISTS prevent_notification_deletion_trigger ON notifications;
CREATE TRIGGER prevent_notification_deletion_trigger
  BEFORE DELETE ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION prevent_notification_deletion();
