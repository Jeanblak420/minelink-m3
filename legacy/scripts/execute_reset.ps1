# PowerShell script to execute SQL directly
$sqlContent = Get-Content -Path "reset_database.sql" -Raw

# Open the SQL Editor in the browser
Start-Process "https://supabase.com/dashboard/project/kkcseqmpgzzrogatdoqi/sql"

# Display instructions
Write-Host "Please follow these steps to reset your Supabase database:"
Write-Host "1. Copy the SQL script below"
Write-Host "2. Paste it into the SQL Editor in the browser"
Write-Host "3. Click 'Run' to execute the script"
Write-Host ""
Write-Host "SQL Script:"
Write-Host "----------------------------------------"
Write-Host $sqlContent
Write-Host "----------------------------------------"
Write-Host ""
Write-Host "After executing the script, your database will be reset with all the necessary tables and policies."
