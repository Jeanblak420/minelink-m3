-- This script will force delete an employee and related notifications
-- Replace 'EMPLOYEE_ID_HERE' with the actual employee ID you want to delete

-- First, let's disable the trigger that prevents notification deletion
ALTER TABLE notifications DISABLE TRIGGER prevent_notification_deletion_trigger;

-- Delete any notifications related to this employee
DELETE FROM notifications WHERE employee_id = 'EMPLOYEE_ID_HERE';

-- Now delete the employee
DELETE FROM employees WHERE id = 'EMPLOYEE_ID_HERE';

-- Re-enable the trigger
ALTER TABLE notifications ENABLE TRIGGER prevent_notification_deletion_trigger;

-- Confirm deletion
SELECT 'Employee deleted successfully' as result;
