<!-- markdownlint-disable-file -->
# Admin (Mine/Supplier) users & roles — design

Date: 2026-06-17

## Context

Mine/Supplier **Admin** employees need a focused workspace whose only capability is
managing their company's users, plus an Add-User flow that creates WhatsApp-number
identities (no email shown). Roles for Mine/Supplier gain **Supervisor/Foreman** and the
existing **Controller/WB** is relabelled **Load Controller**.

The full WhatsApp-OTP login is a separate, larger effort (**Phase B**) requiring an external
WhatsApp provider. This spec covers **Phase A** (screens + roles) and records the agreed
Phase B requirements for later design.

The existing pieces already in place (mapped before design):
- Admin Workspace: `lib/features/tabs/screens/admin_tab_screen.dart` (via `OperationsWorkspace`).
- Add User form: `lib/features/company/widgets/company_employee_form_dialog.dart`.
- Roles enum: `lib/features/auth/models/user_type.dart` (`UserRole`).
- Create flow: form → `company_employees_screen` → `companyProvider.createManagedEmployee`
  → `CompanyDatabaseService.createManagedEmployee` → edge function `company-user-admin`
  (`auth.admin.createUser`, **requires an `@` email**) → RPC `create_company_managed_employee`.
- Login: `lib/features/auth/widgets/login_form.dart` → `authStateProvider.signIn(email, password)`.

## Phase A — scope

### A1. Credential model (interim)
Admin-created Mine/Supplier users have **no user-entered email**. To keep the existing
email-based `createUser` working and let users log in today, the form derives a
**deterministic synthetic email** from the WhatsApp number:

```
wa-<digits-only>@wa.mineralguide.com
```

- One shared pure helper `whatsappAuthEmail(String whatsappNumber)` in
  `lib/features/auth/utils/whatsapp_identity.dart`, unit-tested.
- Used by the Add User form (to populate the otherwise-hidden email) and by the login form
  (to map a typed WhatsApp number → the same synthetic email).
- The edge function and service/provider signatures are **unchanged**; only the source of
  the `email` value changes (now derived, not typed).
- Password is kept (image 3 shows it) and set at creation; it is the interim login
  credential until Phase B replaces it with OTP.

### A2. Roles (`user_type.dart`)
- Add enum value `supervisorForeman('Supervisor/Foreman')`.
- Relabel `controllerWB` from `'Controller/WB'` to `'Load Controller'`. The **enum name and
  stored DB value `controllerWB` stay the same** so existing records and RPCs keep working.
- Mine/Supplier role list (`getRolesForOrgType`): Security, Load Controller (controllerWB),
  Supervisor/Foreman, Admin, Management (Management retained — least-destructive).
- Add `supervisorForeman` to `managementNotificationScopes` (treated like controllerWB-level:
  management & admin scopes include it; it sees its own scope + null).

### A3. Propagation of the new/renamed roles
- `lib/features/employee/screens/employee_grid_screen.dart`: add color + label for
  `supervisorForeman`; the `controllerWB` label now reads "Load Controller".
- `lib/features/operations/models/operations_models.dart`: give `supervisorForeman` an
  operations-tab set (start with the same as controllerWB: transactions + weighbridge;
  refine later).
- `lib/features/super_admin/screens/organization_detail_screen.dart` and
  `platform_users_screen.dart`: add/relabel the string→label maps.
- `lib/features/portal/portal_navigation.dart`: relabel the "Controller" tab to
  "Load Controller"; add a Supervisor/Foreman employee tab (reuse an existing workspace
  screen for now — no new bespoke screen in Phase A).
- All driven off `UserRole.label` where possible so future label changes are single-source.

### A4. Add User form → image 3
Field order: **WhatsApp Number, Password, First Name, Last Name, Role**. Email field
removed. `CompanyEmployeeFormResult.email` is set to `whatsappAuthEmail(whatsappNumber)`.
Role dropdown reflects the updated Mine/Supplier list. WhatsApp number gets light validation
(non-empty + contains digits).

### A5. Admin Workspace → image 1 (capability trim)
`admin_tab_screen.dart`: keep **Employees** and **Active** metric cards and the
**Manage Employees** primary action; keep "Latest Team Updates" + notifications.
**Remove** the Pending and Unread metric cards and the Company Profile / Operations Hub /
Communications actions (admins are scoped to user management only).

### A6. Login form
Accept either an email or a WhatsApp number. If the typed identifier contains `@`, treat as
email (unchanged path). Otherwise treat as a WhatsApp number and sign in with
`whatsappAuthEmail(identifier)` + password. Existing email logins (company owners, super
admins) are unaffected.

## Phase B — WhatsApp OTP login (design later, NOT in this spec's implementation)

Agreed requirements to carry forward:
- Identity keyed by WhatsApp number; login via OTP delivered over WhatsApp; password removed
  for these users.
- Provider: likely Supabase Send-SMS auth hook → Meta WhatsApp Cloud API (free tier),
  decided in the Phase B brainstorm. Self-hosted unofficial bridges advised against for a
  login-critical path.
- Number must be WhatsApp-verified.
- Re-verification cadence: verify on a **new device**, then **weekly on Mondays**; if Monday
  is missed, verify on the **next login/use** after that. Tracked per device.

## Testing (Phase A)
- Unit test `whatsappAuthEmail`: digit extraction, formatting, idempotence, ignores spaces/
  `+`/dashes.
- Unit test `UserRole`: `supervisorForeman` parses round-trip; `controllerWB.label ==
  'Load Controller'`; Mine/Supplier role list contents.
- `flutter analyze` clean on touched files; existing tests still pass.

## Out of scope
- Real WhatsApp messaging, OTP send/verify, phone-based Supabase users (all Phase B).
- New bespoke Supervisor/Foreman workspace screen (reuse existing in Phase A).
