# PowerShell script to apply the run_sql function migration

Write-Host "Applying run_sql function migration..." -ForegroundColor Green

# Set your Supabase project reference
$SUPABASE_PROJECT_ID = "kkcseqmpgzzrogatdoqi"

# Run the SQL migration directly on the remote database
supabase db execute --project-ref $SUPABASE_PROJECT_ID --file supabase/migrations/20250515000000_create_run_sql_function.sql

Write-Host "Migration completed successfully!" -ForegroundColor Green
Write-Host "The run_sql function is now available for use in your application." -ForegroundColor Green

# Open the Supabase SQL Editor in the browser for manual execution if needed
Write-Host "If you prefer to run the SQL manually, you can use the Supabase SQL Editor:" -ForegroundColor Yellow
Write-Host "1. Go to https://app.supabase.com/project/$SUPABASE_PROJECT_ID/sql" -ForegroundColor Yellow
Write-Host "2. Create a new query and paste the SQL from supabase/migrations/20250515000000_create_run_sql_function.sql" -ForegroundColor Yellow
Write-Host "3. Click 'Run' to execute the query" -ForegroundColor Yellow

# Pause to keep the window open
Write-Host "Press any key to continue..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
