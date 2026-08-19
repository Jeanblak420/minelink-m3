# Super Global Serial Admin — UI kit

Recreates the **Super Global Serial Admin** (`superGlobalSerialAdminMain`) console
described in the implementation guides: every company is linked here, with token
& seat-serial management and live expiry countdowns.

- `index.html` — interactive shell: Overview, Organizations, Tokens & Seats, Users, Requests. Clicking a company opens a detail slide-over.
- `screens.jsx`:
  - `AdminOverview` — global KPIs + org-type breakdown + recently-active table with **live token countdown**.
  - `AdminOrganizations` — searchable company table (org type, seats used/total, live expiry).
  - `CompanyPanel` — slide-over: live `days-hours-minutes-seconds` countdown, seat serial, seats-used vs anti-abuse reassign limit, linked users with role-bound seat suffixes, and a **Generate seat serial** modal (last 3 chars bind to role type).
  - `AdminRequests` — **incoming transportation-requests inbox**: status filter tabs (All / New / Under review / Sent back / Accepted), each row showing request ID, buyer, route, commodity, tonnage & slots, status pill and time received.
  - `RequestPanel` — request review slide-over mirroring the buyer's submission (route timeline, load & commercials, schedule, buyer notes) with representative actions per the codebase lifecycle (`RequestStatus`): **Accept & match to a supplier mine → dispatch**, **Send back** (with note; buyer may then edit & resubmit), **Decline** (with reason).

Source: `Task-list-for=Super_Global_Serial-Admin…md`, `new-changes-implementations…md`, `work_flow_test_accounts.md`.
