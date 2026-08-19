-- Drop the incorrect version of the function (with text argument)
DROP FUNCTION IF EXISTS update_employee_company(uuid, text);

-- (Optional) Re-create the correct version for safety
CREATE OR REPLACE FUNCTION update_employee_company(
  employee_id_param UUID,
  company_id_param UUID
)
RETURNS VOID AS $$
BEGIN
  UPDATE employees
  SET 
    company_id = company_id_param,
    updated_at = NOW()
  WHERE id = employee_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION update_employee_company(UUID, UUID) TO authenticated;

COMMENT ON FUNCTION update_employee_company(UUID, UUID) IS 'Safely updates an employee''s company_id with proper type handling';
