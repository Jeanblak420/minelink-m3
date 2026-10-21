# Super Admin Equality Changes

**Date:** 2026-09-16  
**Project:** MineLink-M3  
**Supabase Project:** yftazblpmicqtamyiwyb

## Summary

Both super global admins now have **identical, full permissions** with no "main" admin distinction.

## Changes Made

### 1. Database Schema Changes

#### `platform_admin_settings` Table
- Made `main_super_admin_email` nullable (was NOT NULL)
- Made `main_super_admin_user_id` nullable (was NOT NULL)
- Set both fields to NULL
- Added comments marking them as legacy fields for backward compatibility

#### RLS Policy Changes
- **Removed:** `Main super admin can update settings` policy (used `is_main_super_admin()`)
- **Added:** `Super admins can update settings` policy (uses `is_super_admin()`)

### 2. Current Super Admins

Both users have `platform_role = 'superGlobalSerialAdminMain'`:

| Email | User ID | Display Name | Platform Role |
|-------|---------|--------------|---------------|
| jean@minelink.org | e27e173f-3be1-45d4-8272-2741ef76e2d6 | Jean Burger | superGlobalSerialAdminMain |
| bryson@minelink.org | 70aad2e1-9a05-4c52-9223-f47396040eae | Bryson Mansoor | superGlobalSerialAdminMain |

### 3. Permission Verification

#### `is_super_admin()` Function
```sql
CREATE OR REPLACE FUNCTION public.is_super_admin()
RETURNS boolean
AS $function$
  select exists(
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.platform_role = 'superGlobalSerialAdminMain'
  );
$function$
```

This function is used by **25 RLS policies** across the database, including:
- Super admins can read/update platform_admin_settings
- Super admins can manage all companies, employees, roles, statuses
- Super admins can read all transactional data (trips, transactions, routes, etc.)
- Super admins can manage serial tokens, organization seats, audit logs
- Super admins can access all platform-level operations

#### What Both Users Can Now Do

✅ Add new organizations  
✅ Manage all companies (suspend/reactivate)  
✅ Set employee roles and statuses  
✅ Release organization seats  
✅ Manage all platform data (trips, transactions, routes, etc.)  
✅ Access all super admin screens and functions  
✅ Read/write to all tables protected by `is_super_admin()` or `is_platform_admin()` policies  
✅ Update platform_admin_settings table (newly granted)  

### 4. Migration File Updated

Updated `clean_profiles_and_add_admins.sql` to reflect that both super admins are equal:
- Removed step that set Jean as "main" admin
- Added comment explaining both have equal permissions
- Updated to NULL out the legacy fields

## Verification

Both users now have:
- **Identical** platform roles
- **Identical** database function access (`is_super_admin()`)
- **Identical** RLS policy permissions
- **No** special "main" admin restrictions or privileges

The `platform_admin_settings` table fields are kept for backward compatibility only and no longer affect permissions.
