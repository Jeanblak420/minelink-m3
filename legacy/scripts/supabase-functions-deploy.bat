@echo off
echo Deploying Supabase Edge Function...
if "%1"=="" (
    echo Error: Function name is required.
    echo Usage: supabase-functions-deploy.bat function-name
    exit /b 1
)

set FUNCTION_NAME=%1
set FUNCTION_DIR=supabase\functions\%FUNCTION_NAME%

if not exist %FUNCTION_DIR% (
    echo Error: Function %FUNCTION_NAME% does not exist.
    exit /b 1
)

echo Deploying function %FUNCTION_NAME%...
"C:\Users\Somebody Someone\scoop\shims\supabase.exe" functions deploy %FUNCTION_NAME%

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Deployment failed. Make sure you are logged in to Supabase CLI.
    echo To login, run: supabase login
    echo.
    echo If you're not logged in, you can still create and test functions locally,
    echo but you'll need to install Docker Desktop to run them locally.
    exit /b 1
)

echo Function %FUNCTION_NAME% deployed successfully!
