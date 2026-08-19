# MineLink Design-System Port — Implementation Plan

> **For agentic workers:** Executed INLINE by the main agent (user forbids subagents). Steps use checkbox (`- [ ]`) syntax for tracking. REQUIRED SUB-SKILL: superpowers:executing-plans.

**Goal:** Port the complete `docs/new system design/minelink-new-design-v0.1` design system (navy-sidebar "MineLink/LoadTrack" premium look) into the Flutter app so every screen matches the ui_kits visually, while preserving ALL existing functionality, data wiring, and extra screens.

**Architecture:** Three foundation layers first — (1) design tokens + bundled fonts + upgraded `AppTheme`, (2) a shared `ml_widgets` component library mirroring the design-system primitives, (3) the upgraded portal chrome (`PortalScaffold`/`PortalShellLayout`). Then portal-by-portal screen restyling that swaps visual containers to the shared library WITHOUT touching providers, services, models, or navigation logic.

**Tech Stack:** Flutter (SDK ^3.8 beta), Riverpod, go_router, Supabase. Fonts bundled as assets (Plus Jakarta Sans, JetBrains Mono, Fraunces). No new packages unless font download fails (fallback: `google_fonts`).

**Spec:** the design package itself is the spec — `docs/new system design/minelink-new-design-v0.1/` (readme.md = foundations, `tokens/*.css` = exact values, `ui_kits/shared/shell.jsx` = chrome, `ui_kits/<portal>/screens*.jsx` = per-screen truth, `COVERAGE.md` = screen map). `templates/` duplicates `ui_kits/` — always read `ui_kits/`.

## Global Constraints

- **Never remove functionality.** Existing providers, callbacks, routes, dialogs, extra screens/features stay. Restyle containers only; where the design lacks a feature the app has, keep the feature and style it consistently.
- **ui_kits are canonical** where mockup PNGs and JSX disagree (e.g. sidebar active tile is `#6ab8ff`-blue tinted per `shell.jsx`, not cyan).
- Brand: **MineLink** wordmark in chrome; app name stays as-is elsewhere.
- Fonts: `PlusJakartaSans` (UI, weights 400–800), `JetBrainsMono` (plates/serials/times/tonnage), `Fraunces` 600 (sidebar wordmark only).
- Key tokens (from `tokens/*.css`): accent `#00B5D8`, accent-hover `#0496B6`, navy sidebar gradient `#0C1C34→#050B18`, app bg `#F8FAFC`, card white + border `#E7EDF3`, divider `#E9EEF4`, text strong `#0F172A` / body `#334155` / muted `#475569` / faint `#94A3B8`;
  status pairs — transit `#2563EB`/`#EFF6FF`, atMine `#B45309`/`#FEF3C7`, done `#15803D`/`#DCFCE7`, warn `#C2410C`/`#FFEDD5`, error `#DC2626`/`#FEE2E2`; wells — cyan `#E2F6FB`, amber `#FDEEDD`, green `#E3F5EA`, blue `#E7EFFE`;
  radii — chip 8, button/input/nav 12, card 16, hero 20, sheet 24, pill 999; shadows — sm `0 1px 3px rgba(15,23,42,.06)`, hero `0 8px 18px rgba(0,181,216,.07)`, drawer `-16px 0 40px rgba(15,23,42,.12)`;
  motion — sidebar 260ms easeOutCubic, hover 180ms, count-up 850ms, modal 180–220ms, slide-over 280ms;
  layout — sidebar 274/78 (JSX; Flutter keeps its 268/76 constants, close enough — update to 274/78), appbar ≥72, content padding 28, max-width 1280.
- Type scale: display 34, h1 26, h2 22, h3 18, title 16, body 15, body-sm 13, label 12, micro 11. Headline numerals & feature titles w800. Status pills 12/w700 UPPERCASE. Table headers 11.5/w700 UPPERCASE ls .08em.
- Dark theme must keep working: use the `[data-theme="dark"]` token remaps from `tokens/semantic.css` (surface-app `#0A1424`, card `#111C30`, raised `#16243C`, translucent status bgs, etc.).
- Verification gate per task: `flutter analyze` clean (no new issues) + relevant `flutter test` green + commit.

---

## Phase 0 — Housekeeping

### Task 0.1: Commit pre-existing dialog-context fix

**Files:** `lib/features/portal/screens/mine_supplier_buyers_detail_screen.dart` (already modified in tree)

- [ ] `git add lib/features/portal/screens/mine_supplier_buyers_detail_screen.dart && git commit -m "fix(portal): pop buyer-panel dialogs with the dialog's own context"`

---

## Phase 1 — Foundations (tokens, fonts, theme)

### Task 1.1: Bundle fonts

**Files:**
- Create: `assets/fonts/PlusJakartaSans-VariableFont_wght.ttf` (or static 400/500/600/700/800), `assets/fonts/JetBrainsMono-{Regular,Medium,Bold}.ttf`, `assets/fonts/Fraunces-SemiBold.ttf`
- Modify: `pubspec.yaml` (add `fonts:` section)

- [ ] Download from Google Fonts GitHub (`github.com/google/fonts` raw URLs); verify each file >50KB.
- [ ] Declare families `PlusJakartaSans`, `JetBrainsMono`, `Fraunces` in pubspec with weights.
- [ ] `flutter pub get` OK.
- [ ] Commit `feat(theme): bundle Plus Jakarta Sans, JetBrains Mono, Fraunces fonts`.

Fallback if downloads fail: add `google_fonts` dependency and use `GoogleFonts.plusJakartaSansTextTheme()`.

### Task 1.2: Token file

**Files:** Create: `lib/core/theme/ml_tokens.dart`

**Produces (used by everything later):**
```dart
abstract final class MlTokens {
  // brand/navy/slate/status/well color consts (exact hexes from Global Constraints)
  // fontSans = 'PlusJakartaSans', fontMono = 'JetBrainsMono', fontSerif = 'Fraunces'
  // radii: rXs 6, rSm 8, rMd 12, rLg 16, rXl 20, r2xl 24, rPill 999
  // shadows: shadowXs/Sm/Md/Lg/Hero/Drawer as List<BoxShadow>
  // durations: durFast 140ms, durBase 200ms, durSlow 260ms, durCount 850ms; curve easeOutCubic
}
/// Brightness-aware semantic aliases (light + dark maps from semantic.css)
class MlSemantic { final Color surfaceApp, surfaceCard, surfaceRaised, surfaceSunken, textStrong, textBody, textMuted, textFaint, borderSubtle, borderCard, borderStrong, divider; ... static MlSemantic of(BuildContext) / from(Brightness) }
enum MlTone { transit, atMine, done, warn, error, neutral, accent } // fg/bg pair resolver MlTone.colors(Brightness)
```
- [ ] Write file with ALL values; unit test `test/core/theme/ml_tokens_test.dart` asserting a few exact colors (accent 0xFF00B5D8, statusDoneFg 0xFF15803D, dark surfaceApp 0xFF0A1424).
- [ ] `flutter test test/core/theme/ml_tokens_test.dart` green; commit.

### Task 1.3: AppTheme upgrade

**Files:** Modify: `lib/core/theme/app_theme.dart`; Test: `test/core/theme/app_theme_test.dart` (create)

- [ ] Set `fontFamily: MlTokens.fontSans` on ThemeData; textTheme sizes per type scale (displaySmall 34/w800, headlineSmall 26, titleLarge 22/w800, titleMedium 16/w700, bodyLarge 15, bodyMedium 15, bodySmall 13, labelMedium 12, labelSmall 11).
- [ ] FilledButton: weight 700; keep 12 radius/48 height. Inputs: focused border → `MlTokens.accent` 2px (primary stays seed for the rest of Material).
- [ ] Light scaffold `#F8FAFC` (already), dark scaffold → `#0A1424`, dark card → `#111C30` per semantic.css dark remap.
- [ ] Test: build both themes, assert fontFamily and key colors. Green; commit `feat(theme): Plus Jakarta Sans type scale + MineLink token surfaces`.

### Task 1.4: PortalColors delegation

**Files:** Modify: `lib/features/portal/portal_colors.dart`

- [ ] Keep existing API (screens depend on it) but re-point values at `MlTokens`; add convenience getters used by new chrome (sidebar gradient colors, active tile blue `#6AB8FF` set). No behavior change elsewhere. Analyze clean; commit.

---

## Phase 2 — Shared component library (`lib/features/portal/widgets/ml/`)

One file per component, exported via `lib/features/portal/widgets/ml/ml.dart`. Each gets a widget test in `test/features/portal/ml/` (build + key visual props via finders).

### Task 2.1: `ml_status_badge.dart` — `MlStatusBadge(label, tone, {dot})`
Pill radius 999, bg/fg from `MlTone`, text 12/w700 UPPERCASE ls 0.6, padding h10 v4, optional 6px leading dot. Also `MlStatusBadge.forTripStatus(String)` mapping OTW/AT MINE/LOADED/etc → tones (keep existing app status strings).

### Task 2.2: `ml_plate_pill.dart` — `MlPlatePill(plate, {size})`
JetBrainsMono w700 ls .06em, slate-100 fill, radius 8, 1px border-subtle.

### Task 2.3: `ml_icon_well.dart` — `MlIconWell(icon, {tone, size=46})`
Rounded-square tinted well (radius = size*0.28), well color by tone (cyan/amber/green/blue), icon = accent (cyan tone) or tone fg, icon size = size*0.5. (No Icon3D port — Flutter uses flat wells everywhere; the 3D set is HTML-only. Visual parity note: kits fall back to flat wells in `MLIconMode==='fallback'`, so this is a sanctioned look.)

### Task 2.4: `ml_card.dart` — `MlCard({child, hero=false, padding, onTap})`
White (dark: `#111C30`), radius 16 (hero 20), border `#E7EDF3`, shadow-sm (hero: cyan hero shadow + accent-tinted border + optional 44×3 accent rule via `MlCard.heroTitleRule()` helper). Hover lift 1px on desktop/web (MouseRegion translate).

### Task 2.5: `ml_stat_card.dart` — `MlStatCard(label, value, icon, {tone, delta, onTap, animateCount})`
White card + icon well left + value (22–26/w800, count-up 850ms when `animateCount` and value numeric) + label 13 muted; optional delta line "▲ 12.5t vs yesterday" (green/red).

### Task 2.6: `ml_feature_card.dart` — `MlFeatureCard(title, description, icon, {tone, buttonLabel='Open', onOpen})`
Card 16, icon well 48 tone-tinted, title 16–18/w800, desc 13 muted, outlined pill button "Open →" (accent border/text).

### Task 2.7: `ml_section_title.dart` — `MlSectionTitle(title, {icon, action})`
Icon (accent, 22) + 18/w800 + trailing action slot; bottom margin 16.

### Task 2.8: `ml_data_table.dart` — `MlDataTable(columns: [MlColumn(label, flex/width, align)], rows: [List<Widget>])`
Header row: 11.5/w700 UPPERCASE ls .08em faint; body rows padding v14, hairline divider `#E9EEF4`; horizontal scroll fallback under min width.

### Task 2.9: `ml_buttons.dart`
`MlButton.primary` (solid cyan, white text, soft cyan shadow), `.go` (green gradient `#16A34A→#15803D`), `.leave` (orange gradient `#F97316→#EA580C`), `.tonal`, `.outline`, `.ghost`, `.danger`. All radius 12, ≥48 tall, w700, hover lift.

### Task 2.10: `ml_empty_state.dart` — `MlEmptyState(icon, title, message, {action})`
Centered faint icon 56 in well, title 16/w700, calm message 13 muted.

### Task 2.11: `ml_map_canvas.dart` — `MlMapCanvas({child, height})`
CustomPainter grid "paper": bg gradient `#EEF2F7→#F1F5F9`, 120px major + 24px minor slate grid lines, radius 16, border. Used as backdrop wrapper where screens show placeholder maps (real `flutter_map` stays where wired).

### Task 2.12: `ml_overlays.dart` — `showMlModal(context, title, child, {footer, width=460})` + `showMlSlideOver(context, title, child, {width=380})`
Modal: navy scrim 45%, card radius 16, fade+pop 200ms. SlideOver: right panel, drawer shadow, translate 280ms easeOutCubic, scrim 32%.

**Steps for EVERY 2.x task:** write widget test → fail → implement → pass → `flutter analyze` → commit (`feat(ml): <component>`).

---

## Phase 3 — Portal chrome upgrade

### Task 3.1: Sidebar (`portal_scaffold.dart`)
- [ ] Background: `LinearGradient(168deg, #0C1C34 → #050B18)`; right hairline `rgba(148,163,184,.08)`; widths 274/78.
- [ ] Brand block: "MineLink" wordmark — Fraunces 22/w600, foreground gradient `#7FE3F2→#5AA2FF` (ShaderMask); subtitle = workspace name, 10.5/w600 uppercase ls .14em (first word `#EAF2FF`, rest `rgba(148,178,214,.55)`); collapse chip button 26×26 radius 8 top-right (collapsed: shows above the single-letter wordmark).
- [ ] Sidebar search field under first nav item (expanded only): 36px, bg `#080F1C`, border `rgba(140,180,240,.12)` → focus `#6AB8FF`, radius 10, "Search..." — filters nav tiles by label (local state).
- [ ] Nav tiles: radius 12, gap 3, padding 10/12; selected: bg `rgba(106,184,255,.10)`, border `rgba(106,184,255,.4)`, inset 3px left `#6AB8FF`, text `#EAF2FF` w700, icon filled white; hover `rgba(148,163,184,.10)`; unselected text `rgba(226,232,240,.82)` w500 14.5.
- [ ] Utility group above footer (hairline top border): Notifications tile (badge dot) → `/notifications`; Settings expandable group (Account & profile → `/profile`, Security & password → `/account-security` if routed, Appearance & theme → theme toggle) — only include children whose routes exist.
- [ ] Footer: Logout button (orange tinted: border `rgba(249,115,22,.28)`, bg `.08`, text `#F97316`, w700) wired to existing `LogoutService.logoutWithConfirmation`; Collapse button (blue tinted); user card (avatar 38 + green presence dot + name 13.5/w700 white + email/role 11.5 `rgba(148,178,214,.7)`) reading auth/employee providers.
- [ ] Keep: navLocked behavior, drawer variant, label-min-width guard, prefs persistence, tooltips when collapsed.

### Task 3.2: App bar (`portal_shell_layout.dart`)
- [ ] Height ≥72, bg surface-card, bottom hairline `#E7EDF3`; home chip button 38×38 radius 11 border `#6AB8FF` icon `space_dashboard` `#8FD0FF` → go home tab 0; title 22/w800 ls -.01em + subtitle 12 `#657795` (existing `workspace · operator · role`); keep back button, both bells (restyle: 42px circular hover, cyan dot ring), profile, logout, compact overflow. Add theme toggle icon button (light/dark) wired to existing theme mode provider if present, else create `themeModeProvider` (StateProvider<ThemeMode>, persisted via SharedPreferences) and consume in `MaterialApp`.
- [ ] Content area padding 28 (wide), `PortalScrollBody` max-width 1280.

### Task 3.3: Chat FAB
- [ ] `MlChatFab` in portal shell Stack (wide layout only… actually all sizes, bottom-right 26): 60×60 radius 20, gradient `#22C2DE→#0496B6`, `forum` icon, unread badge (red pill) from existing chat unread provider if available else hidden; navigates to existing chat/communications route. Hidden on the chat screen itself and for roles without chat access.

**Steps per task:** implement → `flutter analyze` → run existing portal tests (`flutter test test/features/portal/`) → fix → screenshot in running app vs `ui_kits` Preview for eyeball parity → commit (`feat(chrome): …`).

---

## Phase 4 — Screen restyling, portal by portal

**Process contract for every screen task (repeat verbatim):**
1. Read the relevant section of `ui_kits/<kit>/screens*.jsx`.
2. Read the current Dart screen fully.
3. Restyle: swap containers/typography/badges/tables to `ml/` widgets; layout to match kit (KPI row 4-up, feature grid 3/4-up, tables, slide-overs); keep every provider, callback, dialog, route, and extra feature; extra features get styled with the same primitives.
4. `flutter analyze` (no new issues) + `flutter test test/features/<area>/` green (update finders broken by text/casing changes only when semantics unchanged).
5. Commit `feat(<portal>): restyle <screen> to MineLink design`.

### Task 4.1: Mine/Supplier portal (`ui_kits/mine-supplier/screens.jsx` + `screens-detail.jsx`)
- [ ] `mine_supplier_portal_dashboard_screen.dart` (Overview: KPI row, tons-out hero, buyers, loading activity, request-buyers promo panel)
- [ ] `load_controller_screen.dart` (Mine Control: search, KPI row, trucks-ready list with Record Load slide-over form, quick actions, recent loads table)
- [ ] `security_checkin_screen.dart` (mobile Mine Security: search, 3 KPI chips, Incoming — Mark Arrived (green), At Mine — Mark Departure (orange), recent activity, bottom nav look)
- [ ] `mine_supplier_buyers_detail_screen.dart`, `mine_supplier_truck_locations_screen.dart` (list + MlMapCanvas/flutter_map)
- [ ] `stockpile_audit_screen.dart`, `stockpile_detail_screen.dart` (stockpile kit)
- [ ] `loading_activity_detail_screen.dart`, `tons_out_detail_screen.dart` (D/W/M/Y + filter table), `supervisor_view_screen.dart` (screens-detail.jsx)

### Task 4.2: Buyer portal (`ui_kits/buyer/`)
- [ ] `buyer_portal_dashboard_screen.dart` (KPI row: Active Waybills / Tons Allocated / Active Trips / Pending Recons; feature cards Routes & Mines / Reconciliations / Truck Locations; Active Trips table w/ claims+routes filters)
- [ ] `buyer_routes_mines_screen.dart` (expandable route cards: assigned trucks, waybills, trips + Assign Truck / New Waybill buttons)
- [ ] `buyer_requests_screen.dart`, `request_transportation_screen.dart`
- [ ] `buyer_waybills_screen.dart`, `buyer_reconciliations_screen.dart` (KPI row + segmented Overall/By Mine/By Route/By Transporter + recon cards)
- [ ] `buyer_truck_locations_screen.dart` (left truck list + map/empty state)

### Task 4.3: Transporter portal (`ui_kits/transporter/`)
- [ ] `transporter_portal_dashboard_screen.dart`, `fleet_management_screen.dart` (fleet register card grid: plate mono title + status pill, side tipper, driver, docs, Edit/Upload Truck Pack/delete)
- [ ] `transporter_routes_screen.dart`, `transporter_reconciliations_screen.dart`
- [ ] `transporter_truck_locations_screen.dart`, `transporter_truck_positions_screen.dart`
- [ ] `transporter_maintenance_screen.dart`, `driver_routes_screen.dart` (driver kit — mobile: current trip stepper, POD upload)

### Task 4.4: Auth + states (`ui_kits/auth/`, `ui_kits/states/`)
- [ ] `auth_shell.dart` + `login_screen.dart`/forms (brand mark, card, filled inputs, cyan primary)
- [ ] `whatsapp_otp_screen.dart`, `forgot_password_screen.dart`, `reset_password_screen.dart`, `mandatory_password_change_screen.dart`
- [ ] `waiting_for_role_screen.dart`, `request_declined_screen.dart`, `expired_access_screen.dart`, `company_selection_screen.dart`, `employee_dismissed_screen.dart`
- [ ] `profile_screen.dart`, `account_security_screen.dart` (settings/states kit)

### Task 4.5: Super-admin (`ui_kits/super-admin/`)
- [ ] `super_admin_dashboard_screen.dart` (Console), `organization_management_screen.dart`, `organization_detail_screen.dart`, `super_admin_org_insights_screen.dart`, `super_admin_company_mirror_screen.dart`
- [ ] `token_requests_screen.dart`, `token_history_screen.dart`, `seat_requests_screen.dart`, `request_review_screen.dart`, `register_company_screen.dart`
- [ ] `audit_logs_screen.dart`, `child_admin_screen.dart`, `platform_admin_settings_screen.dart`, `platform_users_screen.dart`

### Task 4.6: Chat + notifications (`ui_kits/chat/`, `ui_kits/notifications/`)
- [ ] `chat_screen.dart`, `communications_hub_screen.dart` (Messages look: contact rail, thread, composer)
- [ ] `notification_screen.dart`, `notification_management_screen.dart`

### Task 4.7: Employee register + company (`ui_kits/shared/employee-register.jsx`)
- [ ] `employee_grid_screen.dart`, `company_employees_screen.dart`, `company_list_screen.dart` (dark editorial register — role groups, presence, chips)
- [ ] Coming-soon holding style (`ui_kits/coming-soon/`) for `operations_hub_screen.dart`, `employee_dismissal_management_screen.dart` content shells (keep existing functions reachable)

---

## Phase 5 — Verification

- [ ] `flutter analyze` — zero issues.
- [ ] `flutter test` — full suite green.
- [ ] `flutter run -d chrome` (run_web script) → log in with test accounts (memory: app-test-logins) → walk every portal, screenshot vs `ui_kits` Preview.html side by side; fix deltas.
- [ ] Update memory (`premium-overview-screen.md` / `outstanding-work.md`) with final state.

## Self-review notes

- Spec coverage: all kits mapped to tasks (mine-supplier 4.1, buyer 4.2, transporter+driver 4.3, auth+states+settings 4.4, super-admin 4.5, chat+notifications 4.6, employee-register+coming-soon 4.7, chrome Phase 3, tokens/components Phases 1–2). Icon3D intentionally not ported (flat-well fallback is part of the design; documented in Task 2.3).
- Types consistent: `MlTone`, `MlTokens`, `MlSemantic` defined once (1.2) and consumed everywhere.
- Per-screen JSX detail is intentionally read at execution time (step 1 of the process contract) rather than transcribed here — the executor is the plan author with the design package on disk.
