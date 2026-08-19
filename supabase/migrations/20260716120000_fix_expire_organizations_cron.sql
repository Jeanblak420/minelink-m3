-- Fix the nightly expire_organizations() cron (pg_cron job 1), broken since the
-- audit_logs FK was added: the function inserted audit rows with a fake
-- all-zeros "system" actor UUID, violating audit_logs_actor_user_id_fkey
-- (references profiles(id)). The FK error aborted the WHOLE run every night,
-- so token expiry enforcement silently never executed.
--
-- Fix:
--   1. Allow NULL actor_user_id (system-generated rows have no human actor;
--      the Dart model already tolerates null). FK still enforced when non-null.
--   2. Recreate expire_organizations() to insert NULL as the actor.
--   3. Data repair: while the cron was broken, the long-lived dev/test
--      companies (Iron Hills Mining, Atlas Buyer Group, Fast Freight
--      Logistics, Roadhaul Logistics, ...) sailed past token_expires_at while
--      still in daily use. Renew those still-active-but-expired tokens by a
--      year so the repaired cron doesn't mass-expire the working environment
--      on its next run. Real expiry management stays with the super admin.

begin;

-- 1. System audit rows carry no human actor.
alter table public.audit_logs alter column actor_user_id drop not null;

-- 2. FK-safe cron function.
create or replace function public.expire_organizations()
returns void
language plpgsql
security definer
set search_path to ''
as $function$
declare
  v_org record;
begin
  for v_org in
    select id, company_name, org_type
    from public.companies
    where status = 'active'
    and token_expires_at is not null
    and token_expires_at <= timezone('utc', now())
  loop
    -- Expire the organization
    update public.companies
    set status = 'expired', updated_at = timezone('utc', now())
    where id = v_org.id;

    -- Expire the active token
    update public.serial_tokens
    set status = 'expired', updated_at = timezone('utc', now())
    where organization_id = v_org.id and status = 'active';

    -- Restrict all employees under this organization
    update public.employees
    set status = 'inactive', updated_at = timezone('utc', now())
    where company_id = v_org.id and status = 'active';

    -- Audit log (system action: no actor profile, FK-safe NULL)
    insert into public.audit_logs (
      actor_user_id, actor_email, actor_platform_role,
      action_type, target_type, target_id, target_name,
      organization_id, organization_name, organization_type,
      description
    ) values (
      null, 'system@minerlink.app', 'system',
      'TOKEN_EXPIRED', 'organization', v_org.id::text, v_org.company_name,
      v_org.id, v_org.company_name, v_org.org_type,
      format('Token expired for %s %s. All users restricted.', v_org.org_type, v_org.company_name)
    );
  end loop;
end;
$function$;

-- 3. Renew tokens that expired while the cron was broken (still-active orgs only).
with stale as (
  select id from public.companies
  where status = 'active'
    and token_expires_at is not null
    and token_expires_at <= timezone('utc', now())
)
update public.serial_tokens st
set expires_at = timezone('utc', now()) + interval '365 days',
    updated_at = timezone('utc', now())
from stale
where st.organization_id = stale.id and st.status = 'active';

update public.companies c
set token_expires_at = timezone('utc', now()) + interval '365 days',
    updated_at = timezone('utc', now())
where c.status = 'active'
  and c.token_expires_at is not null
  and c.token_expires_at <= timezone('utc', now());

commit;
