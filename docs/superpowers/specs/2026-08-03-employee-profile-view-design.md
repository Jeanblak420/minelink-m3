# Employee profile detail view — design (2026-08-03)

## Goal

Clicking a person in the Employee Register (org portals + super-admin mirror) opens a
full-screen live profile matching the approved mockups (design ref:
`docs/new system design/minelink-new-design-v0.1/templates/shared/employee-register.jsx`
→ `FullProfile`, plus the 9 approved screenshots). One screen serves every role and
org type; the role decides which productivity metrics, activity sources, badges and
posting labels render. **Every number is real** (repo rule: register renders REAL data
only) and the screen is genuinely realtime — Supabase `postgres_changes` + the
`online-users` presence channel drive live updates, UI ticks refresh relative stamps.

## Role → presentation map (code roles only; no schema change)

| Org | Code role | Mock persona | Metrics (all live queries) |
|---|---|---|---|
| transporter | admin | Anna (Admin) | approvals actioned (notifications), seats used (companies), 30-day sign-ins (profiles) |
| transporter | management | Riaan (Fleet Controller) | trucks managed (fleet_vehicles), dispatched today (trips), in service now (trips) |
| transporter | driver | Thabo (Driver) | trips this month (driver_assignments→trips), POD rate (pod_uploads), km today (vehicle_positions haversine) |
| buyer | admin | Eli (Admin) | same as admin above |
| buyer | management | Sarah (Procurement) | requests raised (transportation_requests), recons closed / open (recon_disputes) |
| mine | admin / management | Nadia (Admin) | same as admin above |
| mine | supervisorForeman | Vusi (Supervisor) | crew online now (presence), stockpile sign-offs today (stockpile_transactions), incidents today (security_incidents) |
| mine | controllerWB | Ben (Load Controller) | loads logged (weighbridge_records by recorded_by), avg tons/load, gate rejects today (gate_checks) |
| mine | security | Happy (Security Guard) | gate checks by me (gate_checks.checked_by), trucks cleared today, flags raised (security_incidents.reported_by) |

Sparklines = real daily counts over the trailing 7 days for the metric's base table.
No data → muted dash, never an invented number.

## Sections (per mock, all real-backed)

- **Header**: back/breadcrumb (`COMPANY / EMPLOYEE REGISTER / NAME`), live "Synced Xs
  ago" pill (10s ticker), prev/next through the same register ordering, close.
- **Identity hero**: avatar (resolved signed URL) + presence dot
  (`onlineUsersProvider` + `profiles.last_seen_at` away window, same rules as the
  super-admin register), serif name (italic surname), role chip, derived emp-code
  (`ADM-XXXX` pattern already in the register), Managed/Read-only pill, presence row
  with live last-ping. Actions: **Message** (getOrCreateDm → ChatDock open request, or
  `/chat/:id` when not under a portal shell), call (`tel:`), WhatsApp (`wa.me`),
  radio → org group chat (`createOrgGroup`).
- **Contact & identity**: emp code, role, email (real `profiles.email`; a synthetic
  WhatsApp-login email renders as the mock's green "WhatsApp-only account" note
  instead), WhatsApp, ID number. Tap-to-copy on every row.
- **Documents**: legacy `employees.*_document_url` slots + `compliance_documents`
  (owner_type=employee). View/Download = signed URLs via url_launcher. Status chips:
  Verified (uploaded), Expires Nmo / Expired (compliance `days_to_expiry`). Upload →
  compliance screen (managers only).
- **Today's shift**: standard 05:00→17:00 window, progress = wall clock, LIVE pill
  when online. Stats: shift progress, last activity (from the real feed), last ping.
- **Today's productivity**: 3 role metric tiles (serif value, delta vs yesterday,
  7-day area sparkline) per the table above.
- **Location & assignment**: mine → `mine_locations` (name + lat/lng);
  driver → latest `vehicle_positions` fix for their assigned vehicle; others → head
  office (company name). ON-SITE badge = online. Stylized zone canvas exactly like the
  mock (dashed ellipse + marker) with the real coordinates printed. Reporting
  supervisor = first active supervisor/admin of the company (admins → "Board /
  Directors"); tapping opens their profile; online dot live.
- **Activity · last 24h**: merged, capped feed from `profiles.last_login_at`,
  `gate_checks`, `weighbridge_records`, `stockpile_transactions`, `pod_uploads`,
  driver trip timestamps, `notifications` (actioned_by_id), `recon_disputes`,
  `transportation_requests`, presence "Online · now". Every entry deep-links to its
  operational screen. "View full log →" → notifications.
- **Role snapshot**: tenure (created_at), posting, last sign-in, permissions scope;
  real badges (docs verified, today's counts, System owner when
  `companies.company_admin_user_id == user`).
- **Notes & flags**: derived live flags — expiring/expired compliance docs (amber/red,
  with real day counts), dismissal/appeal state; else green "No open flags".
  "Add note or flag" → compliance screen (managers).
- **Footer**: live line + **Export profile PDF** (real PDF via `pdf`/`printing`).

## Architecture

- `lib/features/employee/services/employee_profile_service.dart` — all queries
  (CLAUDE.md §6), each block best-effort try/catch so a failed source drops that card,
  never the screen.
- `lib/features/employee/providers/employee_profile_provider.dart` — bundle/metrics/
  activity/docs/flags FutureProviders (family, autoDispose) + a realtime provider that
  opens filtered `postgres_changes` channels (employees row, profiles row,
  company-filtered activity tables) and debounce-invalidates the read providers.
- `lib/features/employee/screens/employee_profile_screen.dart` — the screen, built on
  `MlSemantic`/`MlTokens` (matches mock in dark; adapts in light). Self-contained
  painters: area sparkline, zone map.
- Routes: `/portal/{mine,buyer,transporter}/employees/:employeeId` (inside portal
  shell). Register row tap → profile; the row's management section stays reachable via
  the row's trailing manage toggle. Super-admin `_MemberCard` tap → same screen
  read-only via `MaterialPageRoute`.
- ChatDock: new `dockOpenRequestProvider` nonce; dock listens and morphs open; panel
  listens to `activeRoomProvider` to jump into the thread.
- Migration (live + committed): add `pod_uploads`, `stockpile_transactions`,
  `compliance_documents`, `recon_disputes`, `driver_assignments`,
  `transportation_requests`, `request_dispatches` to the `supabase_realtime`
  publication so every profile source emits realtime events (RLS still filters per
  subscriber via WALRUS).

## Error handling & testing

Every data block independent + best-effort; presence falls back to DB heartbeat; docs
resolve lazily. Verify with `flutter analyze` (must stay 0) and the full test suite
(268 green baseline); manual click-through of all three portals.
