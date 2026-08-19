-- Find employee by name
-- Replace 'First Name' and 'Last Name' with the actual name of the employee you want to delete
SELECT id, first_name, last_name, user_id, company_id 
FROM employees 
WHERE first_name ILIKE '%First Name%' AND last_name ILIKE '%Last Name%';
