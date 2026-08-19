-- Live end-to-end run exposed a silent bug: every server-side LIFECYCLE
-- notification was being rejected by two CHECK constraints and swallowed by the
-- best-effort `exception when others then null` wrappers, so none ever
-- delivered:
--   * notifications_type_check lacked the lifecycle types
--     (stockpile_prepare, truck_checked_in, truck_loaded, stockpile_depleted),
--   * notifications_role_scope_check lacked 'supervisorForeman'.
-- The driver-assignment notifications used already-allowed types, which is why
-- they worked and a static read of the code looked fine.
--
-- Extend both constraints to cover the roles and lifecycle types the code
-- actually emits (link_and_dispatch_request, set_trip_status,
-- record_truck_load).

begin;

alter table public.notifications drop constraint if exists notifications_role_scope_check;
alter table public.notifications
  add constraint notifications_role_scope_check
  check (role_scope = any (array[
    'security', 'controllerWB', 'supervisorForeman', 'admin', 'management', 'driver'
  ]));

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications
  add constraint notifications_type_check
  check (type = any (array[
    -- existing
    'employeeRequest', 'roleAssigned', 'requestDeclined', 'roleConfirmation',
    'profileUpdate', 'userManagement', 'securityAlert', 'controllerAction',
    'adminAction', 'managementAction', 'dismissalInitiated', 'dismissalAppeal',
    'dismissalFinal', 'fleetVehicleAdded', 'fleetDriverAssigned',
    'fleetDriverUnassigned', 'fleetVehicleStatusChanged', 'general',
    'tokenExpiringSoon', 'tokenRequestCreated', 'tokenRequestClaimed',
    'tokenRequestReleased', 'tokenRequestHandled',
    -- lifecycle (added)
    'stockpile_prepare', 'truck_checked_in', 'truck_loaded', 'stockpile_depleted'
  ]));

commit;
