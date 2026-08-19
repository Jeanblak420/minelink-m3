# Setup Database Connection Script
# This script sets up the database connection for local development

# Set the database connection string as an environment variable
$env:DB_URL = "postgresql://postgres.kkcseqmpgzzrogatdoqi:BuRG3rJ3@n1995@#!@aws-0-eu-central-1.pooler.supabase.com:6543/postgres"

# Display confirmation message
Write-Host "Database connection string has been set as an environment variable."
Write-Host "You can now run your application with access to the database."
Write-Host ""
Write-Host "To use this connection in your code, access the environment variable:"
Write-Host "DB_URL"
Write-Host ""
Write-Host "Press any key to continue..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
