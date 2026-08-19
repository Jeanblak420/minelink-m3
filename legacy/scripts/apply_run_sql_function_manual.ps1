# PowerShell script to apply the run_sql function migration manually

Write-Host "Opening Supabase SQL Editor for manual migration..." -ForegroundColor Green

# Set your Supabase project reference
$SUPABASE_PROJECT_ID = "kkcseqmpgzzrogatdoqi"

# Read the SQL file content
$sqlContent = Get-Content -Path "supabase/migrations/20250515000000_create_run_sql_function.sql" -Raw

# Open the Supabase SQL Editor in the browser
Start-Process "https://app.supabase.com/project/$SUPABASE_PROJECT_ID/sql"

# Display instructions
Write-Host "Please follow these steps to create the run_sql function:" -ForegroundColor Yellow
Write-Host "1. Copy the SQL script below" -ForegroundColor Yellow
Write-Host "2. Paste it into the SQL Editor in the browser" -ForegroundColor Yellow
Write-Host "3. Click 'Run' to execute the query" -ForegroundColor Yellow
Write-Host ""
Write-Host "SQL Script:" -ForegroundColor Cyan
Write-Host "----------------------------------------" -ForegroundColor Cyan
Write-Host $sqlContent -ForegroundColor White
Write-Host "----------------------------------------" -ForegroundColor Cyan
Write-Host ""
Write-Host "After executing the script, the run_sql function will be available for use in your application." -ForegroundColor Green

# Pause to keep the window open
Write-Host "Press any key to continue..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
