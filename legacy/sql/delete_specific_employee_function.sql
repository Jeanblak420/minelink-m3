-- Create a function to force delete an employee
CREATE OR REPLACE FUNCTION force_delete_employee(employee_id_param UUID)
RETURNS TEXT AS $$
DECLARE
  result TEXT;
BEGIN
  -- Disable all triggers temporarily
  SET session_replication_role = 'replica';

  -- Delete notifications first
  DELETE FROM notifications WHERE employee_id = employee_id_param;

  -- Delete from employee_status_history if it exists
  BEGIN
    DELETE FROM employee_status_history WHERE employee_id = employee_id_param;
  EXCEPTION WHEN undefined_table THEN
    -- Table doesn't exist, continue
  END;

  -- Delete the employee
  DELETE FROM employees WHERE id = employee_id_param;

  -- Re-enable triggers
  SET session_replication_role = 'origin';

  RETURN 'Employee and related records deleted successfully';
EXCEPTION WHEN OTHERS THEN
  -- Re-enable triggers even if there's an error
  SET session_replication_role = 'origin';
  RETURN 'Error: ' || SQLERRM;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Execute the function to delete the specific employee
SELECT force_delete_employee('980056b1-8fb5-4a06-a28a-a6d02ecf801b');
