# Script to apply the RLS policy fix to Supabase

# Supabase project reference
$SUPABASE_PROJECT_ID = "kkcseqmpgzzrogatdoqi"

# Check if supabase CLI is installed
try {
    $supabasePath = Get-Command supabase -ErrorAction Stop
    Write-Host "Supabase CLI found at: $($supabasePath.Source)" -ForegroundColor Green
} catch {
    Write-Host "Supabase CLI not found in PATH. Please install it or add it to your PATH." -ForegroundColor Red
    Write-Host "You can manually apply the SQL fix by copying the content of fix_notifications_rls.sql to the Supabase SQL editor." -ForegroundColor Yellow
    exit 1
}

# Apply the RLS fix
Write-Host "Applying RLS policy fix for notifications table..." -ForegroundColor Cyan
supabase db execute --project-ref $SUPABASE_PROJECT_ID --file fix_notifications_rls.sql

Write-Host "RLS policy fix applied successfully!" -ForegroundColor Green
Write-Host "If you don't have the Supabase CLI configured, please apply the SQL manually through the Supabase dashboard." -ForegroundColor Yellow
