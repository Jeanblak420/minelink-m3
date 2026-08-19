-- Enable the HTTP extension if it's not already enabled
CREATE EXTENSION IF NOT EXISTS http;

-- Test the HTTP extension by creating a simple function
CREATE OR REPLACE FUNCTION test_http_extension()
RETURNS TEXT AS $$
DECLARE
  result TEXT;
BEGIN
  SELECT content::text INTO result FROM http((
    'GET',
    'https://httpbin.org/get',
    ARRAY[http_header('Content-Type', 'application/json')],
    NULL,
    5000
  ));
  
  RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Test the function
SELECT test_http_extension();
