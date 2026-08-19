-- S8-7 / P10-13. Client ruling 2026-08-15: the scoped read path.
--
-- The hierarchy — "companies see all users' actions, management sees everyone
-- below them" — was never a read rule. It was a NARROWING FILTER on rows you
-- had already been sent, so it only worked where the sender happened to write
-- a copy for you. Measured across production:
--
--   fleetVehicleStatusChanged   always 3 recipients
--   fleetDriverAssigned         1 – 3
--   truck_checked_in            1 – 1
--   truck_loaded                1 – 1
--
-- truck_checked_in and truck_loaded are core lifecycle events and reach
-- exactly one person, so management never sees them — not because a filter
-- hides them, but because no copy exists. No read-side filter can fix that.
--
-- Fan-out was rejected in favour of this: a copy written per recipient never
-- back-fills, so somebody promoted today would still not see yesterday's
-- events, and the table would grow with the org chart.
--
-- NOTE: the scope lists below were WRONG in this file — every role got a
-- company-scoped read keyed on its own name, so a driver could read every
-- driver's notifications. Corrected in 20260815104000, which is kept separate
-- because the mistake is the instructive part.
create or replace function public.notification_scopes_for_role(p_role text)
returns text[]
language sql
immutable
as $function$
  select case p_role
    when 'owner' then array['management','admin','controllerWB',
                            'supervisorForeman','security','driver']
    when 'management' then array['management','admin','controllerWB',
                                 'supervisorForeman','security','driver']
    when 'admin' then array['admin','controllerWB','supervisorForeman',
                            'security','driver']
    else array[p_role]
  end;
$function$;

-- Null handling is explicit rather than an array member, because
-- `role_scope = any(array[...])` is NULL — not false — when role_scope is
-- null, and a NULL predicate silently admits nothing.
create or replace function public.can_read_notification_scope(
  p_role text, p_scope text)
returns boolean
language sql
immutable
as $function$
  select p_scope is null
      or p_scope = any (public.notification_scopes_for_role(p_role));
$function$;

-- Widen the read. Own rows exactly as before, PLUS rows for your own company
-- whose role_scope your role is entitled to. Scoped to current_company_id(),
-- so this can never reach another company's notifications.
drop policy if exists notifications_select_own on public.notifications;
create policy notifications_select_own
  on public.notifications for select to authenticated
  using (
    user_id = (select auth.uid())
    or (
      company_id is not null
      and company_id = (select public.current_company_id())
      and public.can_read_notification_scope(
            public.chat_role_of((select auth.uid())), role_scope)
    )
  );

-- One row per EVENT, not per copy.
--
-- Widening the read alone would show management three identical rows for an
-- event fanned out to three people. Copies of one event share their company,
-- type, title, message and second, because they are written in one loop at one
-- call site — that is the dedupe key. The row addressed to the caller wins, so
-- `is_read` stays theirs; otherwise the earliest copy stands in, and its
-- is_read is reported false, because somebody else's copy is not evidence that
-- YOU read it.
create or replace function public.list_my_notifications(p_limit int default 200)
returns table(
  id uuid, user_id uuid, company_id uuid, employee_id uuid,
  title text, message text, type text, is_read boolean,
  created_at timestamptz, actioned_by text, actioned_by_id uuid,
  role_scope text, org_type text, importance text, metadata jsonb,
  is_own boolean
)
language sql
stable security definer
set search_path to 'public'
as $function$
  with visible as (
    select n.*,
           (n.user_id = auth.uid()) as own,
           row_number() over (
             partition by n.company_id, n.type, n.title, n.message,
                          date_trunc('second', n.created_at)
             order by (n.user_id = auth.uid()) desc, n.created_at asc
           ) as rn
    from public.notifications n
    where n.user_id = auth.uid()
       or (
         n.company_id is not null
         and n.company_id = public.current_company_id()
         and public.can_read_notification_scope(
               public.chat_role_of(auth.uid()), n.role_scope)
       )
  )
  select v.id, v.user_id, v.company_id, v.employee_id,
         v.title, v.message, v.type,
         case when v.own then v.is_read else false end,
         v.created_at, v.actioned_by, v.actioned_by_id,
         v.role_scope, v.org_type, v.importance, v.metadata,
         v.own
  from visible v
  where v.rn = 1
  order by v.created_at desc
  limit p_limit;
$function$;

comment on function public.list_my_notifications(int) is
  'The caller''s inbox: rows addressed to them, plus rows their role is '
  'entitled to within their own company (P10-13 scoped read). Deduplicated to '
  'one row per event, preferring the copy addressed to the caller so is_read '
  'stays theirs.';

grant execute on function public.list_my_notifications(int) to authenticated;
