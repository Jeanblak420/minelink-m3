# Fleet Maintenance & Downtime — design (2026-07-17)

Turns the Transporter "Maintenance" coming-soon placeholder
(`transporter_maintenance_screen.dart`) into the real module. Approved by the
user 2026-07-17: maintenance blocks route assignment (with a guaranteed path
back to Available), scope includes BOTH maintenance/downtime records AND
recurring service schedules with due reminders, and fleet managers
(owner + admin + management) write while all company staff read.

## Approach — derived state, single source of truth

"In maintenance" is **derived** from the existence of an open maintenance
record with `takes_out_of_service = true` — the same pattern as On-Route being
derived from active trips. Closing the record is the ONLY thing needed to
return the truck to Available; there is no separate status flag that can go
stale. Fleet states become: **Available ↔ On Route ↔ In Maintenance**.

## Database (migration `20260717120000_fleet_maintenance.sql`)

### Tables

`fleet_maintenance_records`
- `id uuid pk`, `company_id → companies`, `vehicle_id → fleet_vehicles`
- `kind text` check in `service | repair | breakdown | inspection`
- `title text` (required), `notes text`
- `status text` check in `open | closed` (wire strings; Dart parses tolerantly)
- `takes_out_of_service boolean not null default true` — only these block
  assignment; minor logbook entries can be recorded without downtime
- `started_at timestamptz default now()`, `expected_back_at timestamptz null`,
  `closed_at timestamptz null`
- `cost_zar numeric null`, `odometer_km integer null`
- `created_by`, `closed_by`, `created_at`, `updated_at`
- Indexes: `(company_id, status)`, `(vehicle_id, status)`

`fleet_service_schedules`
- `id`, `company_id`, `vehicle_id`, `name text` (e.g. "Minor service")
- `due_date date null`, `due_odometer_km integer null` (at least one required)
- `repeat_months integer null`, `repeat_km integer null` — on completion the
  schedule rolls forward by these; null = one-off (deactivates on completion)
- `notify_days_before integer not null default 7`
- `active boolean not null default true`
- `last_done_at timestamptz null`, `last_notified_at timestamptz null`
- `created_by`, timestamps. Index `(company_id, active)`.

### Availability integration
- `list_transporter_fleet_status` gains `in_maintenance boolean` +
  `maintenance_title text` (open out-of-service record exists). A vehicle is
  assignable only when active ∧ not on-route ∧ not in-maintenance.
- **Server-side guard:** `accept_request_dispatch` rejects any selected truck
  that has an open out-of-service record (raise exception naming the truck) —
  the UI filter alone is not the security boundary.

### RPCs (SECURITY DEFINER, pinned `search_path = public`, EXECUTE revoked
from PUBLIC/anon, granted to `authenticated`; every function checks
`can_manage_fleet(company_id)` for writes)
- `open_maintenance_record(vehicle, kind, title, notes, takes_out_of_service,
  expected_back_at, cost, odometer)` → id. Notifies company management
  ("Vehicle down for maintenance" — only when out-of-service).
- `close_maintenance_record(record_id, notes?, cost?, odometer?)` — sets
  closed/closed_at/closed_by. Truck is instantly Available again (derived).
  Notifies management ("back in service") when it was out-of-service.
- `list_fleet_maintenance(company_id)` → jsonb {records, schedules,
  vehicle summaries} for the screen (staff-readable).
- `upsert_service_schedule(...)` / `set_service_schedule_active(id, active)`.
- `complete_service_schedule(id, cost?, odometer?, notes?)` — creates a closed
  `service` maintenance record (the log entry) and rolls the schedule forward
  (due_date += repeat_months / due_odometer_km += repeat_km, stamps
  last_done_at, clears last_notified_at); deactivates if no repeat.

### Reminders (pg_cron daily)
`notify_service_due_job()` — for active schedules where
`due_date - notify_days_before <= today` OR
`vehicle.odometer_km >= due_odometer_km - 500`, and `last_notified_at` is null
or > 6 days old: notify fleet managers, stamp `last_notified_at`. Scheduled
daily via pg_cron alongside the existing jobs.

### RLS / realtime
- RLS on both tables: SELECT for `is_company_staff(company_id)` (+ platform
  admin); INSERT/UPDATE/DELETE `with check (false)` — mutations only via the
  RPCs (matches the stockpile pattern).
- Both tables added to `supabase_realtime`.

## Flutter

- `lib/features/fleet/models/maintenance_record.dart`,
  `service_schedule.dart` — wire enums (`MaintenanceKind`,
  `MaintenanceStatus`) with tolerant `parse()` per house pattern.
- `lib/features/fleet/services/maintenance_service.dart` — the only DB access;
  typed methods over the RPCs.
- `lib/features/fleet/providers/maintenance_providers.dart` — company-scoped
  FutureProvider + realtime-refresh.
- `transporter_maintenance_screen.dart` rebuilt: stat cards (In maintenance /
  Open records / Due soon), open-records list with vehicle chip, kind pill
  (`MlTone.warn` amber), expected-back date, and a prominent
  **"Mark fixed — return to service"** action; service-schedules section with
  add/edit dialog + "Log service done"; collapsed closed-history list.
  All colours via `MlTokens`/`MlSemantic`/`MlTone` (maintenance = `warn`).
- `FleetVehicleStatus` gains `inMaintenance` (+ label); `available` getter
  becomes `isActive && !onRoute && !inMaintenance`. Fleet screens show an
  amber IN MAINTENANCE chip; the dispatch truck picker already offers only
  `available` trucks so it excludes them automatically.

## Testing & verification
- Unit: enum parse tolerance; schedule roll-forward math (pure function).
- `flutter analyze` + full suite stay green.
- Live drive as Roadhaul owner: open a breakdown on the idle truck → it
  leaves Available (and the truck picker); close it → Available again and
  assignable. Schedule created → shows Due soon when due date is near.
- CLAUDE.md status row flips 🔴 → 🟢 only after the live drive passes.
