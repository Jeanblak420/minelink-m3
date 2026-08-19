# MineLink — screen coverage map

Every screen in the codebase `lib/features/**/screens/`, mapped to one of four states:
- **BUILT** — redesigned & delivered in this design system (interactive kit screen)
- **COMING SOON** — branded holding screen (deferred at your request)
- **MISSING** — not yet designed (this turn's build target)
- **N/A** — debug/dev-only or represented structurally elsewhere

## Auth
- login → **BUILT** (auth: LoginScreen)
- whatsapp_otp → **BUILT** (auth: OtpScreen)
- forgot_password → **BUILT** (auth: ForgotScreen)
- reset_password → **MISSING** (dedicated set-new-password form)
- mandatory_password_change → **MISSING** (forced change on first sign-in)

## Chat
- chat_screen → **BUILT** (chat kit)
- communications_hub_screen → **BUILT** (replaced by Messages, per your instruction)

## Company
- company_list_screen → **BUILT** (super-admin Organizations)
- company_employees_screen → **BUILT** (dark editorial Employee Register — shared `ui_kits/shared/employee-register.jsx`, read-only for super-admin mirror, manage for own portals; per org type Mine/Buyer/Transporter)

## Employee
- employee_grid_screen → **BUILT** (dark editorial Employee Register — role-grouped, presence, tenure/skill chips, per-person & coverage sparklines, live stats)
- employee_dismissal_management_screen → **COMING SOON** (deferred)
- employee_dismissed_screen → **COMING SOON** (deferred)
- company_selection_screen → **MISSING** (choose which company/workspace to enter)
- waiting_for_role_screen → **MISSING** (role-pending state)
- request_declined_screen → **MISSING** (join-request declined state)

## Fleet
- fleet_management_screen → **BUILT** (transporter Fleet + filter)
- fleet_document_debug_screen → **N/A** (debug)

## Home / Demo / Tabs
- home_screen → **BUILT** (Preview.html launcher)
- components_demo_screen → **N/A** (Design System tab cards)
- tabs/*_tab_screen (8) → **BUILT** (each is a role nav shell = our portal kits)

## Notifications
- notification_screen → **BUILT** (notifications kit)
- notification_management_screen → **BUILT** (notifications centre)

## Operations
- operations_hub_screen → **COMING SOON** (deferred; tile on mine dashboard)

## Portal — Buyer
- buyer_portal_dashboard / routes_mines / requests / waybills / reconciliations / truck_locations → **BUILT**
- request_transportation → **BUILT**

## Portal — Transporter
- transporter dashboard / routes / reconciliations / truck_locations / truck_positions → **BUILT**
- transporter_maintenance_screen → **MISSING** (per-truck maintenance + truck-pack PDF)

## Portal — Mine / Supplier
- mine_supplier dashboard / truck_locations / buyers_detail → **BUILT**
- load_controller → **BUILT** (Control + seals)
- security_checkin → **BUILT** (mobile Security)
- stockpile_audit / stockpile_detail → **BUILT** (Stockpile + add-tons)
- driver_routes → **BUILT** (Driver app)
- loading_activity_detail_screen → **MISSING**
- tons_out_detail_screen → **MISSING**
- supervisor_view_screen → **MISSING**

## Profile
- profile_screen → **MISSING** (org-user profile)
- account_security_screen → **BUILT** for super-admin; **MISSING** for org users (shared)

## Super Admin — all **BUILT**
- super_admin_dashboard (Console), organization_management, organization_detail,
  super_admin_org_insights, super_admin_company_mirror, token_requests, token_history,
  audit_logs, child_admin, platform_admin_settings, platform_users, register_company,
  request_review, seat_requests
- expired_access_screen → **MISSING** (token-expired lockout state)

---

## MISSING build list (this turn) — DONE
1. **Shared state screens** (`ui_kits/states/`): waiting_for_role, request_declined, expired_access, mandatory_password_change, reset_password, company_selection, org-user profile + account security → **BUILT**.
2. **Mine detail screens** (`ui_kits/mine-supplier/screens-detail.jsx`): loading_activity_detail, tons_out_detail (D/W/M/Y + buyer filter), supervisor_view → **BUILT** (nav: Loading Activity, Tons Out, Supervisor View).
3. **Transporter**: maintenance detail (per-truck + truck-pack PDF) → **BUILT** (nav: Maintenance).
4. **Profile**: shared org-user profile + account security → **BUILT** (in states kit).
5. **company_selection** (workspace picker) → **BUILT** (in states kit).

Remaining **COMING SOON** (deferred at user request): employee_dismissal_management, employee_dismissed, operations_hub.
All other codebase screens are **BUILT**. Coverage complete except the deferred set.
