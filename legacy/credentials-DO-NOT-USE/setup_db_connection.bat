@echo off
REM Setup Database Connection Script
REM This script sets up the database connection for local development

REM Set the database connection string as an environment variable
set DB_URL=postgresql://postgres.kkcseqmpgzzrogatdoqi:BuRG3rJ3@n1995@#!@aws-0-eu-central-1.pooler.supabase.com:6543/postgres

REM Display confirmation message
echo Database connection string has been set as an environment variable.
echo You can now run your application with access to the database.
echo.
echo To use this connection in your code, access the environment variable:
echo DB_URL
echo.
echo Press any key to continue...
pause > nul
