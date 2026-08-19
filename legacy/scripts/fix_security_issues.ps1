# PowerShell script to fix security issues in Supabase

Write-Host "Fixing security issues identified by Security Advisor..." -ForegroundColor Green

# Option 1: Using Supabase Dashboard (recommended)
Write-Host "Option 1: Apply fixes using Supabase Dashboard" -ForegroundColor Cyan
Write-Host "1. Go to https://app.supabase.com/project/kkcseqmpgzzrogatdoqi/sql" -ForegroundColor Yellow
Write-Host "2. Create a new query" -ForegroundColor Yellow
Write-Host "3. Copy and paste the contents of supabase/migrations/20250511000000_fix_security_issues.sql" -ForegroundColor Yellow
Write-Host "4. Run the SQL" -ForegroundColor Yellow

# Option 2: Using Supabase CLI with password from environment variable
Write-Host "`nOption 2: Apply fixes using Supabase CLI" -ForegroundColor Cyan
Write-Host "Enter your database password:" -ForegroundColor Yellow
$password = Read-Host -AsSecureString
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($password)
$plainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Set environment variables for authentication
$env:PGPASSWORD = $plainPassword

Write-Host "Attempting to apply security fixes using CLI..." -ForegroundColor Yellow
try {
    # Run the SQL migration directly on the remote database
    supabase db execute --project-ref kkcseqmpgzzrogatdoqi --file supabase/migrations/20250511000000_fix_security_issues.sql
    Write-Host "Security fixes applied successfully!" -ForegroundColor Green
} catch {
    Write-Host "Error applying security fixes using CLI: $_" -ForegroundColor Red
    Write-Host "Please use Option 1 (Supabase Dashboard) instead." -ForegroundColor Yellow
}

# Clear the password from environment for security
$env:PGPASSWORD = ""
[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

Write-Host "`nAfter applying fixes, try running your fleet management migration again." -ForegroundColor Green
