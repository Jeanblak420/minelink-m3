-- Drop the existing trigger
DROP TRIGGER IF EXISTS prevent_notification_deletion_trigger ON notifications;

-- Create a modified function that allows cascade deletes
CREATE OR REPLACE FUNCTION prevent_notification_deletion()
RETURNS TRIGGER AS $$
BEGIN
  -- Allow deletion if it's part of a cascade from employee or company deletion
  IF EXISTS (SELECT 1 FROM pg_trigger WHERE tgrelid = TG_RELID AND tgname = TG_NAME AND tgisinternal) THEN
    -- This is an internal trigger (like a foreign key cascade), so allow it
    RETURN OLD;
  ELSE
    -- This is a direct deletion attempt, so block it
    RAISE EXCEPTION 'Failed to delete table row: Notifications cannot be deleted to maintain persistent history (Step 11)';
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create a new trigger that allows cascade deletes
CREATE TRIGGER prevent_notification_deletion_trigger
  BEFORE DELETE ON notifications
  FOR EACH ROW
  EXECUTE FUNCTION prevent_notification_deletion();
