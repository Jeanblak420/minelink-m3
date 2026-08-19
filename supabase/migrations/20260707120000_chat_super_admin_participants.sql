-- ============================================================================
-- Allow the Super Global Admin to chat with any contact.
--
-- are_chat_participants_allowed() (the WITH CHECK on chat_rooms INSERT and the
-- USING on chat_rooms SELECT) previously required the caller to belong to a
-- company AND every room participant to be in that same company. The super
-- global admin has no company, so it could neither create nor see any room —
-- and even normal users could not open a DM that included the admin (the admin
-- is in no company, so the per-participant company check failed).
--
-- This recreates the guard so that:
--   * a super global admin may create/see any room they are a participant of;
--   * super-admin participants are always "chattable" by anyone, so a normal
--     user's DM with the admin passes the per-participant check too.
-- Ordinary company↔company scoping is otherwise unchanged.
-- ============================================================================
create or replace function public.are_chat_participants_allowed(
  target_participant_ids uuid[]
)
returns boolean
language plpgsql
stable
security definer
set search_path to 'public'
as $function$
declare
  base_company_id uuid;
  participant_id uuid;
begin
  if auth.uid() is null then
    return false;
  end if;

  if target_participant_ids is null
     or array_length(target_participant_ids, 1) is null then
    return false;
  end if;

  -- The caller must be one of the participants.
  if not auth.uid() = any (target_participant_ids) then
    return false;
  end if;

  -- Super global admin may chat with anyone (they belong to no company).
  if public.chat_is_super_admin(auth.uid()) then
    return true;
  end if;

  base_company_id := public.current_company_id();
  if base_company_id is null then
    return false;
  end if;

  foreach participant_id in array target_participant_ids
  loop
    -- Super admins are chattable by anyone, regardless of company.
    if public.chat_is_super_admin(participant_id) then
      continue;
    end if;

    if not exists (
      select 1
      from public.companies c
      where c.id = base_company_id
        and c.user_id = participant_id
      union all
      select 1
      from public.employees e
      where e.company_id = base_company_id
        and e.user_id = participant_id
        and e.status = 'active'
        and e.is_dismissed = false
    ) then
      return false;
    end if;
  end loop;

  return true;
end;
$function$;
