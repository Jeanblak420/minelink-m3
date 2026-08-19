# Canonical Platform Codemap

## Canonical environment

- Supabase project ref: `yftazblpmicqtamyiwyb`
- Canonical schema reset and rebuild: [supabase/migrations/20260327000100_canonical_platform_reset.sql](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/supabase/migrations/20260327000100_canonical_platform_reset.sql)
- Flutter runtime config: [lib/core/config/supabase_config.dart](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/lib/core/config/supabase_config.dart)

## App map

- [lib/main.dart](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/lib/main.dart): bootstraps Supabase with `dart-define` values and starts Riverpod.
- [lib/app.dart](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/lib/app.dart): app shell and router wiring.
- [lib/core/routing/app_router.dart](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/lib/core/routing/app_router.dart): auth-aware route protection and redirect rules.
- [lib/core/services](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/lib/core/services): shared database, cache, and maintenance helpers.
- [lib/features/auth](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/lib/features/auth): sign-in, sign-up, auth state stream handling, and user-type bootstrapping.
- [lib/features/company](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/lib/features/company): company profile management and employee approval flows.
- [lib/features/employee](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/lib/features/employee): employee onboarding, company linking, status history, dismissal flow, and documents.
- [lib/features/notifications](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/lib/features/notifications): notification reads plus RPC-based notification creation.
- [lib/features/fleet](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/lib/features/fleet): transporter fleet CRUD, driver assignment, and driver-document snapshot debugging.
- [lib/features/chat](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/lib/features/chat): room, message, presence, and broadcast collaboration flows.
- [lib/features/tabs](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/lib/features/tabs): role- and org-specific tab shells for mine/supplier, buyer, transporter, and staff roles.

## Backend map

- [supabase/migrations](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/supabase/migrations): source of truth for schema, RLS, grants, storage, and realtime publication setup.
- [supabase/functions](/C:/Users/Somebody%20Someone/Downloads/The_Mineral_Guide-main/The_Mineral_Guide-main/supabase/functions): legacy and optional edge functions. Core onboarding and workflow logic now lives in Postgres functions, not webhook handlers.
- Storage buckets:
  - `company_assets`
  - `employee_assets`
  - `chat_files`

## Schema map

- Identity:
  - `profiles`
- Org lifecycle:
  - `companies`
  - `employees`
  - `employee_status_history`
  - `notifications`
- Fleet:
  - `fleet_vehicles`
- Collaboration:
  - `chat_rooms`
  - `chat_messages`
  - `broadcast_messages`
- Operations:
  - `minerals`
  - `transactions`
  - `weighbridge_records`
  - `mineral_loads`
  - `security_incidents`
  - `gate_checks`

## Canonical runtime flows

- Company signup:
  - Auth signup creates `profiles` through an auth trigger.
  - The client calls `complete_company_signup`.
  - Company screens read from `companies` and subscribe to Postgres Changes.
- Employee signup:
  - Auth signup creates `profiles`.
  - The client calls `complete_employee_signup`.
  - Employee documents upload to `employee_assets`, then employee profile updates run through `update_my_employee_profile`.
- Employee company request:
  - The client calls `request_company_link`.
  - The database writes the employee state change, history entry, and notifications atomically.
- Approval and role assignment:
  - Company-side clients call `approve_employee_request`, `assign_employee_role`, or `decline_employee_request`.
  - Employees receive updated profile state and notification rows through realtime subscriptions.
- Dismissal flow:
  - Company management calls `initiate_employee_dismissal` or `resolve_employee_dismissal`.
  - Employees call `submit_employee_dismissal_appeal`.
  - The database owns status history and notification fan-out.
- Fleet flow:
  - Transporter management uses `create_fleet_vehicle`, `update_fleet_vehicle`, `assign_fleet_driver`, `unassign_fleet_driver`, and `delete_fleet_vehicle`.
  - Driver document snapshots live on the `fleet_vehicles` row and refresh on assignment.

## Legacy notes

- Webhook-driven onboarding and `run_sql` debugging are no longer part of the supported production path.
- Legacy helper files still exist for reference in some areas, but the app's current hot path is RPC- and Postgres-Changes-based.
