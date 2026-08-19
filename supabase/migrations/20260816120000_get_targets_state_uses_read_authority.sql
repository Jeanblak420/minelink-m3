-- Point `get_targets_state` at the READ authority added by
-- `20260816110000_targets_company_self_read.sql`. One line changes; nothing
-- else about the function does.
--
-- This is done as a targeted substitution on `pg_get_functiondef` rather than
-- by pasting the 150-line body back in. CLAUDE.md §6 records that retyping a
-- body into `apply_migration` is how the ledger and the files silently drift —
-- on the previous targets migrations that check found 5 of 15 function bodies
-- differing from their file. A substitution cannot drift, and the anchor
-- assertion below makes a failed match loud instead of a no-op.
do $do$
declare
  v_def text;
  v_from constant text :=
    'perform public.assert_target_scope(p_scope, p_org_type, p_company_id);';
  v_to constant text :=
    'perform public.assert_target_scope_read(p_scope, p_org_type, p_company_id);';
begin
  select pg_get_functiondef(p.oid)
    into v_def
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.proname = 'get_targets_state';

  if v_def is null then
    raise exception 'get_targets_state not found';
  end if;

  if position(v_from in v_def) = 0 then
    raise exception
      'anchor not found in get_targets_state — refusing to replace it blind';
  end if;

  execute replace(v_def, v_from, v_to);
end
$do$;

comment on function public.get_targets_state(text, text, uuid, integer) is
  'Targets read. Super admin: every scope. A company: its own company scope, '
  'so its dashboard can show the target it is measured against. Writes are '
  'still super-admin-only (assert_target_scope).';
