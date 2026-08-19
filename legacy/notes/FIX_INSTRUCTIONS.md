# Fix Instructions for Employee Role Assignment Issues

This document provides instructions for fixing the issues with employee role assignment in the Supabase database.

## Issues Fixed

1. **Missing columns in `employee_status_history` table**:
   - Added `actioned_by_id`, `actioned_by_name`, and `assigned_role` columns
   - Created indexes for better performance

2. **Row Level Security (RLS) policy issues for `notifications` table**:
   - Fixed RLS policies to allow proper insertion of notifications

## How to Apply the Fix

### Option 1: Using Supabase CLI (Recommended)

1. Run the PowerShell script to apply the migration:

```powershell
.\run_migration.ps1
```

This uses the Supabase CLI to apply the tracked migration to the linked
Supabase project.

### Option 2: Apply Directly to the Live Supabase Project

1. Run the PowerShell script to apply the migration to the live Supabase
   project:

```powershell
.\apply_remote_migration.ps1
```

### Option 3: Using the Supabase SQL Editor

1. Open the Supabase dashboard and navigate to the SQL Editor
2. Copy the contents of `fix_tables_direct.sql`
3. Paste into the SQL Editor and run the query

## Verification

After applying the fix, you should be able to:

1. Assign roles to employees without errors
2. See proper status history entries with action attribution
3. Create and view notifications related to role assignments

If you continue to experience issues, please check the browser console for any new error messages.
