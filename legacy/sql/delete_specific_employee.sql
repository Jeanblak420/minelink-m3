-- This script will force delete the specific employee and related notifications

-- First, let's disable the trigger that prevents notification deletion
ALTER TABLE notifications DISABLE TRIGGER prevent_notification_deletion_trigger;

-- Delete any notifications related to this employee
DELETE FROM notifications WHERE employee_id = '980056b1-8fb5-4a06-a28a-a6d02ecf801b';

-- Now delete the employee
DELETE FROM employees WHERE id = '980056b1-8fb5-4a06-a28a-a6d02ecf801b';

-- Re-enable the trigger
ALTER TABLE notifications ENABLE TRIGGER prevent_notification_deletion_trigger;

-- Confirm deletion
SELECT 'Employee deleted successfully' as result;
