# PowerShell script to apply the fixes for employee_status_history and notifications tables

Write-Host "Applying fixes for employee_status_history and notifications tables..." -ForegroundColor Green

# Set your Supabase project reference
$SUPABASE_PROJECT_ID = "kkcseqmpgzzrogatdoqi"

# Run the SQL migrations directly on the remote database
Write-Host "Applying fix for employee_status_history table..." -ForegroundColor Cyan
supabase db execute --project-ref $SUPABASE_PROJECT_ID --file supabase/migrations/20250507000000_fix_employee_status_history.sql

Write-Host "Adding org_type to notifications table..." -ForegroundColor Cyan
supabase db execute --project-ref $SUPABASE_PROJECT_ID --file supabase/migrations/20250507000001_add_org_type_to_notifications.sql

Write-Host "Adding metadata to notifications table..." -ForegroundColor Cyan
supabase db execute --project-ref $SUPABASE_PROJECT_ID --file supabase/migrations/20250507000002_add_metadata_to_notifications.sql

Write-Host "Adding importance to notifications table..." -ForegroundColor Cyan
supabase db execute --project-ref $SUPABASE_PROJECT_ID --file supabase/migrations/20250507000003_add_importance_to_notifications.sql

Write-Host "Fixing RLS policies for notifications table..." -ForegroundColor Cyan
supabase db execute --project-ref $SUPABASE_PROJECT_ID --file supabase/migrations/20250507000004_fix_notifications_rls.sql

Write-Host "All fixes applied successfully!" -ForegroundColor Green
