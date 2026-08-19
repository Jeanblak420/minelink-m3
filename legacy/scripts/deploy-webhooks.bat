@echo off
echo Deploying Email Notification Edge Function...

REM Check if Supabase CLI is installed
where supabase >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Supabase CLI not found. Please install it first.
    echo You can install it using: scoop install supabase
    exit /b 1
)

REM Deploy the function
echo Deploying email-notification function...
supabase functions deploy email-notification

REM Set environment variables
echo Setting environment variables...
set /p SENDGRID_API_KEY=Please enter your SendGrid API key: 
set /p FROM_EMAIL=Please enter the FROM email address (e.g., notifications@minguide.com): 

supabase secrets set SENDGRID_API_KEY=%SENDGRID_API_KEY%
supabase secrets set FROM_EMAIL=%FROM_EMAIL%

echo Deployment completed successfully!
echo.
echo If you encounter any issues, please check the logs in the Supabase Dashboard:
echo https://supabase.com/dashboard/project/kkcseqmpgzzrogatdoqi/functions
echo.
echo You can also deploy manually through the Supabase Dashboard.  