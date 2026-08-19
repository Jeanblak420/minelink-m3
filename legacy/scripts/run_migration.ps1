# PowerShell script to run the migration using Supabase CLI

Write-Host "Running migration to add document flag fields to employees table..." -ForegroundColor Green

# Set your Supabase project reference
$SUPABASE_PROJECT_ID = "kkcseqmpgzzrogatdoqi"

# Run the migration using Supabase CLI
supabase db push --db-url postgres://postgres:postgres@localhost:54322/postgres --project-ref $SUPABASE_PROJECT_ID

Write-Host "Migration completed successfully!" -ForegroundColor Green

# If you prefer to run the SQL directly, you can use the following command:
Write-Host "Alternatively, you can run the SQL directly in the Supabase dashboard:" -ForegroundColor Yellow
Write-Host "1. Go to https://kkcseqmpgzzrogatdoqi.supabase.co" -ForegroundColor Yellow
Write-Host "2. Navigate to the SQL Editor" -ForegroundColor Yellow
Write-Host "3. Create a new query and paste the SQL from supabase/migrations/20250511000000_add_document_flag_fields.sql" -ForegroundColor Yellow
Write-Host "4. Click 'Run' to execute the query" -ForegroundColor Yellow
