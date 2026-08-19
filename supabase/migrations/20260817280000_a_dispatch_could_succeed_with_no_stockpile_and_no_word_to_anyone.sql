-- `link_and_dispatch_request` swallowed the failure of the step the whole
-- order depends on.
--
-- The stockpile creation and every dispatch notification sat inside one block
-- ending `exception when others then null`. Not a warning, not a log line --
-- `null`. So if anything in that block raised, the function returned normally
-- and the admin was told the dispatch had succeeded.
--
-- MEASURED, on the live database, before changing anything. A trigger was
-- installed that made the `stockpiles` insert raise, a throwaway request was
-- dispatched, and the whole probe then rolled itself back:
--
--     the call SUCCEEDED.
--       request.status = linked
--       routes         = 1
--       dispatches     = 1
--       stockpiles     = 0
--       notifications  = 0
--
-- Read that as an operator would. The request is marked dispatched. The route
-- exists. The transporter has the order and will send trucks. But no stockpile
-- was created, so there is nothing for the supervisor to fill and nothing for
-- the buyer or transporter to read a fill level from -- and *nobody was told
-- anything at all*: not the mine's supervisor, not the transporter, not the
-- buyer. CLAUDE.md §4 calls the auto-created stockpile the point where "the
-- whole flow starts". It could silently not start.
--
-- It would also be invisible afterwards. No exception, no warning, nothing in
-- postgres_logs. The only symptom is a supervisor who never gets a "New
-- stockpile to prepare" notice, months later, for one order.
--
-- THE FIX IS NOT "REMOVE THE HANDLER". There is a real reason for one: a
-- notification failure should not be able to block a dispatch. A bad role
-- string or a missing vocabulary entry is a nuisance; refusing to dispatch the
-- load because of it is worse. That reasoning applies to the notifications and
-- was wrongly extended over the stockpile, which is not incidental to the
-- order -- it IS the order.
--
-- So the protection is moved rather than deleted:
--
--   * The stockpile create/update is now unprotected. If it fails, the whole
--     function fails, the transaction rolls back, and the admin sees the
--     error and retries. A dispatch either happens completely or not at all.
--   * The notifications keep a handler, but it `raise warning`s with the
--     request id, SQLERRM and SQLSTATE, so a swallowed failure is greppable in
--     postgres_logs instead of being erased.
--
-- HOW: the body is rewritten from `pg_get_functiondef` rather than retyped
-- (the pattern from 20260816120000), so nothing else in this 150-line function
-- can drift. Both anchors are asserted before either is applied.

do $migrate$
declare
  v_src text;
  v_new text;
  v_open constant text := E'\n    v_mine_msg := case\n';
  v_tail constant text := E'\n  exception when others then\n    null;\n  end;\n';
begin
  select pg_get_functiondef(p.oid) into v_src
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public' and p.proname = 'link_and_dispatch_request';
  if v_src is null then
    raise exception 'link_and_dispatch_request not found';
  end if;

  if position(v_open in v_src) = 0 then
    raise exception 'anchor 1 (start of the notification section) not found';
  end if;
  if position(v_tail in v_src) = 0 then
    raise exception 'anchor 2 (the swallowing handler) not found';
  end if;

  -- 1. Open a nested block immediately before the first notification, so the
  --    stockpile above it is no longer covered.
  v_new := replace(v_src, v_open, E'\n    -- Everything below is notification only. It is allowed to fail without\n    -- taking the dispatch with it -- but it says so, loudly, rather than\n    -- being erased (20260817280000).\n    begin\n    v_mine_msg := case\n');

  -- 2. Close that nested block with a handler that leaves a trace, and let the
  --    outer block (which now covers the stockpile) end without one.
  v_new := replace(v_new, v_tail, E'\n    exception when others then\n      raise warning ''link_and_dispatch_request(%): the dispatch stands, but its notifications failed: % (%)'', p_id, sqlerrm, sqlstate;\n    end;\n  end;\n');

  execute v_new;
  raise notice 'link_and_dispatch_request: stockpile failures now abort the dispatch; notification failures warn';
end
$migrate$;

comment on function public.link_and_dispatch_request(uuid, uuid, numeric, numeric, uuid[]) is
  'Links a request to a mine and transporter(s): mints the route, the margin '
  'ledger row, the dispatches and the order stockpile, then notifies the mine, '
  'the transporter and (only when one exists) the buyer. A stockpile failure '
  'aborts the whole dispatch -- it used to be swallowed, leaving a request '
  'marked linked with a route, a dispatched transporter, no stockpile and no '
  'notification to anyone (20260817280000). Notification failures are warned '
  'about, not swallowed.';
