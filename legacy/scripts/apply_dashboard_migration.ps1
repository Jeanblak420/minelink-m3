# PowerShell script to apply migrations using Supabase Dashboard

Write-Host "Applying migrations using Supabase Dashboard..." -ForegroundColor Green

# Open the Supabase SQL Editor in the browser
Start-Process "https://app.supabase.com/project/kkcseqmpgzzrogatdoqi/sql"

Write-Host "`nFollow these steps:" -ForegroundColor Cyan
Write-Host "1. Log in to your Supabase account if needed" -ForegroundColor Yellow
Write-Host "2. Create a new query in the SQL Editor" -ForegroundColor Yellow
Write-Host "3. First apply the security fixes:" -ForegroundColor Yellow
Write-Host "   - Copy and paste the contents of supabase/migrations/20250511000000_fix_security_issues.sql" -ForegroundColor Yellow
Write-Host "   - Run the SQL" -ForegroundColor Yellow
Write-Host "4. Then apply the fleet management migration:" -ForegroundColor Yellow
Write-Host "   - Create another new query" -ForegroundColor Yellow
Write-Host "   - Copy and paste the contents of supabase/migrations/20250510000001_create_fleet_management_dashboard.sql" -ForegroundColor Yellow
Write-Host "   - Run the SQL" -ForegroundColor Yellow

Write-Host "`nAfter applying both migrations, you should be able to run your Flutter application successfully." -ForegroundColor Green
