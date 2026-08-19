# App-wide Back Button — Phase 1 (Navigation) — Design

**Date:** 2026-06-28
**Status:** Approved for spec review
**Phase:** 1 of 2 (Navigation). Phase 2 — cross-session draft persistence — is a separate spec.

## Problem

Navigating the app is hard because there is no working "back" affordance on most
screens. The app already ships an `AppNavigationBackButton`, but it only renders
when Go Router's `canPop()` is `true`. In practice the app:

- switches sidebar tabs by mutating `portalTabIndexProvider` (an index) **without
  changing the route** (it stays on `/home`), and
- navigates between pages with `context.go(...)`, which **replaces** the route
  rather than pushing it.

Both mean `canPop()` is almost always `false`, so the back button is hidden
nearly everywhere. The user experiences this as "there is no back button."

Separately, a redundant collapse toggle ("«") in the top **header bar** clutters
the chrome and should be removed (the sidebar keeps its own collapse toggle).

## Goals (Phase 1)

1. A Back button visible on **every** screen, for **every** role/portal, that
   takes the user to the **previous screen/tab/view they were on** — one step
   back per press.
2. The Back button is **hidden** on the main Dashboard / Overview (the root
   landing screen of each portal).
3. Back is **navigation-only**: it never submits, cancels, or clears anything.
   It cannot, by its own action, erase in-progress input.
4. **In-session resume:** switching tabs / going back and returning to a tab
   preserves that tab's in-progress input, fields, and scroll position (memory
   only — not across logout/crash; that is Phase 2).
5. Remove the **header** "«" collapse toggle. The **sidebar's own** collapse
   toggle stays, so collapsing still works.

## Non-goals (Phase 1)

- Cross-session / persisted drafts surviving logout, crash, device restart, or
  app reload, and the associated "save or clear?" / "continue where you left
  off?" prompts. **That is Phase 2** (separate spec).
- Converting the app's navigation calls from `context.go` to `context.push`.
- Restructuring routing (e.g. route-per-tab).
- Changing any business logic or data flows.

## Approach

A self-contained **custom navigation-history stack** (Riverpod) records each
distinct screen the user lands on — including index-based tab switches and
`go`-based page changes — and drives a Back button. This avoids editing the
~100 existing navigation call-sites and avoids restructuring routing.

Rejected alternatives:
- **Convert everything to `context.push()`** — would make `canPop()` work but
  requires editing every navigation site and cannot represent index-based tab
  switches without restructuring. Invasive, risky.
- **Route-per-tab restructuring** — large architectural change for a navigation
  nicety.

## Components

### 1. `NavLocation` (value object)

Identifies a single screen the user visited:

```
class NavLocation {
  final String path;                 // e.g. '/home', '/profile', '/companies/...'
  final Map<String, String> query;   // GoRouterState query params
  final int? homeTabIndex;           // sidebar tab index when path == '/home', else null
  // equality over (path, query, homeTabIndex)
}
```

- **Equality** is value-based over `(path, query, homeTabIndex)` so consecutive
  duplicate visits can be detected.
- A title is **not** stored here; titles are already derived from the path by
  the shells (`portalShellSectionTitle` / `_titleForPath`).

### 2. `navHistoryProvider` (`StateNotifier<List<NavLocation>>`)

Holds the visit stack. Pure logic — independently unit-testable.

- `bool isRoot(NavLocation l)` — portal: `l.path == '/home' && l.homeTabIndex == 0`;
  super-admin: `l.path == '/super-admin'`. (Root = the main Dashboard/Overview /
  Console landing screen.) The notifier is told which "family" it is via the
  recorder so the same notifier type serves both shells, or root-detection is
  passed in as a predicate. **Decision:** root predicate is injected by the
  recorder, keeping the notifier portal-agnostic.
- `void visit(NavLocation l, {required bool isRoot})`:
  - If `_suppressNextVisit` is set (a back navigation just happened) → clear the
    flag and **ignore** (do not record).
  - If `l` equals the current top → ignore (consecutive-duplicate dedup).
  - If `isRoot` → **reset** stack to `[l]` (this is what hides the button on the
    dashboard and bounds growth).
  - Else → push `l`. Cap the stack at 50 entries (drop oldest) as a memory bound.
- `bool get canGoBack` → `stack.length > 1`.
- `NavLocation? previous` → second-from-top, or null.
- `void markBackNavigating()` → sets `_suppressNextVisit = true` so the navigation
  triggered by `back()` is not re-recorded as a forward visit.

Note: `back()` itself (the actual navigation call) lives in a thin helper that has
`BuildContext`/`WidgetRef` — see below — because it must both pop the stack and
call `context.go(...)`. The notifier exposes `popForBack()` returning the new top
without performing navigation.

### 3. Recorder widget (`NavHistoryRecorder`)

A small widget wrapping each shell's content. It receives the current
`NavLocation` (computed by the shell from `GoRouterState` + `portalTabIndexProvider`)
and the `isRoot` flag, and records a visit whenever that location changes
(via `didUpdateWidget` + an initial `initState` record, both inside a
post-frame callback to stay out of build side-effects). Encapsulated so no
navigation/business logic leaks into shell `build`.

- Portal shell computes: `path = uri.path`, `query = uri.queryParameters`,
  `homeTabIndex = path == '/home' ? tabIndex : null`,
  `isRoot = path == '/home' && tabIndex == 0`.
- Super-admin shell computes: `path = uri.path`, `query = uri.queryParameters`,
  `homeTabIndex = null`, `isRoot = path == '/super-admin'`.

### 4. `AppNavigationBackButton` (modified)

Switch from `router.canPop()` to the history provider:

- Visible when `ref.watch(navHistoryProvider.notifier).canGoBack` (equivalently
  stack depth > 1); otherwise `SizedBox.shrink()` (hidden on root → hidden on
  Dashboard/Overview).
- `onPressed` calls the back helper: `markBackNavigating()`, pop the stack to the
  previous `NavLocation`, then navigate to it:
  - if `previous.homeTabIndex != null`: set
    `portalTabIndexProvider = previous.homeTabIndex` then `context.go('/home')`;
  - else `context.go(previous.fullPathWithQuery)`.
- Tooltip stays "Back"; icon stays `Icons.arrow_back_rounded`. Still purely
  navigational — no undo/submit/clear side effects (satisfies Goal 3).

Because the button is already placed in the leading slot of both the portal
header and the super-admin header, **no per-screen placement changes** are
needed — the change to its show/hide logic makes it appear app-wide.

### 5. System / hardware back (`PopScope`)

Both shells already wrap content in `PopScope(canPop: false, ...)` delegating to
`router.canPop()`. Repoint these to the same back helper: if `canGoBack`, perform
the history back; otherwise allow the default (e.g. exit). Keeps the on-screen
button and the OS back gesture identical.

### 6. Remove header "«"

- **Portal:** delete the `if (!narrowNav) IconButton(... Collapse/Expand
  navigation ...)` block in `portal_shell_layout.dart` (the header toggle in the
  user's screenshot). The sidebar's own collapse toggle in `portal_scaffold.dart`
  is **kept**.
- **Super-admin:** remove the analogous header toggle in
  `super_admin_shell_layout.dart` (the `if (!useDrawer) IconButton(...
  Collapse/Expand navigation ...)` block) for consistency. The sidebar's own
  toggle (`onToggleRailExpanded` in `_SidebarNav`) is **kept**.

### 7. In-session tab keep-alive

Replace the `/home` tab host in `home_screen.dart` (currently
`AnimatedSwitcher` + `KeyedSubtree`, which **disposes** the previous tab) with a
**lazy keep-alive** model:

- A tab is built the first time it is selected, then kept alive (not disposed)
  when other tabs are shown. Achieved with an `IndexedStack` over the set of
  **already-visited** tab indices (so heavy tabs like *Truck locations* are not
  all eagerly mounted), or equivalently `AutomaticKeepAliveClientMixin` wrappers.
  **Decision:** lazy `IndexedStack` — maintain a `Set<int>` of visited indices;
  render an `IndexedStack` whose children are the visited tabs (placeholder
  `SizedBox.shrink()` for not-yet-visited slots) and whose `index` points at the
  current tab. This keeps visited tabs (and their `TextEditingController`s,
  scroll positions) alive across switches and back-navigation, in memory.
- The fade transition between tabs may be dropped or kept minimal; preserving
  state takes priority over the switch animation.

## Behaviour walkthrough

- Land on Dashboard (`/home`, tab 0) → stack `[Dashboard]` → Back hidden.
- Dashboard → Routes & Mines (tab 1) → stack `[Dashboard, Routes]` → Back shows;
  pressing it → Dashboard, stack `[Dashboard]`, Back hidden.
- Routes → open a detail (`go('/companies/...')`) → stack
  `[Dashboard, Routes, Detail]` → Back → Routes.
- From anywhere, tap the sidebar **Dashboard** → lands on root → stack resets to
  `[Dashboard]` → Back hidden.
- Half-fill a form in a tab, switch to another tab, press Back to return → the
  tab is still alive → input is still there (in-session). Back never cleared it.
- "Add user" is a **modal dialog** — it sits above the shell behind a modal
  barrier, so the header Back button can't be pressed while it's open and cannot
  affect it.

## Testing (TDD)

Pure-logic unit tests for the notifier (write tests first):
- visit records a new screen; `canGoBack` flips true.
- consecutive duplicate visit is ignored.
- landing on root resets the stack to `[root]`.
- `back` pops one and exposes the correct previous location.
- the suppress flag prevents a back-navigation from being re-recorded.
- stack is capped at 50.

Widget tests:
- Back button hidden on root; shown after navigating to a non-root screen.
- Tab keep-alive: enter text in a `TextField` on tab A, switch to tab B, return
  to tab A → text is preserved.

## Files touched

- `lib/features/portal/providers/` — **new** `nav_history_provider.dart`
  (`NavLocation`, `navHistoryProvider`, back helper).
- `lib/core/widgets/app_navigation_back_button.dart` — use history provider.
- `lib/features/portal/widgets/portal_shell_layout.dart` — compute `NavLocation`,
  add recorder, repoint `PopScope`, remove header "«".
- `lib/features/super_admin/widgets/super_admin_shell_layout.dart` — compute
  `NavLocation`, add recorder, repoint `PopScope`, remove header "«".
- `lib/features/home/screens/home_screen.dart` — lazy keep-alive tab host.
- `test/` — unit + widget tests above.

## Open items for Phase 2 (not this spec)

- Persisted drafts surviving logout / crash / restart / reload (continuous,
  debounced save-to-disk, since a crash runs no shutdown code).
- Logout prompt: "save for later or clear?".
- On-launch prompt: "continue where you left off?".
- Per-form draft declaration; **security**: do not persist passwords/credentials;
  deliberate decision on persisting any PII.
