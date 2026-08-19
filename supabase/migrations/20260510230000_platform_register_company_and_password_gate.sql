begin;

alter table public.profiles
  add column if not exists must_change_password boolean not null default false;

alter table public.platform_admin_settings
  add column if not exists child_can_register_companies boolean not null default false;

create or replace function public.child_admin_permission(flag text)
returns boolean
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  settings record;
begin
  if not public.is_child_super_admin() then
    return false;
  end if;

  select * into settings
  from public.platform_admin_settings
  where id = 'main'
  limit 1;

  case flag
    when 'canViewCompanies' then return coalesce(settings.child_can_view_companies, false);
    when 'canViewUsers' then return coalesce(settings.child_can_view_users, false);
    when 'canGenerateTokens' then return coalesce(settings.child_can_generate_tokens, false);
    when 'canRevokeTokens' then return coalesce(settings.child_can_revoke_tokens, false);
    when 'canManageSeats' then return coalesce(settings.child_can_manage_seats, false);
    when 'canSuspendCompanies' then return coalesce(settings.child_can_suspend_companies, false);
    when 'canDownloadLogs' then return coalesce(settings.child_can_download_logs, false);
    when 'canCreateAnotherChild' then return coalesce(settings.child_can_create_another_child, false);
    when 'canRegisterCompanies' then return coalesce(settings.child_can_register_companies, false);
    else return false;
  end case;
end;
$$;

create or replace function public.super_admin_assign_child_admin(
  p_target_user_id uuid,
  p_target_email text,
  p_permissions jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  s record;
  old_child uuid;
  em text;
  tgt_role text;
begin
  if not public.is_main_super_admin() then
    raise exception 'Main super admin required';
  end if;

  if p_target_user_id is null then
    raise exception 'Target user is required';
  end if;

  em := lower(trim(coalesce(p_target_email, '')));
  if em = '' then
    raise exception 'Target email is required';
  end if;

  select platform_role into tgt_role
  from public.profiles
  where id = p_target_user_id
  limit 1;

  if tgt_role is null then
    raise exception 'Target user not found';
  end if;

  if tgt_role <> 'normalUser' then
    raise exception 'Target user must have platform role normalUser';
  end if;

  select * into s
  from public.platform_admin_settings
  where id = 'main'
  limit 1;

  old_child := s.child_super_admin_user_id;

  if old_child is not null and old_child is distinct from p_target_user_id then
    update public.profiles
    set platform_role = 'normalUser'
    where id = old_child;
  end if;

  update public.profiles
  set platform_role = 'superGlobalSerialAdminMainChild'
  where id = p_target_user_id;

  update public.platform_admin_settings
  set
    child_super_admin_user_id = p_target_user_id,
    child_super_admin_email = em,
    child_admin_created_at = timezone('utc', now()),
    child_admin_status = 'active',
    child_can_view_companies = coalesce((p_permissions->>'child_can_view_companies')::boolean, true),
    child_can_view_users = coalesce((p_permissions->>'child_can_view_users')::boolean, true),
    child_can_generate_tokens = coalesce((p_permissions->>'child_can_generate_tokens')::boolean, true),
    child_can_revoke_tokens = coalesce((p_permissions->>'child_can_revoke_tokens')::boolean, false),
    child_can_manage_seats = coalesce((p_permissions->>'child_can_manage_seats')::boolean, true),
    child_can_suspend_companies = coalesce((p_permissions->>'child_can_suspend_companies')::boolean, false),
    child_can_download_logs = coalesce((p_permissions->>'child_can_download_logs')::boolean, false),
    child_can_create_another_child = coalesce((p_permissions->>'child_can_create_another_child')::boolean, false),
    child_can_register_companies = coalesce((p_permissions->>'child_can_register_companies')::boolean, false),
    updated_at = timezone('utc', now())
  where id = 'main';

  perform public.insert_audit_log(
    'CHILD_ADMIN_CREATED',
    'user',
    p_target_user_id,
    em,
    null,
    'Child admin account created for ' || em
  );

  return jsonb_build_object('ok', true, 'user_id', p_target_user_id);
end;
$$;

create or replace function public.super_admin_patch_child_admin_permissions(p_patch jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_main_super_admin() then
    raise exception 'Main super admin required';
  end if;

  if p_patch is null then
    raise exception 'Patch payload is required';
  end if;

  update public.platform_admin_settings
  set
    child_can_view_companies = case
      when p_patch ? 'child_can_view_companies' then (p_patch->>'child_can_view_companies')::boolean
      else child_can_view_companies end,
    child_can_view_users = case
      when p_patch ? 'child_can_view_users' then (p_patch->>'child_can_view_users')::boolean
      else child_can_view_users end,
    child_can_generate_tokens = case
      when p_patch ? 'child_can_generate_tokens' then (p_patch->>'child_can_generate_tokens')::boolean
      else child_can_generate_tokens end,
    child_can_revoke_tokens = case
      when p_patch ? 'child_can_revoke_tokens' then (p_patch->>'child_can_revoke_tokens')::boolean
      else child_can_revoke_tokens end,
    child_can_manage_seats = case
      when p_patch ? 'child_can_manage_seats' then (p_patch->>'child_can_manage_seats')::boolean
      else child_can_manage_seats end,
    child_can_suspend_companies = case
      when p_patch ? 'child_can_suspend_companies' then (p_patch->>'child_can_suspend_companies')::boolean
      else child_can_suspend_companies end,
    child_can_download_logs = case
      when p_patch ? 'child_can_download_logs' then (p_patch->>'child_can_download_logs')::boolean
      else child_can_download_logs end,
    child_can_create_another_child = case
      when p_patch ? 'child_can_create_another_child' then (p_patch->>'child_can_create_another_child')::boolean
      else child_can_create_another_child end,
    child_can_register_companies = case
      when p_patch ? 'child_can_register_companies' then (p_patch->>'child_can_register_companies')::boolean
      else child_can_register_companies end,
    updated_at = timezone('utc', now())
  where id = 'main';

  perform public.insert_audit_log(
    'CHILD_ADMIN_PERMISSION_UPDATED',
    'settings',
    null,
    null,
    null,
    'Child admin permissions updated'
  );

  return jsonb_build_object('ok', true);
end;
$$;

commit;
