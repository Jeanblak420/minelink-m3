-- Vocabulary addition: `truck_arrived_offload`.
--
-- Raised by `mark_trip_arrived_at_offload` (20260817130000) to the buyer's
-- admin/management and the transporter's, when the driver reports arriving at
-- the offload point.
--
-- WHY A NEW FILE AND NOT AN EDIT TO 20260815109000
-- ------------------------------------------------
-- MIGRATION_HYGIENE / CLAUDE.md §6: one file per applied migration, and never
-- fold a later change into an earlier file — the ledger and the file list have
-- to agree, and an edited historical migration makes them lie about what ran
-- when. So the constraint is restated here in full, and this file is now the
-- one that owns the vocabulary.
--
-- `tool/notification_vocabulary_check.py` follows that: it takes the LATEST
-- migration that defines `notifications_type_check` rather than a hard-coded
-- filename, so adding a type keeps working without touching the tool. Its
-- whole purpose is that a type outside this list is rejected with 23514 into
-- an `exception when others then null` — the notification simply never
-- arrives and nothing anywhere complains.

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
    'order_assigned',
    'order_dispatched',
    'stockpile_ready',
    'truck_checked_in',
    'truck_loaded',
    'truck_left_mine',
    'truck_arrived_offload', -- ADDED: mark_trip_arrived_at_offload, the
                             -- driver's "I am here" to the buyer
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
