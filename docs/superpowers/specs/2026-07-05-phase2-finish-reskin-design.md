# Phase 2 — Finish the Reskin (design/spec)

**Date:** 2026-07-05
**Program:** Full Flutter Windows build of MineLink. Base = this worktree.
**This phase:** bring the remaining un-reskinned UI up to the LoadTrack design's fidelity, using the existing `lib/features/portal/widgets/ml/*` component library and `lib/core/theme/ml_tokens.dart`. Chat screens are intentionally excluded (rebuilt wholesale in Phase 3/B).

## Principle
"Make the look exactly the same." Reskin = replace ad-hoc `Container`/`Card`/`Colors.*`/raw `TextStyle` with the shared design-system widgets and semantic tokens (`MlSemantic.of(context)`, `MlTokens`, `MlTone`, `MlStatCard`, `MlFeatureCard`, `MlCard`, `MlButton`, `MlStatusBadge`, `MlPlatePill`, `MlSectionTitle`, `MlDataTable`, `MlEmptyState`, `MlIconWell`). Match the corresponding design kit under
`docs/new system design/minelink-new-design-v0.1/ui_kits/<area>/` and, where a PNG exists, the mockup in `.../assets/reference/`.

Do NOT change business logic, providers, models, services, routing, or Supabase calls. Visual layer only.

## Batches (implement in order, one file/screen at a time, verify after each)
1. **Auth** — `features/auth/screens/login_screen.dart`, `features/auth/widgets/login_form.dart`. Ref: `ui_kits/auth/` (README + screens.jsx). First impression.
2. **Profile** — `profile_screen.dart` (934), `account_security_screen.dart`, `widgets/change_password_section.dart`, `widgets/company_token_requests_panel.dart`. Fully un-reskinned. Ref: `ui_kits/states/` (profile + account security are built there) + `ui_kits/shared/`.
3. **Portal detail screens** — `loading_activity_detail`, `request_transportation`, `stockpile_audit`, `stockpile_detail`, `tons_out_detail`. Ref: `ui_kits/mine-supplier/`, `ui_kits/buyer/`, `ui_kits/stockpile/`.
4. **Dialogs & small widgets** — fleet (`add_vehicle_form`, `edit_vehicle_dialog`, `driver_assignment_dialog`, `fleet_vehicle_table`, `vehicle_details_fields`), `company/widgets/company_employee_form_dialog`, employee widgets (`approval_pending_overlay`, `document_upload_widget`, `employee_status_timeline`), notification widgets (`welcome_notification`, `notification_icon`, bells). Ref: `components/forms/`, `components/core/`.

## Excluded / deferred
- Chat screens (Phase 3). `fleet_document_debug_screen` (debug, N/A). `employee_dismissal_management` / `employee_dismissed` are COMING SOON per COVERAGE.md — reskin lightly or leave as branded holding screens.

## Verification (per file)
1. `flutter analyze lib` → no new issues.
2. Rebuild `flutter build windows --debug` succeeds.
3. Where the screen is reachable in the running app, capture it (PrintWindow) and eyeball against the kit/mockup. Where not reachable without a specific role login, verify by code review against the kit and note it as code-verified.

## Definition of done for Phase 2
Every target file uses the ml design system + semantic tokens; app builds; Super-Admin/portal/auth/profile screens visually consistent with the design; no business-logic regressions.
