-- Canonical request lifecycle (CLAUDE.md §4 — pre-trip request → approval → linking):
--   requested → sent_back → resubmitted → approved → linked   (+ terminal declined)
-- Applies to transportation_requests.status ONLY. request_dispatches.status is a
-- separate per-transporter state machine (dispatched/accepted/declined) and is
-- intentionally untouched.

------------------------------------------------------------------------------
-- 1. Backfill legacy wire values onto the canonical lifecycle.
------------------------------------------------------------------------------
update public.transportation_requests
  set status = 'requested' where status in ('submitted', 'under_review');
update public.transportation_requests
  set status = 'approved' where status = 'accepted';
update public.transportation_requests
  set status = 'linked' where status = 'dispatched';

------------------------------------------------------------------------------
-- 2. Constraint + default now speak canonical only.
------------------------------------------------------------------------------
alter table public.transportation_requests
  drop constraint if exists transportation_requests_status_check;
alter table public.transportation_requests
  add constraint transportation_requests_status_check
  check (status in ('requested','sent_back','resubmitted','approved','linked','declined'));
alter table public.transportation_requests
  alter column status set default 'requested';

------------------------------------------------------------------------------
-- 3. Review RPC — admin actions are now sent_back | approved | declined.
--    Legacy action names are translated so an out-of-date client never breaks
--    a row ('accepted' → 'approved'; 'under_review' → no-op back to requested).
------------------------------------------------------------------------------
create or replace function public.review_transportation_request(
  p_id uuid,
  p_action text,
  p_notes text default null
)
returns public.transportation_requests
language plpgsql security definer set search_path = public as $$
declare
  v_row public.transportation_requests;
  v_action text := p_action;
begin
  if not public.is_platform_admin() then
    raise exception 'Only the MineLink representative may review requests';
  end if;
  -- Tolerate legacy client action names.
  if v_action = 'accepted' then v_action := 'approved'; end if;
  if v_action = 'under_review' then v_action := 'requested'; end if;
  if v_action not in ('sent_back','approved','declined','requested') then
    raise exception 'Invalid review action %', v_action;
  end if;
  update public.transportation_requests set
    status = v_action,
    admin_notes = coalesce(p_notes, admin_notes),
    reviewed_by = auth.uid(),
    reviewed_at = timezone('utc', now())
  where id = p_id
  returning * into v_row;
  if not found then raise exception 'Request % not found', p_id; end if;
  return v_row;
end;
$$;

------------------------------------------------------------------------------
-- 4. Dispatch RPC — dispatching to transporter(s) is the "linking" step, so
--    the request lands on the canonical terminal 'linked' (was 'dispatched').
------------------------------------------------------------------------------
create or replace function public.dispatch_transportation_request(
  p_id uuid,
  p_transporter_ids uuid[]
)
returns public.transportation_requests
language plpgsql security definer set search_path = public as $$
declare
  v_row public.transportation_requests;
  v_tid uuid;
begin
  if not public.is_platform_admin() then
    raise exception 'Only the MineLink representative may dispatch requests';
  end if;
  if p_transporter_ids is null or array_length(p_transporter_ids, 1) is null then
    raise exception 'Select at least one transporter to dispatch to';
  end if;
  foreach v_tid in array p_transporter_ids loop
    insert into public.request_dispatches (request_id, transporter_company_id, dispatched_by)
    values (p_id, v_tid, auth.uid())
    on conflict (request_id, transporter_company_id) do nothing;
  end loop;
  update public.transportation_requests set
    status = 'linked',
    reviewed_by = auth.uid(),
    reviewed_at = timezone('utc', now())
  where id = p_id
  returning * into v_row;
  if not found then raise exception 'Request % not found', p_id; end if;
  return v_row;
end;
$$;
