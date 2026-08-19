-- Check for notifications related to this employee
SELECT id, title, message, type, is_read, created_at
FROM notifications 
WHERE employee_id = '980056b1-8fb5-4a06-a28a-a6d02ecf801b';
