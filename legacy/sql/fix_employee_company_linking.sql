-- Drop existing problematic function
DROP FUNCTION IF EXISTS update_employee_company(UUID, TEXT);

-- Create the proper function
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION update_employee_company(UUID, UUID) TO authenticated;
