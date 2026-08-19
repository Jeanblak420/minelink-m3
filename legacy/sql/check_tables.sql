-- Check all tables in the public schema
SELECT 
    table_name, 
    (SELECT count(*) FROM information_schema.columns WHERE table_name = t.table_name) AS column_count
FROM 
    information_schema.tables t
WHERE 
    table_schema = 'public'
ORDER BY 
    table_name;
