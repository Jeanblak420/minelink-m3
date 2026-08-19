-- Vocabulary addition: `request_sent_back` and `request_approved`.
--
-- Raised by `notify_requester_of_review` (20260817220000) to the requesting
-- company when the platform admin sends a request back, approves it, or
-- declines it.
--
-- Session 2 gave the outbound hand-off a word (`request_submitted`,
-- 20260817160000). The return leg had none, and produced no notification at
-- all: measured 2026-08-17, the admin returned a buyer's product request with a
-- note and `notifications` gained **zero** rows. `requestDeclined` already
-- existed and is reused for declines; these two are the missing halves.
--
-- New file rather than an edit to the previous vocabulary migration, for the
-- reason recorded in 20260817140000: one file per applied migration, and the
-- check tool reads whichever migration most recently defines the constraint.

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
    'request_submitted',
    'request_sent_back',   -- ADDED: notify_requester_of_review — the admin has
                           -- asked for changes, and the note saying what they
                           -- are travels with it
    'request_approved',    -- ADDED: notify_requester_of_review
    'stockpile_prepare',
    'order_assigned',
    'order_dispatched',
    'stockpile_ready',
    'truck_checked_in',
    'truck_loaded',
    'truck_left_mine',
    'truck_arrived_offload',
    'stockpile_depleted',
    'recon_dispute',
    -- targets
    'target_cycle_closed',
    -- catch-all
    'general'
  ]));

comment on constraint notifications_type_check on public.notifications is
  'The notification vocabulary. Every value here must be raised by something, '
  'and everything raised must be here — a type outside this list is rejected '
  'with 23514, and because every notify call site swallows its exception, the '
  'notification simply never arrives and nothing reports it. That is how '
  'order_assigned and stockpile_ready sat dead from 2026-07-15 to 2026-08-15. '
  'Checked mechanically by tool/notification_vocabulary_check.py against the '
  'latest migration that defines this constraint.';
