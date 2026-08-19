-- Flatten the child super-admin into a single full-rights super-global-admin
-- (CLAUDE.md §4 "Super admins are equal — remove the child-admin concept").
--
-- Safe because: (a) is_super_admin()/is_platform_admin() already grant BOTH the
-- main and child roles identical RLS access — no policy references the child
-- functions; (b) every super_admin_* action RPC gates the child only via
-- `if is_child_super_admin() and not child_admin_permission(...)`, which simply
-- stops firing once no child role exists. No RLS rewrite, no column drops.

begin;

-- 1. Promote any child super-admin to a full main super-admin. After this there
--    is a single super-global-admin role; is_child_super_admin() naturally
--    returns false for everyone, so all per-flag child gates are bypassed and
--    both admins have identical full rights.
-- Cold replay 2026-08-18: `parent_super_admin_id` is added by NO file in this
-- repo — it reached production through an unmirrored migration, and
-- 20260712170000 drops it again a step later. So on a rebuild this update dies
-- with 42703 while doing nothing that matters. Written column-by-column so the
-- promotion still happens either way.
do $flatten$
begin
  if exists (select 1 from information_schema.columns
              where table_schema = 'public' and table_name = 'profiles'
                and column_name = 'parent_super_admin_id') then
    execute $sql$
      update public.profiles
         set platform_role = 'superGlobalSerialAdminMain',
             parent_super_admin_id = null
       where platform_role = 'superGlobalSerialAdminMainChild'$sql$;
  else
    update public.profiles
       set platform_role = 'superGlobalSerialAdminMain'
     where platform_role = 'superGlobalSerialAdminMainChild';
  end if;
end
$flatten$;

-- 2. Belt-and-suspenders: any lingering permission check (backend or the Dart
--    UI that reads it) now grants full rights to every super-admin and nothing
--    to non-admins. Signature unchanged so existing callers keep working.
create or replace function public.child_admin_permission(flag text)
returns boolean
language sql
stable
security definer
set search_path to 'public'
as $function$
  select public.is_super_admin();
$function$;

commit;
