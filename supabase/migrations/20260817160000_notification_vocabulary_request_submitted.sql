-- Vocabulary addition: `request_submitted`.
--
-- Raised by `notify_admins_of_request` (20260817150000) to every platform
-- admin when a request is submitted, and again when a sent-back request is
-- resubmitted.
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
    'request_submitted',   -- ADDED: notify_admins_of_request, the first
                           -- hand-off in the whole flow and the last one to
                           -- be silent
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
