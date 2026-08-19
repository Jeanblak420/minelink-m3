-- Fix the webhook functions

-- First, make sure the HTTP extension is enabled
CREATE EXTENSION IF NOT EXISTS http;

-- Create or replace the employees webhook function
CREATE OR REPLACE FUNCTION employees_webhook()
RETURNS TRIGGER AS $$
DECLARE
  webhook_url TEXT;
  payload JSONB;
  result JSONB;
BEGIN
  -- Use a hardcoded webhook URL
  webhook_url := 'https://kkcseqmpgzzrogatdoqi.supabase.co/functions/v1';

  -- Build the payload
  payload := jsonb_build_object(
    'type', TG_OP,
    'table', TG_TABLE_NAME,
    'schema', TG_TABLE_SCHEMA,
    'record', row_to_json(NEW),
    'old_record', CASE WHEN TG_OP = 'UPDATE' OR TG_OP = 'DELETE' THEN row_to_json(OLD) ELSE null END
  );

  -- Call the webhook function
  SELECT content::jsonb FROM http((
    'POST',
    webhook_url || '/employee-webhook',
    ARRAY[http_header('Content-Type', 'application/json')],
    payload::text,
    5000
  )) INTO result;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create or replace the trigger for the employees table
DROP TRIGGER IF EXISTS employees_webhook_trigger ON employees;
CREATE TRIGGER employees_webhook_trigger
AFTER INSERT OR UPDATE OR DELETE ON employees
FOR EACH ROW
EXECUTE FUNCTION employees_webhook();

-- Test the function with a simple HTTP call
CREATE OR REPLACE FUNCTION test_http_call()
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
SELECT test_http_call();
