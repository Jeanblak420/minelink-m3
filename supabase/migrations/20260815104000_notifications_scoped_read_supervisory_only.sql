-- Follow-up to 20260815103000, fixing an over-grant that migration introduced.
--
-- That migration gave every role a company-scoped read keyed on its own role
-- name, so a driver's scope list `['driver']` matched EVERY driver-scoped
-- notification in the company — not just their own. Walked: a driver at
-- Roadhaul went from **3 rows addressed to them to 15**, 12 of which were
-- other people's.
--
-- The mistake was mechanical translation. In Dart the list was applied as a
-- filter on rows already narrowed by `user_id = me`, so self-scoping came free
-- from the address. Lifted into a company-wide read, `['driver']` stops
-- meaning "mine" and starts meaning "every driver's".
--
-- The scoped read exists for SUPERVISION — "management sees everyone below
-- them". Nobody below management gains anything, and their behaviour is
-- unchanged: they see exactly what they are addressed, as before.
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
    -- Admin sees everything below management, but not management-only traffic.
    when 'admin' then array['admin','controllerWB','supervisorForeman',
                            'security','driver']
    -- Everyone else: NO company-scoped read. Empty, not [p_role] — see above.
    else array[]::text[]
  end;
$function$;

comment on function public.notification_scopes_for_role(text) is
  'Which OTHER people''s notification scopes a role may read within its own '
  'company. Empty for every non-supervisory role: the scoped read exists for '
  'supervision, and a self-scope here would mean "every driver''s", not '
  '"mine". Rows addressed to you are always readable regardless.';

-- A company-wide notice (null scope) is only broadcast to those who already
-- have a company-scoped read; for everyone else it still arrives by being
-- addressed to them, exactly as before this change.
create or replace function public.can_read_notification_scope(
  p_role text, p_scope text)
returns boolean
language sql
immutable
as $function$
  select cardinality(public.notification_scopes_for_role(p_role)) > 0
     and (p_scope is null
          or p_scope = any (public.notification_scopes_for_role(p_role)));
$function$;

comment on function public.can_read_notification_scope(text, text) is
  'Whether a role may read ANOTHER person''s notification carrying p_scope, '
  'within its own company. False for every non-supervisory role. Null handled '
  'explicitly because `scope = any(array)` is NULL — not false — when scope is '
  'null, and a NULL predicate silently admits nothing.';

-- Verified on production, rolled back. Inbox size, own rows -> total (others):
--   driver       3 -> 3   (0 others)   unchanged, as intended
--   management  10 -> 17  (7 others)
--   admin       10 -> 17  (7 others)
-- Predicate matrix:
--   admin sees management            false
--   management sees management       true
--   admin sees driver                true
--   driver sees other drivers        false
--   driver sees company-wide         false
--   security sees other security     false
-- Cross-company isolation: management's inbox spans exactly 1 company, with
-- 0 rows from any other.
