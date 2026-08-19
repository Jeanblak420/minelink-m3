-- Enable the HTTP extension
CREATE EXTENSION IF NOT EXISTS http;

-- Test the HTTP extension
DO $$
BEGIN
  PERFORM http_get('https://httpbin.org/get');
  RAISE NOTICE 'HTTP extension is working correctly';
EXCEPTION WHEN OTHERS THEN
  RAISE EXCEPTION 'HTTP extension is not working: %', SQLERRM;
END $$;

-- Create a simple function to test HTTP headers
CREATE OR REPLACE FUNCTION test_http_header()
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
SELECT test_http_header();
