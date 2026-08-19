-- Three notification types are raised by live RPCs and REJECTED by the CHECK
-- constraint that governs `notifications.type`. The most important action in
-- the product currently delivers no notifications at all.
--
-- HOW THIS WAS FOUND
-- ------------------
-- While adding `security_check_out` (S6-9/S6-24) I invented the type
-- `truck_left_mine`, wrapped the notify in `exception when others then null`
-- as every other call site does, and the check-out passed its walk. Counting
-- `truck_left_mine` rows before and after showed **0 -> 0**. The swallow had
-- hidden a `23514 notifications_type_check` violation.
--
-- Checking whether any EXISTING call had the same problem found two:
--
--   order_assigned    raised by link_and_dispatch_request (transporter)
--   order_dispatched  raised by link_and_dispatch_request (buyer)
--   stockpile_ready   raised by stockpile_add_tons
--
-- `order_dispatched` was MISSED on the first pass. The audit regex required the
-- type literal and the org literal to be adjacent, and it under-reported. The
-- second pass extracted every `'<token>', '<orgType>'` pair from every function
-- body in the schema and diffed against the constraint's own array, which is
-- how the fourth one surfaced. An audit that cannot be re-derived from the
-- constraint itself is an audit that will drift again.
--
-- Neither is in the constraint's list. Both are documented in CLAUDE.md §4 as
-- 🟢 Built.
--
-- WHAT IT COSTS, MEASURED
-- -----------------------
-- `link_and_dispatch_request` is supposed to fire three notifications: the
-- mine supervisor's "New stockpile to prepare", the transporter's "New order
-- assigned" and the buyer's "Order accepted & dispatched". Called on a real
-- request in a rolled-back transaction, it **SUCCEEDED and produced zero
-- notifications** — the whole `notifications` table went 467 -> 467. The
-- function has a handler around that section, so the first bad type aborts the
-- block and the two good notifications either side of it are lost with it.
-- Dispatch is the action that creates every trip; the mine learns of no
-- stockpile to build, the transporter of no order, the buyer of nothing.
--
-- It has never been seen because it has never run. The surviving
-- `stockpile_prepare` rows are dated 2026-07-12..14 and the last dispatch is
-- 2026-07-14, while the migration that introduced `order_assigned`
-- (`20260715090000`) landed on 2026-07-15. Every dispatch that ever notified
-- predates the bug, and none has run since. The rolled-back call above is the
-- first exercise of the current function.
--
-- `stockpile_ready` — the "+30 t, a full trailer is ready to collect" alert
-- that CLAUDE.md describes as how "a driver is never sent to sit and wait" —
-- is equally dead, though it has not yet cost anything: both live additions
-- crossed a 30 t multiple but neither pile is an order pile, so
-- `stockpile_add_tons` correctly skipped the alert on its own condition. It
-- would have failed the moment it did fire.
--
-- THE FIX, AND WHY IT IS THE CONSTRAINT AND NOT THE CALLERS
-- --------------------------------------------------------
-- The constraint is the notification vocabulary. These three types are the
-- intended vocabulary — they are what the shipped RPCs raise and what the
-- client already switches on. Renaming the calls to squeeze into the old list
-- would make the audit trail lie about what happened.
--
-- Kept as a CHECK rather than dropped: it is the only thing that would catch a
-- typo in a type string, and a typo is invisible at every call site because
-- they all swallow.
--
-- A FIFTH, FOUND BY THE TOOL WRITTEN FOR THIS, AND THE WORST OF THEM
-- ------------------------------------------------------------------
-- `tool/notification_vocabulary_check.py` diffs every type raised in
-- `supabase/migrations/*.sql` against this array. Its first run surfaced one
-- the manual audits had missed: **`target_cycle_closed`**, raised by
-- `close_due_target_cycles_job`.
--
-- It is latent — 0 of 4 target cycles have closed, so the notify has never
-- been reached, even though the `close-due-target-cycles` pg_cron job has run
-- 7 times. But it is the most dangerous of the five, because unlike every
-- other notify call in this schema **it is not wrapped in an exception
-- handler**: `position('exception when' in prosrc)` on that function is `0`.
--
-- So on the first anniversary of any cycle the job would close it, raise
-- `23514` on the notification, and abort **unhandled** — rolling back the
-- close, and taking every other scope's close in the same run with it. That is
-- exactly the failure CLAUDE.md §4 already warns about in the neighbouring
-- design note: *"one stuck cycle would freeze the nightly close for every
-- other scope."* The doc anticipated the shape; this was a live instance of it
-- waiting for a date.
--
-- The other four lose a notification. This one would have lost the close.

alter table public.notifications
  drop constraint if exists notifications_type_check;

alter table public.notifications
  add constraint notifications_type_check check (type = any (array[
    -- people and access
    'employeeRequest', 'roleAssigned', 'requestDeclined', 'roleConfirmation',
    'profileUpdate', 'userManagement',
    'dismissalInitiated', 'dismissalAppeal', 'dismissalFinal',
    -- role-scoped action feeds
    'securityAlert', 'controllerAction', 'adminAction', 'managementAction',
    -- fleet
    'fleetVehicleAdded', 'fleetDriverAssigned', 'fleetDriverUnassigned',
    'fleetVehicleStatusChanged',
    -- tokens and seats
    'tokenExpiringSoon', 'tokenRequestCreated', 'tokenRequestClaimed',
    'tokenRequestReleased', 'tokenRequestHandled',
    -- the order and haul lifecycle
    'stockpile_prepare',
    'order_assigned',    -- ADDED: link_and_dispatch_request, rejected until now
    'order_dispatched',  -- ADDED: the BUYER half of the same dispatch
    'stockpile_ready',   -- ADDED: stockpile_add_tons +30t, rejected until now
    'truck_checked_in',
    'truck_loaded',
    'truck_left_mine',   -- ADDED: security_check_out (S6-9/S6-24)
    'stockpile_depleted',
    'recon_dispute',
    -- targets
    'target_cycle_closed', -- ADDED: close_due_target_cycles_job, and the most
                           -- dangerous of the five, see below
    -- catch-all
    'general'
  ]));

comment on constraint notifications_type_check on public.notifications is
  'The notification vocabulary. Every value here must be raised by something, '
  'and everything raised must be here — a type outside this list is rejected '
  'with 23514, and because every notify call site swallows its exception, the '
  'notification simply never arrives and nothing reports it. That is how '
  'order_assigned and stockpile_ready sat dead from 2026-07-15 to 2026-08-15.';
