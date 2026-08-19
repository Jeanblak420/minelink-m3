# PowerShell script to apply the migration directly to the remote Supabase instance

Write-Host "Applying migration to fix employee_status_history table and notification policies..." -ForegroundColor Green

# Set your Supabase project reference
$SUPABASE_PROJECT_ID = "kkcseqmpgzzrogatdoqi"

# Run the SQL migration directly on the remote database
supabase db execute --project-ref $SUPABASE_PROJECT_ID --file supabase/migrations/20250507000000_fix_employee_status_history.sql

Write-Host "Migration completed successfully!" -ForegroundColor Green
