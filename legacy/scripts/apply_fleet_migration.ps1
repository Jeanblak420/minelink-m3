# PowerShell script to apply the fleet management migration

Write-Host "Applying fleet management migration..." -ForegroundColor Green

# Set your Supabase project reference
$SUPABASE_PROJECT_ID = "kkcseqmpgzzrogatdoqi"

# Run the SQL migration directly on the remote database
supabase db execute --project-ref $SUPABASE_PROJECT_ID --file supabase/migrations/20250510000000_create_fleet_management.sql

Write-Host "Migration completed successfully!" -ForegroundColor Green
