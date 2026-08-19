begin;

-- ============================================================
-- Token expiry enforcement job (scheduled)
-- ============================================================

create extension if not exists pg_cron with schema extensions;

create or replace function public.expire_organizations_job()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  updated_count integer := 0;
begin
  -- Mark active orgs expired when the current token is past expiry (or missing)
  with expired_orgs as (
    select c.id
    from public.companies c
    where c.status = 'active'
      and (c.token_expires_at is null or c.token_expires_at <= timezone('utc', now()))
  ),
  upd as (
    update public.companies c
    set
      status = 'expired',
      updated_at = timezone('utc', now())
    where c.id in (select id from expired_orgs)
    returning c.id
  )
  select count(*) into updated_count from upd;

  if updated_count > 0 then
    insert into public.audit_logs (
      actor_user_id,
      actor_email,
      actor_platform_role,
      action_type,
      target_type,
      target_id,
      organization_id,
      description,
      created_at
    )
    select
      null,
      'system',
      'system',
      'TOKEN_EXPIRED',
      'organization',
      u.id,
      u.id,
      'Organization expired due to token expiry.',
      timezone('utc', now())
    from upd u;
  end if;

  return updated_count;
end;
$$;

-- Try to schedule it daily at 01:05 UTC (safe to re-run migration).
do $$
begin
  if not exists (
    select 1
    from cron.job
    where jobname = 'expire_organizations_daily'
  ) then
    perform cron.schedule(
      'expire_organizations_daily',
      '5 1 * * *',
      -- Cold replay 2026-08-18: the inner dollar-quote here used the same tag
      -- as the enclosing DO block, so it CLOSED that block early and the rest
      -- parsed as loose SQL (42601). A distinct tag is required.
      -- (The first attempt at this comment spelled the bad tag out literally
      --  and broke the file again in exactly the same way. Do not do that.)
      $job$select public.expire_organizations_job();$job$
    );
  end if;
exception
  when undefined_table or insufficient_privilege or invalid_schema_name then
    -- pg_cron may be unavailable in some environments; function still exists for external scheduling.
    null;
end$$;

commit;

