@echo off
echo Applying run_sql function migration...

REM Set your Supabase project reference
set SUPABASE_PROJECT_ID=kkcseqmpgzzrogatdoqi

REM Run the SQL migration directly on the remote database
supabase db execute --project-ref %SUPABASE_PROJECT_ID% --file supabase/migrations/20250515000000_create_run_sql_function.sql

echo Migration completed successfully!
echo The run_sql function is now available for use in your application.

REM Open the Supabase SQL Editor in the browser for manual execution if needed
echo If you prefer to run the SQL manually, you can use the Supabase SQL Editor:
echo 1. Go to https://app.supabase.com/project/%SUPABASE_PROJECT_ID%/sql
echo 2. Create a new query and paste the SQL from supabase/migrations/20250515000000_create_run_sql_function.sql
echo 3. Click 'Run' to execute the query

REM Pause to keep the window open
pause
