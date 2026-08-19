# Account Setup & Profile Completion — Design (2026-08-07)

## Goal

Every account on the platform — company owners and employees of every role, across all three
org types (`mineSupplier`, `buyer`, `transporter`) — gets a guided **"Complete your account
setup"** experience:

- Personal / company details (missing fields called out explicitly).
- Document uploads (ID / passport + work visa, driver's licence, PrDP, PSIRA, certificates,
  company registration, tax clearance, insurance, …) with **expiry dates** captured where the
  document type carries one.
- A dedicated **Medicals** section (certificate of fitness, with expiry).
- **Signature** capture (reuses `profiles.signature_url` + `signatures` bucket).
- Role-specific requirements per org type (driver ≠ security ≠ load controller ≠ buyer admin…).
- A live **completion score** with "still required / still missing / expiring / expired" states,
  surfaced as: a persistent portal banner, a login popup, inbox notifications, and employer-side
  visibility (register + employee profile + management notifications).
- Daily server-side reminders to **both** the user and company management for missing items and
  expiring/expired documents (compliance engine extended, not duplicated).

## Existing building blocks (verified live, project `yftazblpmicqtamyiwyb`)

- `compliance_documents` — polymorphic (vehicle/employee/company) doc registry with
  `expires_at`, `last_notified_at` throttle, `compliance_docs` private bucket, daily cron
  `notify-expiring-documents` (04:25) → `notify_expiring_documents_job()` → management only.
  Writes today are manager/admin-gated via `upsert_compliance_document`.
- `employees` — legacy one-slot doc URLs (`id_document_url`, `passport_document_url`,
  `work_visa_document_url`, `license_document_url`), `profile_photo_url`,
  `is_south_african_citizen`, `id_number`, `passport_or_workers_permit`, `whatsapp_number`.
  **No expiry fields, no medicals, no emergency contact, no date of birth.**
- `profiles.signature_url` + private `signatures` bucket.
- `notifications` (`role_scope`, `org_type`, `importance`, `metadata`) + helpers
  `notify_company_management(...)`, `notify_company_role(...)`.
- Role map: `UserRole.getRolesForOrgType` — mineSupplier: security, controllerWB,
  supervisorForeman, admin, management; buyer: admin, management; transporter: driver, admin,
  management. Company-owner accounts are a separate `user_type='company'` axis.
- Known live defect to fix en route: `employees.role` CHECK and `is_valid_role_for_org` omit
  `supervisorForeman` even though the Dart enum and RLS policies use it.

## Architecture

### 1. Requirements catalog (new table `profile_requirements`)

Seeded, platform-owned catalog; one row per requirement item:

- `audience` — `employee` | `company`
- `org_type` — nullable (null = all org types)
- `role` — nullable (null = all roles of that org type); employee audience only
- `item_kind` — `field` | `document` | `signature` | `photo`
- `item_key` — stable key, e.g. `id_document`, `drivers_license`, `medical_certificate`,
  `emergency_contact`, `company_registration`
- `label`, `description`, `category` (`personal` | `identity` | `medical` | `licences` |
  `certifications` | `company`), `requires_expiry` bool, `requires_file` bool,
  `is_required` bool (required vs recommended), `sort_order`.

RLS: readable by any authenticated user; writes platform-admin only.

Seed matrix (summary — required unless "(rec)"):

- **All employees, all orgs:** profile photo; ID document (SA) *or* passport + work visa
  (non-SA) — resolved via `is_south_african_citizen`; signature; emergency contact
  (name + phone fields); date of birth + residential address (rec); WhatsApp (already
  mandatory at sign-up, counted complete).
- **Medical (category `medical`):** certificate of fitness with expiry — required for all
  mineSupplier roles and transporter drivers; recommended for everyone else. Extra slot
  "other medical record" (rec, expiry optional) for all.
- **transporter/driver:** driver's licence (expiry), PrDP (expiry), certificate of fitness
  (above); induction certificate (rec, expiry).
- **mineSupplier/security:** PSIRA registration (expiry); firearm competency (rec, expiry).
- **mineSupplier/controllerWB:** weighbridge/load-controller competency certificate (rec,
  expiry).
- **mineSupplier/supervisorForeman:** supervisor appointment letter (2.9.2-style) (rec);
  first-aid certificate (rec, expiry).
- **admin/management (all orgs):** identity + signature + medical(rec) only.
- **Company owners:** logo (field on `companies`), CEO first/last name, support email,
  signature; company registration (CIPC) doc; tax clearance (expiry); B-BBEE certificate
  (rec, expiry). Plus org-specific: mineSupplier → mining permit/licence (expiry);
  transporter → GIT insurance (expiry), operating licence (rec, expiry); buyer → VAT
  registration (rec).

### 2. Employee/company detail fields (migration additions)

`employees`: `date_of_birth date`, `residential_address text`, `emergency_contact_name text`,
`emergency_contact_phone text`, `email text` (contact email distinct from login, optional),
`profile_setup_completed_at timestamptz`, `profile_reminder_at timestamptz` (nag throttle).
Widen `employees.role` CHECK + `is_valid_role_for_org` to include `supervisorForeman`.
`companies`: `profile_reminder_at timestamptz` (digest throttle).

### 3. Documents = `compliance_documents` (reuse, no parallel store)

Every uploaded setup document is a `compliance_documents` row (owner employee or company),
so the existing expiry engine, compliance tabs, and employee-profile document list all keep
working. New `item_key`-bearing column? No — reuse `doc_type` = catalog `item_key`.
Legacy `employees.*_url` slots count as satisfying their item when present (no expiry data;
shown with an "add expiry / re-upload" hint) — no destructive migration.

New self-service RPCs (SECURITY DEFINER, employee-scoped):

- `upsert_my_compliance_document(p_item_key, p_title, p_doc_number, p_issued_at, p_expires_at,
  p_file_path, p_notes, p_id default null)` — caller must be an active employee; forces
  `owner_type='employee'`, `owner_id=their employee id`, `company_id=their company`. Company
  owners get the same via owner_type='company' when caller owns the company.
- `delete_my_compliance_document(p_id)` — same scoping.
- Storage policy: allow the employee to read/write `compliance_docs` under
  `<company_id>/employee/<employee_id>/…`; company owner under `<company_id>/company/…`.

### 4. Completion RPC — `get_profile_setup(p_employee_id default null)`

SECURITY DEFINER. `null` → the caller's own setup (employee or company-owner account);
non-null → employer/manager (or platform admin) viewing an employee. Returns jsonb:

- `audience`, `org_type`, `role`, resolved requirement list with per-item:
  `item_key`, `label`, `category`, `item_kind`, `is_required`, `requires_expiry`,
  `status` — `complete` | `missing` | `needs_expiry` | `expiring` | `expired`,
  `expires_at`, `days_to_expiry`, `document_id`, `file_present`, `source`
  (`field` | `legacy_url` | `compliance_doc` | `signature`)
- `summary`: total/required/complete counts, `completion_percent` (required items only),
  `missing_required`, `expiring_count`, `expired_count`.

Citizenship branching handled server-side (ID vs passport+visa). Expiring = ≤30 days,
matching the engine.

### 5. Reminders (server, daily cron)

- **Extend** `notify_expiring_documents_job`: after the management notice, also insert a
  direct notification to the document owner's user (employee owner → `employees.user_id`;
  company owner → `companies.user_id`), same 6-day throttle row.
- **New** `notify_incomplete_profiles_job` (daily 04:40, jobname `notify-incomplete-profiles`):
  for each active employee/company-owner with missing required items → personal notification
  ("Your account setup is incomplete — N items still required: …"), throttled via
  `profile_reminder_at` (6 days). Per company: one management digest ("N team members have
  incomplete profiles") throttled via `companies.profile_reminder_at` (6 days).

### 6. Flutter

New feature folder `lib/features/profile_setup/`:

- `models/profile_setup.dart` — wire model of the RPC payload.
- `services/profile_setup_service.dart` — RPC + uploads (compliance_docs & employee_assets &
  signatures buckets) + save-field methods.
- `providers/profile_setup_provider.dart` — `profileSetupProvider` (self),
  `employeeProfileSetupProvider(employeeId)` (employer view), refresh on employee/doc changes.
- `screens/profile_setup_screen.dart` — sectioned checklist screen (Personal details,
  Identity documents, Medicals, Licences & certificates, Signature, Company details for
  owners): per-item cards with status chip (Missing / Required / Expiring in Nd / Expired /
  Complete), inline editors, file pick + upload, expiry-date picker (shown whenever
  `requires_expiry`), doc number, signature pad reuse. Progress header with percent ring.
- `widgets/profile_setup_banner.dart` — compact banner ("Account setup 62% — 3 required items
  missing, 1 document expired · Complete now") mounted on portal dashboards/shell for every
  role incl. driver app shell; hidden at 100% with nothing expiring.
- Login popup: once per session, if required items missing or anything expired → dialog with
  the missing list + "Complete now" (routes to the setup screen). Shown for employees and
  company owners.
- Routes: `/portal/{mine,buyer,transporter}/account-setup`, `/portal/driver/account-setup`,
  plus a bare `/account-setup` for pre-portal states (waiting-for-role employees can complete
  their profile early).
- Employer side: employee profile screen gains a "Profile setup" card (percent + missing
  required items, from `employeeProfileSetupProvider`); register rows show a subtle
  incomplete-profile indicator. Existing Compliance tab keeps being the doc admin surface.

### 7. Error handling & tests

All service calls best-effort try/catch per repo convention; RPC guards raise exceptions with
clear messages. Tests: model parsing tests, requirement-resolution tests (per role/org/citizen
branch), widget smoke test for the setup screen; server-side verified live with rolled-back
transactions (guard rejections + owner paths + throttle idempotency), matching how earlier
engines were verified.

## Alternatives considered

- **Hardcode requirements in Dart** — rejected: server needs the same matrix for the daily
  incomplete-profile job and employer views; one catalog table keeps a single source of truth.
- **New `employee_documents` table** — rejected: would fork the expiry engine; compliance
  engine already models exactly this with cron + throttle + UI.
- **Hard-block portal until setup complete** — rejected (YAGNI + operationally hostile);
  banner + popup + notifications nag instead. Can be tightened later via a flag.
