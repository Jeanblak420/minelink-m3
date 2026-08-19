-- The remaining `exception when others then null` handlers.
--
-- A sweep of `pg_proc` after 20260817280000 found four functions in `public`
-- swallowing exceptions with a bare `null`. That migration dealt with the
-- worst, `link_and_dispatch_request`, where the handler wrongly covered the
-- stockpile as well. These three are different: each one wraps a **single**
-- notification call and nothing else, so the scope is already right. Only the
-- silence is wrong.
--
--   assign_route_to_company        "New available route" to the company
--   decide_driver_limit_request    the approve/decline notice to the fleet
--   record_truck_load              "ready for gate check-out" to Security
--
-- The last one is not cosmetic. That notification is how a loaded truck gets
-- released from the mine: Security is told the weighbridge is finished with it.
-- If the call fails, the load is recorded correctly, the tonnage is right, the
-- waybill prints — and the truck sits at the gate while nobody is told to check
-- it out. There would be no exception, no log line, and nothing to look for
-- afterwards. A driver waiting at a boom is a very expensive way to discover a
-- swallowed error.
--
-- Keeping the handler is right — a notification must not be able to fail a
-- weighbridge entry. Keeping it silent is not. Each becomes a `raise warning`
-- naming the function, SQLERRM and SQLSTATE, which lands in postgres_logs
-- (`log_min_messages = warning` on this project, verified) and is greppable.
-- Verified end-to-end on 20260817280000: a deliberately broken notification
-- produced
--
--     link_and_dispatch_request(006a6c7d-...): the dispatch stands, but its
--     notifications failed: simulated notification failure (P0001)
--
-- in postgres_logs, where the previous `null` had produced nothing at all.
--
-- HOW: bodies rewritten from `pg_get_functiondef`, never retyped. Every
-- function must actually change or the migration raises.

do $migrate$
declare
  v_fn text;
  v_sig text;
  v_src text;
  v_new text;
  v_left int;
begin
  for v_fn, v_sig in
    select p.proname, pg_get_function_identity_arguments(p.oid)
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname in ('assign_route_to_company', 'decide_driver_limit_request',
                        'record_truck_load')
    order by p.proname
  loop
    select pg_get_functiondef(p.oid) into v_src
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public' and p.proname = v_fn
      and pg_get_function_identity_arguments(p.oid) = v_sig;

    -- Whitespace differs between these three (one is on a single line), so
    -- match the shape rather than an exact string.
    v_new := regexp_replace(
      v_src,
      'exception\s+when\s+others\s+then\s*null\s*;',
      format(
        'exception when others then raise warning ''%s: a notification failed; '
        'the action itself stands: %% (%%)'', sqlerrm, sqlstate;',
        v_fn),
      'g');

    if v_new = v_src then
      raise exception '%(%): expected a silent handler, found none', v_fn, v_sig;
    end if;
    execute v_new;
    raise notice 'no longer silent: %(%)', v_fn, v_sig;
  end loop;

  -- Nothing in the schema may swallow an exception without saying so.
  select count(*) into v_left
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and p.prosrc ~* 'exception[[:space:]]+when[[:space:]]+others[[:space:]]+then[[:space:]]*null[[:space:]]*;';
  if v_left <> 0 then
    raise exception 'still % function(s) swallowing exceptions silently', v_left;
  end if;
  raise notice 'no function in public swallows an exception without a trace';
end
$migrate$;
